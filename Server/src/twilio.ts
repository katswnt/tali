export async function validateTwilioRequest(
  authToken: string,
  signature: string,
  requestURL: string,
  parameters: URLSearchParams,
): Promise<boolean> {
  if (!authToken || !signature) return false;
  const grouped = new Map<string, string[]>();
  parameters.forEach((value, key) => {
    grouped.set(key, [...(grouped.get(key) ?? []), value]);
  });

  let payload = requestURL;
  for (const key of [...grouped.keys()].sort()) {
    for (const value of (grouped.get(key) ?? []).sort()) payload += key + value;
  }

  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(authToken),
    { name: "HMAC", hash: "SHA-1" },
    false,
    ["sign"],
  );
  const digest = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(payload));
  const expected = bytesToBase64(new Uint8Array(digest));
  return timingSafeEqual(expected, signature);
}

export function twiml(message: string): Response {
  const contents = message ? `<Message>${escapeXML(message)}</Message>` : "";
  const xml = `<?xml version="1.0" encoding="UTF-8"?><Response>${contents}</Response>`;
  return new Response(xml, { status: 200, headers: { "content-type": "text/xml; charset=utf-8" } });
}

export function isAdvancedOptOutReply(parameters: URLSearchParams): boolean {
  const value = parameters.get("OptOutType")?.toUpperCase();
  return value === "START" || value === "STOP" || value === "HELP";
}

function escapeXML(value: string): string {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&apos;");
}

function bytesToBase64(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary);
}

function timingSafeEqual(left: string, right: string): boolean {
  const length = Math.max(left.length, right.length);
  let mismatch = left.length ^ right.length;
  for (let index = 0; index < length; index += 1) {
    mismatch |= (left.charCodeAt(index) || 0) ^ (right.charCodeAt(index) || 0);
  }
  return mismatch === 0;
}
