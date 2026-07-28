import { describe, expect, it } from "vitest";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { parseCommand } from "../src/command";

const now = new Date("2026-07-22T19:00:00.000Z");

describe("parseCommand", () => {
  it("parses a bare habit", () => {
    expect(parseCommand("yoga", { now })).toEqual({ type: "log", habit: "yoga", occurredAt: undefined, note: undefined });
  });

  it("strips conversational prefixes and keeps a note", () => {
    expect(parseCommand("I did PT -- knee felt good", { now })).toEqual({
      type: "log",
      habit: "PT",
      occurredAt: undefined,
      note: "knee felt good",
    });
  });

  it("parses queries", () => {
    expect(parseCommand("since yoga", { now })).toEqual({ type: "since", habit: "yoga" });
    expect(parseCommand("time since weed", { now })).toEqual({ type: "since", habit: "weed" });
    expect(parseCommand("how long since weed", { now })).toEqual({ type: "since", habit: "weed" });
    expect(parseCommand("history yoga", { now })).toEqual({ type: "history", habit: "yoga" });
    expect(parseCommand("habits", { now })).toEqual({ type: "list" });
    expect(parseCommand("undo", { now })).toEqual({ type: "undo" });
  });

  it("parses help and contact synonyms", () => {
    for (const input of ["help", "commands", "command list", "menu", "options", "what can you do"]) {
      expect(parseCommand(input, { now })).toEqual({ type: "help" });
    }
    for (const input of ["reshare contact", "share contact", "resend contact", "send contact"]) {
      expect(parseCommand(input, { now })).toEqual({ type: "contact" });
    }
  });

  it("parses explicit habit creation and its typo override", () => {
    expect(parseCommand("add habit Yoga", { now })).toEqual({
      type: "add",
      habit: "Yoga",
      force: false,
    });
    expect(parseCommand("create habit Uoga anyway", { now })).toEqual({
      type: "add",
      habit: "Uoga",
      force: true,
    });
    expect(parseCommand("add habit", { now })).toEqual({ type: "help" });
  });

  it("resolves yesterday in the owner's time zone", () => {
    expect(parseCommand("yoga yesterday at 7pm", {
      now,
      timeZone: "America/Los_Angeles",
    })).toEqual({
      type: "log",
      habit: "yoga",
      occurredAt: "2026-07-22T02:00:00.000Z",
      note: undefined,
    });
  });

  it("resolves a weekday and time to its most recent occurrence", () => {
    for (const input of ["weed sunday 2pm", "weed on Sunday at 2pm"]) {
      expect(parseCommand(input, {
        now,
        timeZone: "America/Los_Angeles",
      })).toEqual({
        type: "log",
        habit: "weed",
        occurredAt: "2026-07-19T21:00:00.000Z",
        note: undefined,
      });
    }
  });

  it("does not resolve an unqualified weekday into the future", () => {
    expect(parseCommand("weed wednesday 2pm", {
      now,
      timeZone: "America/Los_Angeles",
    })).toEqual({
      type: "log",
      habit: "weed",
      occurredAt: "2026-07-15T21:00:00.000Z",
      note: undefined,
    });
  });

  it("satisfies the shared app and SMS command contract", () => {
    const contractURL = new URL("../../Fixtures/command-contract-v1.json", import.meta.url);
    const contract = JSON.parse(readFileSync(fileURLToPath(contractURL), "utf8")) as {
      version: number;
      cases: Array<{
        name: string;
        input: string;
        now: string;
        timeZone: string;
        expected: Record<string, unknown>;
      }>;
    };
    expect(contract.version).toBe(3);

    for (const testCase of contract.cases) {
      const command = parseCommand(testCase.input, {
        now: new Date(testCase.now),
        timeZone: testCase.timeZone,
      });
      expect(JSON.parse(JSON.stringify(command)), testCase.name).toEqual(testCase.expected);
    }
  });
});
