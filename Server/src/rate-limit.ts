export interface RateLimitResult {
  allowed: boolean;
  remaining: number;
  retryAfterSeconds: number;
}

export async function consumeRateLimit(
  db: D1Database,
  namespace: string,
  identifier: string,
  maximum: number,
  windowSeconds: number,
  now = new Date(),
): Promise<RateLimitResult> {
  const nowISO = now.toISOString();
  const expiresAt = new Date(now.getTime() + windowSeconds * 1_000).toISOString();
  const key = `${namespace}:${await digest(identifier || "unknown")}`;
  const row = await db.prepare(`
    INSERT INTO rate_limits (key, window_start, count, expires_at)
    VALUES (?, ?, 1, ?)
    ON CONFLICT(key) DO UPDATE SET
      window_start = CASE
        WHEN rate_limits.expires_at <= excluded.window_start THEN excluded.window_start
        ELSE rate_limits.window_start
      END,
      count = CASE
        WHEN rate_limits.expires_at <= excluded.window_start THEN 1
        ELSE rate_limits.count + 1
      END,
      expires_at = CASE
        WHEN rate_limits.expires_at <= excluded.window_start THEN excluded.expires_at
        ELSE rate_limits.expires_at
      END
    RETURNING count, expires_at
  `).bind(key, nowISO, expiresAt).first<{ count: number; expires_at: string }>();

  if (!row) throw new Error("Rate limit could not be evaluated.");
  const retryAfterSeconds = Math.max(
    1,
    Math.ceil((Date.parse(row.expires_at) - now.getTime()) / 1_000),
  );
  return {
    allowed: row.count <= maximum,
    remaining: Math.max(0, maximum - row.count),
    retryAfterSeconds,
  };
}

export function clientIP(request: Request): string {
  return request.headers.get("CF-Connecting-IP")?.trim() || "unknown";
}

export function rateLimitedJSON(result: RateLimitResult): Response {
  return Response.json(
    { error: "Too many attempts. Try again later." },
    {
      status: 429,
      headers: {
        "retry-after": String(result.retryAfterSeconds),
        "cache-control": "no-store",
      },
    },
  );
}

async function digest(value: string): Promise<string> {
  const bytes = new Uint8Array(
    await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value)),
  );
  return [...bytes].map((byte) => byte.toString(16).padStart(2, "0")).join("");
}
