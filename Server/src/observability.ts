type OperationalValue = string | number | boolean | null;
type OperationalFields = Record<string, OperationalValue>;
const requestIDs = new WeakMap<Request, string>();

export async function observeRequest(
  request: Request,
  handler: () => Promise<Response>,
): Promise<Response> {
  const startedAt = Date.now();
  const requestID = requestIdentifier(request);
  try {
    const response = await handler();
    logOperational("info", "request.completed", {
      requestID,
      method: request.method,
      route: routeCategory(new URL(request.url).pathname),
      status: response.status,
      durationMs: Date.now() - startedAt,
    });
    response.headers.set("x-tali-request-id", requestID);
    return response;
  } catch {
    logOperational("error", "request.failed", {
      requestID,
      method: request.method,
      route: routeCategory(new URL(request.url).pathname),
      status: 500,
      durationMs: Date.now() - startedAt,
      category: "unhandled",
    });
    return Response.json(
      { error: "Tali could not complete that request.", requestID },
      {
        status: 500,
        headers: {
          "cache-control": "no-store",
          "x-tali-request-id": requestID,
        },
      },
    );
  }
}

export function logOperational(
  level: "info" | "warn" | "error",
  event: string,
  fields: OperationalFields = {},
): void {
  const entry = JSON.stringify({
    timestamp: new Date().toISOString(),
    service: "tali-sms",
    event,
    ...fields,
  });
  if (level === "error") console.error(entry);
  else if (level === "warn") console.warn(entry);
  else console.log(entry);
}

export function requestIdentifier(request: Request): string {
  const existing = requestIDs.get(request);
  if (existing) return existing;
  const identifier = request.headers.get("CF-Ray")?.trim() || crypto.randomUUID();
  requestIDs.set(request, identifier);
  return identifier;
}

export function routeCategory(pathname: string): string {
  if (/^\/v1\/sessions\/[^/]+$/.test(pathname)) return "/v1/sessions/:id";
  return [
    "/health",
    "/sms",
    "/privacy",
    "/terms",
    "/v1/auth/apple",
    "/v1/account",
    "/v1/account/export",
    "/v1/pairing/code",
    "/v1/session",
    "/v1/sessions",
    "/v1/sync",
    "/twilio/incoming",
    "/twilio/status",
  ].includes(pathname) ? pathname : "unmatched";
}
