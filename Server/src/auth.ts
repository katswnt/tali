import { LEGACY_USER_ID } from "./types";
import type { AuthenticatedUser, Env } from "./types";
import { logOperational, requestIdentifier } from "./observability";

const APPLE_ISSUER = "https://appleid.apple.com";
const APPLE_KEYS_URL = "https://appleid.apple.com/auth/keys";
const ACCESS_TOKEN_LIFETIME_MS = 15 * 60 * 1_000;
const SESSION_LIFETIME_MS = 90 * 24 * 60 * 60 * 1_000;

interface AppleClaims {
  iss?: unknown;
  aud?: unknown;
  exp?: unknown;
  iat?: unknown;
  sub?: unknown;
  nonce?: unknown;
}

interface AppleKeySet {
  keys: AppleJsonWebKey[];
}

export type AppleJsonWebKey = JsonWebKey & { kid?: string };

export type AppleKeyProvider = (forceRefresh?: boolean) => Promise<AppleJsonWebKey[]>;

export interface AppleTokenVerificationOptions {
  now?: Date;
  keyProvider?: AppleKeyProvider;
}

interface SessionRow {
  session_id: string;
  user_id: string;
  time_zone: string;
}

export interface SessionSummary {
  id: string;
  deviceName: string;
  createdAt: string;
  lastUsedAt: string;
  expiresAt: string;
  current: boolean;
}

let appleKeyCache: { expiresAt: number; keys: AppleJsonWebKey[] } | undefined;

export async function authenticateRequest(request: Request, env: Env): Promise<AuthenticatedUser | null> {
  const authorization = request.headers.get("authorization") ?? "";
  const token = authorization.startsWith("Bearer ") ? authorization.slice(7).trim() : "";
  if (!token) return null;

  if (env.SYNC_TOKEN && timingSafeEqual(token, env.SYNC_TOKEN)) {
    return { id: LEGACY_USER_ID, timeZone: env.OWNER_TIME_ZONE || "UTC", authentication: "legacy" };
  }

  const tokenHash = await sha256(token);
  const now = new Date();
  const nowISO = now.toISOString();
  const session = await env.DB.prepare(`
    SELECT sessions.id AS session_id, sessions.user_id, users.time_zone
    FROM sessions JOIN users ON users.id = sessions.user_id
    WHERE sessions.token_hash = ?
      AND sessions.revoked_at IS NULL
      AND COALESCE(sessions.access_expires_at, sessions.expires_at) > ?
  `).bind(tokenHash, nowISO).first<SessionRow>();
  if (!session) return null;

  const staleBefore = new Date(now.getTime() - 15 * 60 * 1_000).toISOString();
  await env.DB.prepare(`
    UPDATE sessions SET last_used_at = ?
    WHERE id = ? AND (last_used_at IS NULL OR last_used_at < ?)
  `).bind(nowISO, session.session_id, staleBefore).run();

  return {
    id: session.user_id,
    timeZone: session.time_zone,
    authentication: "session",
    sessionID: session.session_id,
  };
}

export async function signInWithApple(request: Request, env: Env): Promise<Response> {
  let input: Record<string, unknown>;
  try {
    input = await request.json<Record<string, unknown>>();
  } catch {
    return jsonError("The sign-in request must be valid JSON.", 400);
  }

  const identityToken = stringValue(input.identityToken);
  const rawNonce = stringValue(input.nonce);
  const timeZone = validTimeZone(stringValue(input.timeZone)) ?? "UTC";
  const deviceName = boundedString(input.deviceName, 80) || "Apple device";
  if (!identityToken || !rawNonce) return jsonError("The Apple identity token and nonce are required.", 400);
  if (!env.APPLE_CLIENT_ID) return jsonError("Sign in with Apple is not configured.", 503);

  let subject: string;
  try {
    const claims = await verifyAppleIdentityToken(identityToken, rawNonce, env.APPLE_CLIENT_ID);
    subject = claims.sub as string;
  } catch {
    logOperational("warn", "auth.apple_rejected", {
      requestID: requestIdentifier(request),
      category: "token-verification",
    });
    return jsonError("Apple sign-in could not be verified.", 401);
  }

  const now = new Date();
  const nowISO = now.toISOString();
  const existing = await env.DB.prepare("SELECT id FROM users WHERE apple_subject = ?")
    .bind(subject)
    .first<{ id: string }>();
  const userID = existing?.id ?? crypto.randomUUID();
  const sessionID = crypto.randomUUID();
  const tokens = sessionTokens(now);

  const statements: D1PreparedStatement[] = [];
  statements.push(env.DB.prepare("DELETE FROM sessions WHERE user_id = ? AND expires_at <= ?")
    .bind(userID, nowISO));
  if (existing) {
    statements.push(env.DB.prepare("UPDATE users SET time_zone = ?, updated_at = ? WHERE id = ?")
      .bind(timeZone, nowISO, userID));
  } else {
    statements.push(env.DB.prepare(`
      INSERT INTO users (id, apple_subject, time_zone, created_at, updated_at)
      VALUES (?, ?, ?, ?, ?)
    `).bind(userID, subject, timeZone, nowISO, nowISO));
  }
  statements.push(env.DB.prepare(`
    INSERT INTO sessions (
      id, user_id, token_hash, refresh_token_hash, previous_refresh_token_hash,
      device_name, created_at, last_used_at, access_expires_at, expires_at, revoked_at
    )
    VALUES (?, ?, ?, ?, NULL, ?, ?, ?, ?, ?, NULL)
  `).bind(
    sessionID,
    userID,
    await sha256(tokens.accessToken),
    await sha256(tokens.refreshToken),
    deviceName,
    nowISO,
    nowISO,
    tokens.accessExpiresAt,
    tokens.sessionExpiresAt,
  ));
  await env.DB.batch(statements);

  return Response.json({
    token: tokens.accessToken,
    expiresAt: tokens.accessExpiresAt,
    ...tokens,
    account: await accountSummary(env.DB, userID),
  }, { headers: { "cache-control": "no-store" } });
}

export async function refreshSession(request: Request, env: Env): Promise<Response> {
  let input: Record<string, unknown>;
  try {
    input = await request.json<Record<string, unknown>>();
  } catch {
    return jsonError("The refresh request must be valid JSON.", 400);
  }
  const refreshToken = stringValue(input.refreshToken);
  if (!refreshToken) return jsonError("A refresh token is required.", 400);

  const refreshHash = await sha256(refreshToken);
  const now = new Date();
  const nowISO = now.toISOString();
  const session = await env.DB.prepare(`
    SELECT id, user_id
    FROM sessions
    WHERE refresh_token_hash = ?
      AND revoked_at IS NULL
      AND expires_at > ?
  `).bind(refreshHash, nowISO).first<{ id: string; user_id: string }>();

  if (!session) {
    const reused = await env.DB.prepare(`
      SELECT user_id FROM sessions
      WHERE previous_refresh_token_hash = ? AND revoked_at IS NULL
    `).bind(refreshHash).first<{ user_id: string }>();
    if (reused) {
      await env.DB.prepare(`
        UPDATE sessions SET revoked_at = ?
        WHERE user_id = ? AND revoked_at IS NULL
      `).bind(nowISO, reused.user_id).run();
      logOperational("warn", "auth.refresh_reuse", {
        requestID: requestIdentifier(request),
        userID: reused.user_id,
        category: "session-revoked",
      });
    }
    return jsonError("This session is no longer valid. Sign in again.", 401);
  }

  const tokens = sessionTokens(now);
  const result = await env.DB.prepare(`
    UPDATE sessions
    SET token_hash = ?,
        previous_refresh_token_hash = refresh_token_hash,
        refresh_token_hash = ?,
        access_expires_at = ?,
        last_used_at = ?
    WHERE id = ?
      AND refresh_token_hash = ?
      AND revoked_at IS NULL
      AND expires_at > ?
  `).bind(
    await sha256(tokens.accessToken),
    await sha256(tokens.refreshToken),
    tokens.accessExpiresAt,
    nowISO,
    session.id,
    refreshHash,
    nowISO,
  ).run();

  if ((result.meta.changes ?? 0) !== 1) {
    await env.DB.prepare(`
      UPDATE sessions SET revoked_at = ?
      WHERE user_id = ? AND revoked_at IS NULL
    `).bind(nowISO, session.user_id).run();
    return jsonError("This session is no longer valid. Sign in again.", 401);
  }

  return Response.json(tokens, { headers: { "cache-control": "no-store" } });
}

export async function accountSummary(db: D1Database, userID: string): Promise<{
  paired: boolean;
  phone: string | null;
}> {
  const row = await db.prepare("SELECT phone FROM phone_numbers WHERE user_id = ? ORDER BY paired_at LIMIT 1")
    .bind(userID)
    .first<{ phone: string }>();
  return { paired: Boolean(row), phone: row ? maskedPhone(row.phone) : null };
}

export async function revokeSession(request: Request, env: Env): Promise<void> {
  const authorization = request.headers.get("authorization") ?? "";
  const token = authorization.startsWith("Bearer ") ? authorization.slice(7).trim() : "";
  if (!token || (env.SYNC_TOKEN && timingSafeEqual(token, env.SYNC_TOKEN))) return;
  await env.DB.prepare("UPDATE sessions SET revoked_at = ? WHERE token_hash = ?")
    .bind(new Date().toISOString(), await sha256(token))
    .run();
}

export async function listSessions(
  db: D1Database,
  userID: string,
  currentSessionID: string,
): Promise<SessionSummary[]> {
  const result = await db.prepare(`
    SELECT id, device_name, created_at, last_used_at, expires_at
    FROM sessions
    WHERE user_id = ? AND revoked_at IS NULL AND expires_at > ?
    ORDER BY COALESCE(last_used_at, created_at) DESC
  `).bind(userID, new Date().toISOString()).all<{
    id: string;
    device_name: string;
    created_at: string;
    last_used_at: string | null;
    expires_at: string;
  }>();

  return result.results.map((session) => ({
    id: session.id,
    deviceName: session.device_name,
    createdAt: session.created_at,
    lastUsedAt: session.last_used_at ?? session.created_at,
    expiresAt: session.expires_at,
    current: session.id === currentSessionID,
  }));
}

export async function revokeSessionByID(
  db: D1Database,
  userID: string,
  sessionID: string,
): Promise<boolean> {
  const result = await db.prepare(`
    UPDATE sessions SET revoked_at = ?
    WHERE id = ? AND user_id = ? AND revoked_at IS NULL
  `).bind(new Date().toISOString(), sessionID, userID).run();
  return (result.meta.changes ?? 0) > 0;
}

export async function revokeAllSessions(db: D1Database, userID: string): Promise<number> {
  const result = await db.prepare(`
    UPDATE sessions SET revoked_at = ?
    WHERE user_id = ? AND revoked_at IS NULL
  `).bind(new Date().toISOString(), userID).run();
  return result.meta.changes ?? 0;
}

export async function deleteAccount(
  request: Request,
  env: Env,
  userID: string,
): Promise<Response> {
  let input: Record<string, unknown>;
  try {
    input = await request.json<Record<string, unknown>>();
  } catch {
    return jsonError("Confirm account deletion with valid JSON.", 400);
  }
  if (input.confirmation !== "DELETE") {
    return jsonError("Type DELETE to confirm account deletion.", 400);
  }

  await env.DB.batch([
    env.DB.prepare("DELETE FROM events WHERE user_id = ?").bind(userID),
    env.DB.prepare("DELETE FROM sms_messages WHERE user_id = ?").bind(userID),
    env.DB.prepare("DELETE FROM habits WHERE user_id = ?").bind(userID),
    env.DB.prepare("DELETE FROM phone_numbers WHERE user_id = ?").bind(userID),
    env.DB.prepare("DELETE FROM pairing_codes WHERE user_id = ?").bind(userID),
    env.DB.prepare("DELETE FROM sessions WHERE user_id = ?").bind(userID),
    env.DB.prepare("DELETE FROM users WHERE id = ?").bind(userID),
  ]);
  return new Response(null, { status: 204 });
}

export async function sha256(value: string): Promise<string> {
  const bytes = new Uint8Array(await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value)));
  return [...bytes].map((byte) => byte.toString(16).padStart(2, "0")).join("");
}

export function randomToken(byteCount: number): string {
  const bytes = crypto.getRandomValues(new Uint8Array(byteCount));
  return base64URL(bytes);
}

function sessionTokens(now: Date): {
  accessToken: string;
  refreshToken: string;
  accessExpiresAt: string;
  sessionExpiresAt: string;
} {
  return {
    accessToken: randomToken(32),
    refreshToken: randomToken(48),
    accessExpiresAt: new Date(now.getTime() + ACCESS_TOKEN_LIFETIME_MS).toISOString(),
    sessionExpiresAt: new Date(now.getTime() + SESSION_LIFETIME_MS).toISOString(),
  };
}

export async function verifyAppleIdentityToken(
  token: string,
  rawNonce: string,
  clientID: string,
  options: AppleTokenVerificationOptions = {},
): Promise<AppleClaims> {
  const parts = token.split(".");
  if (parts.length !== 3) throw new Error("Malformed JWT");
  const header = decodeJSON(parts[0]) as { alg?: unknown; kid?: unknown };
  const claims = decodeJSON(parts[1]) as AppleClaims;
  if (header.alg !== "RS256" || typeof header.kid !== "string") throw new Error("Unsupported JWT header");

  const keyProvider = options.keyProvider ?? appleKeys;
  let keys = await keyProvider(false);
  let jwk = signingKey(keys, header.kid);
  if (!jwk) {
    keys = await keyProvider(true);
    jwk = signingKey(keys, header.kid);
  }
  if (!jwk) throw new Error("Unknown Apple signing key");
  const key = await crypto.subtle.importKey(
    "jwk",
    jwk,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["verify"],
  );
  const verified = await crypto.subtle.verify(
    "RSASSA-PKCS1-v1_5",
    key,
    base64URLDecode(parts[2]),
    new TextEncoder().encode(`${parts[0]}.${parts[1]}`),
  );
  if (!verified) throw new Error("Invalid JWT signature");

  const nowSeconds = Math.floor((options.now ?? new Date()).getTime() / 1_000);
  const audience = Array.isArray(claims.aud) ? claims.aud : [claims.aud];
  if (claims.iss !== APPLE_ISSUER) throw new Error("Invalid issuer");
  if (!audience.includes(clientID)) throw new Error("Invalid audience");
  if (typeof claims.exp !== "number" || claims.exp <= nowSeconds) throw new Error("Expired token");
  if (typeof claims.iat !== "number" || claims.iat > nowSeconds + 300) throw new Error("Invalid issued-at time");
  if (typeof claims.sub !== "string" || !claims.sub) throw new Error("Missing subject");
  if (claims.nonce !== await sha256(rawNonce)) throw new Error("Invalid nonce");
  return claims;
}

async function appleKeys(forceRefresh = false): Promise<AppleJsonWebKey[]> {
  if (!forceRefresh && appleKeyCache && appleKeyCache.expiresAt > Date.now()) return appleKeyCache.keys;

  try {
    const response = await fetch(APPLE_KEYS_URL, { headers: { accept: "application/json" } });
    if (!response.ok) throw new Error(`Apple keys returned HTTP ${response.status}`);
    const body = await response.json<AppleKeySet>();
    if (!Array.isArray(body.keys) || !body.keys.length) throw new Error("Apple returned no signing keys");
    appleKeyCache = {
      keys: body.keys,
      expiresAt: Date.now() + cacheLifetimeMilliseconds(response.headers.get("cache-control")),
    };
    return body.keys;
  } catch (error) {
    // A previously fetched public key remains safe for signature verification and
    // avoids turning a transient Apple outage into an outage for existing keys.
    if (appleKeyCache?.keys.length) return appleKeyCache.keys;
    throw error;
  }
}

function signingKey(keys: AppleJsonWebKey[], kid: string): AppleJsonWebKey | undefined {
  return keys.find((candidate) =>
    candidate.kid === kid
    && candidate.kty === "RSA"
    && (!candidate.use || candidate.use === "sig")
    && (!candidate.alg || candidate.alg === "RS256")
  );
}

function cacheLifetimeMilliseconds(cacheControl: string | null): number {
  const match = cacheControl?.match(/(?:^|,)\s*max-age=(\d+)/i);
  const seconds = match ? Number(match[1]) : 60 * 60;
  return Math.min(Math.max(seconds, 5 * 60), 24 * 60 * 60) * 1_000;
}

function decodeJSON(value: string): unknown {
  return JSON.parse(new TextDecoder().decode(new Uint8Array(base64URLDecode(value))));
}

function base64URLDecode(value: string): ArrayBuffer {
  const base64 = value.replaceAll("-", "+").replaceAll("_", "/").padEnd(Math.ceil(value.length / 4) * 4, "=");
  const binary = atob(base64);
  return Uint8Array.from(binary, (character) => character.charCodeAt(0)).buffer as ArrayBuffer;
}

function base64URL(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replaceAll("+", "-").replaceAll("/", "_").replaceAll("=", "");
}

function validTimeZone(value: string): string | null {
  if (!value || value.length > 100) return null;
  try {
    new Intl.DateTimeFormat("en-US", { timeZone: value }).format();
    return value;
  } catch {
    return null;
  }
}

function stringValue(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

function boundedString(value: unknown, maximumLength: number): string {
  return stringValue(value).slice(0, maximumLength);
}

function maskedPhone(phone: string): string {
  const suffix = phone.replace(/\D/g, "").slice(-4);
  return suffix ? `••• ••• ${suffix}` : "Connected";
}

function timingSafeEqual(left: string, right: string): boolean {
  const length = Math.max(left.length, right.length);
  let mismatch = left.length ^ right.length;
  for (let index = 0; index < length; index += 1) {
    mismatch |= (left.charCodeAt(index) || 0) ^ (right.charCodeAt(index) || 0);
  }
  return mismatch === 0;
}

function jsonError(message: string, status: number): Response {
  return Response.json({ error: message }, { status });
}
