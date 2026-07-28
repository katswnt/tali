import {
  accountSummary,
  authenticateRequest,
  deleteAccount,
  listSessions,
  refreshSession,
  revokeAllSessions,
  revokeSession,
  revokeSessionByID,
  signInWithApple,
} from "./auth";
import { mergeSnapshot, readAccountExport } from "./database";
import { createPairingCode, pairPhone, pairingCodeFromMessage, userForPhone } from "./pairing";
import { contactCard, privacyPage, smsProgramPage, supportPage, termsPage } from "./pages";
import { logOperational, observeRequest, requestIdentifier } from "./observability";
import { clientIP, consumeRateLimit, rateLimitedJSON } from "./rate-limit";
import { enforceRetention } from "./retention";
import { executeSMSCommand } from "./sms";
import { versionedSync } from "./sync-v2";
import { isAdvancedOptOutReply, twiml, validateTwilioRequest } from "./twilio";
import type { Env } from "./types";
import { parseSyncRequest, parseVersionedSyncRequest, SyncPayloadError } from "./validation";

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    return observeRequest(request, () => handleRequest(request, env));
  },

  async scheduled(
    _controller: ScheduledController,
    env: Env,
    _context: ExecutionContext,
  ): Promise<void> {
    await enforceRetention(env.DB);
  },
} satisfies ExportedHandler<Env>;

async function handleRequest(request: Request, env: Env): Promise<Response> {
  const url = new URL(request.url);

  if (request.method === "GET" && url.pathname === "/sms") return smsProgramPage();
  if (request.method === "GET" && url.pathname === "/contact.vcf") return contactCard();
  if (request.method === "GET" && url.pathname === "/privacy") return privacyPage();
  if (request.method === "GET" && url.pathname === "/terms") return termsPage();
  if (request.method === "GET" && url.pathname === "/support") return supportPage();

  if (request.method === "GET" && url.pathname === "/health") {
    return Response.json({ ok: true, service: "tali-sms" });
  }

  if (request.method === "POST" && url.pathname === "/v1/auth/apple") {
    const limit = await consumeRateLimit(env.DB, "auth-ip", clientIP(request), 10, 10 * 60);
    if (!limit.allowed) {
      logOperational("warn", "rate_limit.exceeded", {
        requestID: requestIdentifier(request),
        category: "auth-ip",
      });
      return rateLimitedJSON(limit);
    }
    return signInWithApple(request, env);
  }

  if (request.method === "POST" && url.pathname === "/v1/auth/refresh") {
    const limit = await consumeRateLimit(env.DB, "refresh-ip", clientIP(request), 30, 10 * 60);
    if (!limit.allowed) return rateLimitedJSON(limit);
    return refreshSession(request, env);
  }

  if (request.method === "GET" && url.pathname === "/v1/account") {
    const user = await authenticateRequest(request, env);
    if (!user) return jsonError("Unauthorized", 401);
    return Response.json({ account: await accountSummary(env.DB, user.id) });
  }

  if (request.method === "GET" && url.pathname === "/v1/account/export") {
    const user = await authenticateRequest(request, env);
    if (!user) return jsonError("Unauthorized", 401);
    const limit = await consumeRateLimit(env.DB, "export-user", user.id, 10, 10 * 60);
    if (!limit.allowed) return rateLimitedJSON(limit);
    const filename = `tali-server-data-${new Date().toISOString().slice(0, 10)}.json`;
    return new Response(JSON.stringify(
      await readAccountExport(env.DB, user.id, user.sessionID),
      null,
      2,
    ), {
      headers: {
        "content-type": "application/json; charset=utf-8",
        "content-disposition": `attachment; filename="${filename}"`,
        "cache-control": "no-store",
      },
    });
  }

  if (request.method === "DELETE" && url.pathname === "/v1/account") {
    const user = await authenticateRequest(request, env);
    if (!user || user.authentication !== "session") {
      return jsonError("Sign in with Apple to delete this account.", 401);
    }
    return deleteAccount(request, env, user.id);
  }

  if (request.method === "GET" && url.pathname === "/v1/sessions") {
    const user = await authenticateRequest(request, env);
    if (!user || user.authentication !== "session" || !user.sessionID) {
      return jsonError("Sign in with Apple to manage devices.", 401);
    }
    return Response.json({
      sessions: await listSessions(env.DB, user.id, user.sessionID),
    });
  }

  if (request.method === "DELETE" && url.pathname === "/v1/sessions") {
    const user = await authenticateRequest(request, env);
    if (!user || user.authentication !== "session") {
      return jsonError("Sign in with Apple to manage devices.", 401);
    }
    await revokeAllSessions(env.DB, user.id);
    return new Response(null, { status: 204 });
  }

  const sessionMatch = /^\/v1\/sessions\/([0-9a-f-]{36})$/i.exec(url.pathname);
  if (request.method === "DELETE" && sessionMatch) {
    const user = await authenticateRequest(request, env);
    if (!user || user.authentication !== "session") {
      return jsonError("Sign in with Apple to manage devices.", 401);
    }
    const revoked = await revokeSessionByID(env.DB, user.id, sessionMatch[1]);
    return revoked ? new Response(null, { status: 204 }) : jsonError("Session not found.", 404);
  }

  if (request.method === "POST" && url.pathname === "/v1/pairing/code") {
    const user = await authenticateRequest(request, env);
    if (!user || user.authentication !== "session") return jsonError("Sign in with Apple first.", 401);
    const limit = await consumeRateLimit(env.DB, "pairing-user", user.id, 5, 10 * 60);
    if (!limit.allowed) {
      logOperational("warn", "rate_limit.exceeded", {
        requestID: requestIdentifier(request),
        category: "pairing-user",
        userID: user.id,
      });
      return rateLimitedJSON(limit);
    }
    return createPairingCode(env.DB, user.id);
  }

  if (request.method === "DELETE" && url.pathname === "/v1/session") {
    const user = await authenticateRequest(request, env);
    if (!user) return jsonError("Unauthorized", 401);
    await revokeSession(request, env);
    return new Response(null, { status: 204 });
  }

  if (request.method === "POST" && url.pathname === "/v1/sync") {
    const user = await authenticateRequest(request, env);
    if (!user) return jsonError("Unauthorized", 401);
    const limit = await consumeRateLimit(env.DB, "sync-user", user.id, 120, 10 * 60);
    if (!limit.allowed) return rateLimitedJSON(limit);
    try {
      await refreshUserTimeZone(request, env.DB, user.id);
      const snapshot = await parseSyncRequest(request);
      return Response.json(await mergeSnapshot(env.DB, user.id, snapshot));
    } catch (error) {
      const status = error instanceof SyncPayloadError ? error.status : 500;
      const message = error instanceof SyncPayloadError ? error.message : "Sync failed";
      if (status === 500) {
        logOperational("error", "sync.failed", {
          requestID: requestIdentifier(request),
          userID: user.id,
          category: "database-or-merge",
        });
      }
      return jsonError(message, status);
    }
  }

  if (request.method === "POST" && url.pathname === "/v2/sync") {
    const user = await authenticateRequest(request, env);
    if (!user) return jsonError("Unauthorized", 401);
    const limit = await consumeRateLimit(env.DB, "sync-user", user.id, 120, 10 * 60);
    if (!limit.allowed) return rateLimitedJSON(limit);
    try {
      await refreshUserTimeZone(request, env.DB, user.id);
      const input = await parseVersionedSyncRequest(request);
      return versionedSync(env.DB, user.id, input);
    } catch (error) {
      const status = error instanceof SyncPayloadError ? error.status : 500;
      const message = error instanceof SyncPayloadError ? error.message : "Sync failed";
      return jsonError(message, status);
    }
  }

  if (request.method === "POST" && url.pathname === "/twilio/status") {
    const parameters = new URLSearchParams(await request.text());
    const signature = request.headers.get("X-Twilio-Signature") ?? "";
    const valid = env.ALLOW_UNSIGNED_TWILIO === "true"
      || await validateTwilioRequest(env.TWILIO_AUTH_TOKEN, signature, request.url, parameters);
    if (!valid) {
      logOperational("warn", "twilio.signature_rejected", {
        requestID: requestIdentifier(request),
        route: "/twilio/status",
      });
      return new Response("Invalid Twilio signature", { status: 403 });
    }
    logOperational("info", "twilio.delivery", {
      requestID: requestIdentifier(request),
      messageID: parameters.get("MessageSid") || "unknown",
      status: parameters.get("MessageStatus") || "unknown",
      errorCode: parameters.get("ErrorCode"),
    });
    return new Response(null, { status: 204 });
  }

  if (request.method === "POST" && url.pathname === "/twilio/incoming") {
    const body = await request.text();
    const parameters = new URLSearchParams(body);
    const signature = request.headers.get("X-Twilio-Signature") ?? "";
    const valid = env.ALLOW_UNSIGNED_TWILIO === "true"
      || await validateTwilioRequest(env.TWILIO_AUTH_TOKEN, signature, request.url, parameters);
    if (!valid) {
      logOperational("warn", "twilio.signature_rejected", {
        requestID: requestIdentifier(request),
        route: "/twilio/incoming",
      });
      return new Response("Invalid Twilio signature", { status: 403 });
    }

    const from = parameters.get("From") ?? "";
    // Advanced Opt-Out has already updated Twilio's block list and sent the
    // configured START/STOP/HELP response. An empty TwiML response prevents
    // Tali from sending a second, duplicate message.
    if (isAdvancedOptOutReply(parameters)) return twiml("");

    const sid = parameters.get("MessageSid") ?? "";
    const message = parameters.get("Body") ?? "";
    const statusCallback = new URL("/twilio/status", request.url).toString();
    if (!sid) return twiml("Tali couldn't identify that message. Please try again.", statusCallback);

    const pairingCode = pairingCodeFromMessage(message);
    if (pairingCode) {
      const limit = await consumeRateLimit(env.DB, "pairing-phone", from, 10, 10 * 60);
      if (!limit.allowed) {
        logOperational("warn", "rate_limit.exceeded", {
          requestID: requestIdentifier(request),
          category: "pairing-phone",
        });
        return twiml("Too many pairing attempts. Create a new code and try again later.", statusCallback);
      }
      return twiml(
        await pairPhone(env.DB, pairingCode, from, env.OWNER_PHONE),
        statusCallback,
      );
    }

    const user = await userForPhone(env.DB, from, env.OWNER_PHONE, env.OWNER_TIME_ZONE);
    if (!user) {
      return twiml(
        "This number isn't connected to Tali. Open the app to pair it first.",
        statusCallback,
      );
    }

    const response = await executeSMSCommand(
      env.DB,
      user.id,
      message,
      user.timeZone,
      { sid, from },
    );
    return twiml(response, statusCallback);
  }

  return new Response("Not found", { status: 404 });
}

function jsonError(message: string, status: number): Response {
  return Response.json({ error: message }, { status });
}

async function refreshUserTimeZone(
  request: Request,
  db: D1Database,
  userID: string,
): Promise<void> {
  const value = request.headers.get("X-Tali-Time-Zone")?.trim();
  if (!value || value.length > 100) return;
  try {
    new Intl.DateTimeFormat("en-US", { timeZone: value }).format();
  } catch {
    return;
  }
  await db.prepare(`
    UPDATE users SET time_zone = ?, updated_at = ? WHERE id = ?
  `).bind(value, new Date().toISOString(), userID).run();
}
