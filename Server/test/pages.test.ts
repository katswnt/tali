import { describe, expect, it } from "vitest";
import { privacyPage, smsProgramPage, supportPage, termsPage } from "../src/pages";

describe("public SMS compliance pages", () => {
  it("publishes the required program disclosures", async () => {
    const content = await smsProgramPage().text();
    expect(content).toContain("Message frequency varies");
    expect(content).toContain("Message and data rates may apply");
    expect(content).toContain("STOP");
    expect(content).toContain("HELP");
    expect(content).toContain('<link rel="canonical" href="https://tali-sms.katswint.workers.dev/sms">');
    expect(content).toContain('property="og:description"');
    expect(content).not.toContain("cdn.jsdelivr.net");
    expect(smsProgramPage().headers.get("content-security-policy")).toContain("default-src 'none'");
  });

  it("states that mobile information is not shared for marketing", async () => {
    const content = await privacyPage().text();
    expect(content).toContain("not sold, rented");
    expect(content).toContain("marketing or promotional purposes");
    expect(content).toContain("contents are removed after 30 days");
    expect(content).toContain("export or delete their server data");
    expect(content).toContain("remain on the device");
    expect(content).toContain("does not request the user's name or email address");
  });

  it("publishes recurring-message, opt-out, and carrier terms", async () => {
    const content = await termsPage().text();
    expect(content).toContain("recurring automated transactional replies");
    expect(content).toContain("Reply STOP");
    expect(content).toContain("carriers are not liable");
  });

  it("publishes a dedicated support destination with a contact path", async () => {
    const response = supportPage();
    const content = await response.text();
    expect(content).toContain("Tali Support");
    expect(content).toContain("contact Kathryn");
    expect(content).toContain("linkedin.com/in/kathrynswint");
    expect(content).toContain("do not send private habit names");
    expect(content).toContain('<link rel="canonical" href="https://tali-sms.katswint.workers.dev/support">');
    expect(response.headers.get("permissions-policy")).toContain("geolocation=()");
  });
});
