import { describe, expect, it } from "vitest";
import { commandHelpResponse, complianceResponse, executeSMSCommand, suggestedHabit } from "../src/sms";
import type { HabitRow } from "../src/types";

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
    expect(response).toContain("To log: yoga");
    expect(response).toContain("To add habit: add habit yoga");
    expect(response).toContain("To backdate: yoga yesterday 7pm");
    expect(response).not.toContain("LOG:");
    expect(response).toContain("time since yoga");
    expect(response).toContain("reshare contact");
    expect(response).toContain("STOP to unsubscribe");
    expect(response?.length).toBeLessThanOrEqual(320);
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

describe("SMS typo suggestions", () => {
  const habit = (name: string): HabitRow => ({
    id: name.toLowerCase(),
    user_id: "user-1",
    name,
    normalized_name: name.toLowerCase(),
    aliases_json: "[]",
    created_at: "2026-07-22T19:00:00.000Z",
    updated_at: "2026-07-22T19:00:00.000Z",
    is_archived: 0,
  });

  it("suggests a unique close habit for a typo or transposition", () => {
    const habits = [habit("Yoga"), habit("Meditation")];
    expect(suggestedHabit(habits, "uoga")?.name).toBe("Yoga");
    expect(suggestedHabit(habits, "yoag")?.name).toBe("Yoga");
    expect(suggestedHabit(habits, "meditaton")?.name).toBe("Meditation");
  });

  it("does not guess when the closest match is tied or too distant", () => {
    expect(suggestedHabit([habit("Cat"), habit("Cut")], "cot")).toBeNull();
    expect(suggestedHabit([habit("Yoga")], "running")).toBeNull();
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
