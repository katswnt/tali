import { describe, expect, it } from "vitest";
import { isAdvancedOptOutReply, twiml, validateTwilioRequest } from "../src/twilio";

describe("Twilio helpers", () => {
  it("validates Twilio's documented HMAC signature algorithm", async () => {
    const token = "12345";
    const url = "https://example.com/twilio/incoming";
    const params = new URLSearchParams({ Body: "yoga", From: "+15551234567", MessageSid: "SM123" });
    const payload = `${url}BodyyogaFrom+15551234567MessageSidSM123`;
    const key = await crypto.subtle.importKey(
      "raw",
      new TextEncoder().encode(token),
      { name: "HMAC", hash: "SHA-1" },
      false,
      ["sign"],
    );
    const digest = new Uint8Array(await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(payload)));
    let binary = "";
    for (const byte of digest) binary += String.fromCharCode(byte);
    const signature = btoa(binary);
    await expect(validateTwilioRequest(token, signature, url, params)).resolves.toBe(true);
  });

  it("escapes replies as XML", async () => {
    await expect(twiml("Yoga & PT <done>").text()).resolves.toContain("Yoga &amp; PT &lt;done&gt;");
  });

  it("adds an escaped delivery callback without changing the message", async () => {
    const response = await twiml(
      "Logged Yoga.",
      "https://example.com/twilio/status?source=a&kind=b",
    ).text();
    expect(response).toContain(
      'statusCallback="https://example.com/twilio/status?source=a&amp;kind=b"',
    );
    expect(response).toContain(">Logged Yoga.</Message>");
  });

  it("returns empty TwiML when Twilio already handled Advanced Opt-Out", async () => {
    const parameters = new URLSearchParams({ OptOutType: "STOP" });
    expect(isAdvancedOptOutReply(parameters)).toBe(true);
    expect(isAdvancedOptOutReply(new URLSearchParams({ Body: "STOP" }))).toBe(false);

    const response = await twiml("").text();
    expect(response).toContain("<Response></Response>");
    expect(response).not.toContain("<Message>");
  });
});
