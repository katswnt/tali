import { describe, expect, it } from "vitest";
import { commandHelpResponse, complianceResponse, executeSMSCommand } from "../src/sms";

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
    expect(response).toContain("time since yoga");
    expect(response).toContain("reshare contact");
    expect(response).toContain("STOP to unsubscribe");
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

describe("SMS command help", () => {
  it("lists every user-facing command for natural help synonyms", async () => {
    const expected = commandHelpResponse();
    for (const input of ["commands", "command list", "what can you do"]) {
      expect(await executeSMSCommand({} as D1Database, "user-1", input, "UTC")).toBe(expected);
    }
  });

  it("returns a tappable vCard link for contact resharing", async () => {
    const response = await executeSMSCommand(
      {} as D1Database,
      "user-1",
      "reshare contact",
      "UTC",
    );
    expect(response).toContain("https://tali-sms.katswint.workers.dev/contact.vcf");
  });
});
