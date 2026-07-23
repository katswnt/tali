import { describe, expect, it } from "vitest";
import { privacyPage, smsProgramPage, termsPage } from "../src/pages";

describe("public SMS compliance pages", () => {
  it("publishes the required program disclosures", async () => {
    const content = await smsProgramPage().text();
    expect(content).toContain("Message frequency varies");
    expect(content).toContain("Message and data rates may apply");
    expect(content).toContain("STOP");
    expect(content).toContain("HELP");
  });

  it("states that mobile information is not shared for marketing", async () => {
    const content = await privacyPage().text();
    expect(content).toContain("not sold, rented");
    expect(content).toContain("marketing or promotional purposes");
  });

  it("publishes recurring-message, opt-out, and carrier terms", async () => {
    const content = await termsPage().text();
    expect(content).toContain("recurring automated transactional replies");
    expect(content).toContain("Reply STOP");
    expect(content).toContain("carriers are not liable");
  });
});
