import {
  accountSummary,
  authenticateRequest,
  deleteAccount,
  listSessions,
  revokeSession,
  revokeSessionByID,
  signInWithApple,
} from "./auth";
import { mergeSnapshot, readAccountExport } from "./database";
import { createPairingCode, pairPhone, pairingCodeFromMessage, userForPhone } from "./pairing";
import { privacyPage, smsProgramPage, termsPage } from "./pages";
import { executeSMSCommand } from "./sms";
import { isAdvancedOptOutReply, twiml, validateTwilioRequest } from "./twilio";
import type { Env } from "./types";
import { parseSyncRequest, SyncPayloadError } from "./validation";

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);

    if (request.method === "GET" && url.pathname === "/sms") return smsProgramPage();
    if (request.method === "GET" && url.pathname === "/privacy") return privacyPage();
    if (request.method === "GET" && url.pathname === "/terms") return termsPage();

    if (request.method === "GET" && url.pathname === "/health") {
      return Response.json({ ok: true, service: "tali-sms" });
    }

    if (request.method === "POST" && url.pathname === "/v1/auth/apple") {
      return signInWithApple(request, env);
    }

    if (request.method === "GET" && url.pathname === "/v1/account") {
      const user = await authenticateRequest(request, env);
      if (!user) return jsonError("Unauthorized", 401);
      return Response.json({ account: await accountSummary(env.DB, user.id) });
    }

    if (request.method === "GET" && url.pathname === "/v1/account/export") {
      const user = await authenticateRequest(request, env);
      if (!user) return jsonError("Unauthorized", 401);
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
      try {
        const snapshot = await parseSyncRequest(request);
        return Response.json(await mergeSnapshot(env.DB, user.id, snapshot));
      } catch (error) {
        const status = error instanceof SyncPayloadError ? error.status : 500;
        const message = error instanceof SyncPayloadError ? error.message : "Sync failed";
        if (status === 500) console.error("Sync failed", error);
        return jsonError(message, status);
      }
    }

    if (request.method === "POST" && url.pathname === "/twilio/incoming") {
      const body = await request.text();
      const parameters = new URLSearchParams(body);
      const signature = request.headers.get("X-Twilio-Signature") ?? "";
      const valid = env.ALLOW_UNSIGNED_TWILIO === "true"
        || await validateTwilioRequest(env.TWILIO_AUTH_TOKEN, signature, request.url, parameters);
      if (!valid) {
        console.warn("Rejected Twilio webhook: invalid signature");
        return new Response("Invalid Twilio signature", { status: 403 });
      }

      const from = parameters.get("From") ?? "";
      // Advanced Opt-Out has already updated Twilio's block list and sent the
      // configured START/STOP/HELP response. An empty TwiML response prevents
      // Tali from sending a second, duplicate message.
      if (isAdvancedOptOutReply(parameters)) return twiml("");

      const sid = parameters.get("MessageSid") ?? "";
      const message = parameters.get("Body") ?? "";
      if (!sid) return twiml("Tali couldn't identify that message. Please try again.");

      const pairingCode = pairingCodeFromMessage(message);
      if (pairingCode) {
        return twiml(await pairPhone(env.DB, pairingCode, from, env.OWNER_PHONE));
      }

      const user = await userForPhone(env.DB, from, env.OWNER_PHONE, env.OWNER_TIME_ZONE);
      if (!user) return twiml("This number isn't connected to Tali. Open the app to pair it first.");

      const response = await executeSMSCommand(
        env.DB,
        user.id,
        message,
        user.timeZone,
        { sid, from },
      );
      return twiml(response);
    }

    return new Response("Not found", { status: 404 });
  },
} satisfies ExportedHandler<Env>;

function jsonError(message: string, status: number): Response {
  return Response.json({ error: message }, { status });
}
