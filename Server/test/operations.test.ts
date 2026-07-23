import { describe, expect, it, vi } from "vitest";
import { observeRequest, routeCategory } from "../src/observability";
import { clientIP, consumeRateLimit, rateLimitedJSON } from "../src/rate-limit";
import { RETENTION, retentionCutoffs } from "../src/retention";

describe("privacy-safe operations", () => {
  it("normalizes dynamic routes before logging", () => {
    expect(routeCategory("/v1/sessions/123")).toBe("/v1/sessions/:id");
    expect(routeCategory("/private/habit-name")).toBe("unmatched");
  });

  it("adds an opaque request ID without logging request contents", async () => {
    const log = vi.spyOn(console, "log").mockImplementation(() => {});
    const request = new Request("https://example.com/v1/account", {
      headers: { "CF-Ray": "request-123" },
    });
    const response = await observeRequest(request, async () => Response.json({ ok: true }));
    expect(response.headers.get("x-tali-request-id")).toBe("request-123");
    expect(log).toHaveBeenCalledOnce();
    expect(log.mock.calls[0][0]).toContain('"route":"/v1/account"');
    expect(log.mock.calls[0][0]).not.toContain("habit");
    log.mockRestore();
  });

  it("hashes rate-limit identifiers before persistence", async () => {
    let storedKey = "";
    const db = {
      prepare: () => ({
        bind: (key: string) => {
          storedKey = key;
          return {
            first: async () => ({
              count: 1,
              expires_at: "2026-07-23T12:10:00.000Z",
            }),
          };
        },
      }),
    } as unknown as D1Database;

    const result = await consumeRateLimit(
      db,
      "pairing-phone",
      "+16505551107",
      5,
      600,
      new Date("2026-07-23T12:00:00.000Z"),
    );
    expect(result.allowed).toBe(true);
    expect(storedKey).toMatch(/^pairing-phone:[a-f0-9]{64}$/);
    expect(storedKey).not.toContain("6505551107");
  });

  it("returns a standards-compatible rate-limit response", async () => {
    const response = rateLimitedJSON({
      allowed: false,
      remaining: 0,
      retryAfterSeconds: 42,
    });
    expect(response.status).toBe(429);
    expect(response.headers.get("retry-after")).toBe("42");
    await expect(response.json()).resolves.toEqual({
      error: "Too many attempts. Try again later.",
    });
  });

  it("defines deterministic retention cutoffs", () => {
    const now = new Date("2026-07-23T12:00:00.000Z");
    const cutoffs = retentionCutoffs(now);
    expect(cutoffs.pairing).toBe("2026-07-22T12:00:00.000Z");
    expect(cutoffs.session).toBe("2026-06-23T12:00:00.000Z");
    expect(cutoffs.sms).toBe("2026-06-23T12:00:00.000Z");
    expect(RETENTION.smsReceiptDays).toBe(30);
  });

  it("uses Cloudflare's connection IP and a safe fallback", () => {
    expect(clientIP(new Request("https://example.com", {
      headers: { "CF-Connecting-IP": "203.0.113.4" },
    }))).toBe("203.0.113.4");
    expect(clientIP(new Request("https://example.com"))).toBe("unknown");
  });
});
