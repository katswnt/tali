import assert from "node:assert/strict";

const rawBaseURL = process.env.TALI_BASE_URL;
if (!rawBaseURL) {
  throw new Error("Set TALI_BASE_URL to the deployed staging Worker URL.");
}

const baseURL = new URL(rawBaseURL);
if (!baseURL.hostname.toLowerCase().includes("staging")) {
  throw new Error(`Refusing to run a staging smoke test against ${baseURL.hostname}.`);
}

const health = await get("/health");
assert.equal(health.response.headers.get("content-type")?.includes("application/json"), true);
assert.deepEqual(JSON.parse(health.body), { ok: true, service: "tali-sms" });

for (const path of ["/sms", "/privacy", "/terms", "/support"]) {
  const page = await get(path);
  assert.equal(page.response.headers.get("content-type")?.includes("text/html"), true);
  assert.equal(page.response.headers.get("x-content-type-options"), "nosniff");
  assert.match(page.response.headers.get("content-security-policy") ?? "", /default-src 'none'/);
  assert.match(page.body, new RegExp(`<link rel="canonical" href="[^"]+${path}">`));
  assert.doesNotMatch(page.body, /cdn\.jsdelivr\.net/);
}

const contact = await get("/contact.vcf");
assert.equal(contact.response.headers.get("content-type")?.includes("text/vcard"), true);
assert.match(contact.body, /FN:Tali/);
assert.match(contact.body, /TEL;TYPE=CELL:\+14455452123/);

console.log(`Read-only staging smoke passed for ${baseURL.origin}.`);

async function get(path) {
  const url = new URL(path, baseURL);
  const response = await fetch(url, {
    redirect: "error",
    signal: AbortSignal.timeout(10_000),
  });
  const body = await response.text();
  assert.equal(response.ok, true, `${url} returned ${response.status}: ${body.slice(0, 200)}`);
  return { response, body };
}
