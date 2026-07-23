import { describe, expect, it } from "vitest";
import { complianceResponse } from "../src/sms";

describe("SMS compliance keywords", () => {
  it("confirms every declared opt-in keyword", () => {
    for (const keyword of ["START", "yes", " Unstop "]) {
      const response = complianceResponse(keyword);
      expect(response).toContain("You're opted in");
      expect(response).toContain("Reply HELP");
      expect(response).toContain("STOP");
    }
  });

  it("provides branded help and opt-out instructions", () => {
    const response = complianceResponse("HELP");
    expect(response).toContain("Tali by Kathryn Swint");
    expect(response).toContain("Reply STOP");
  });

  it("confirms standard opt-out keywords", () => {
    for (const keyword of ["STOP", "STOPALL", "CANCEL", "END", "QUIT", "UNSUBSCRIBE"]) {
      expect(complianceResponse(keyword)).toContain("You're unsubscribed");
    }
  });

  it("leaves habit commands to the normal parser", () => {
    expect(complianceResponse("yoga")).toBeNull();
    expect(complianceResponse("history yoga")).toBeNull();
  });
});
