import { describe, expect, it } from "vitest";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { habitTermValidationError, parseCommand } from "../src/command";

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
    for (const input of [
      "help", "HELP!", "info", "commands", "command list", "menu", "options", "what can you do",
      "what are the commands?", "show me the commands", "instructions", "how do I use this?",
    ]) {
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

  it("accepts a clock time before today, yesterday, or a weekday", () => {
    const lateEvening = new Date("2026-07-28T05:51:00.000Z");
    expect(parseCommand("alcohol 9:30 pm today", {
      now: lateEvening,
      timeZone: "America/Los_Angeles",
    })).toEqual({
      type: "log",
      habit: "alcohol",
      occurredAt: "2026-07-28T04:30:00.000Z",
      note: undefined,
    });
    expect(parseCommand("alcohol 6:30 pm yesterday", {
      now: lateEvening,
      timeZone: "America/Los_Angeles",
    })).toEqual({
      type: "log",
      habit: "alcohol",
      occurredAt: "2026-07-27T01:30:00.000Z",
      note: undefined,
    });
    expect(parseCommand("alcohol 8pm saturday", {
      now: lateEvening,
      timeZone: "America/Los_Angeles",
    })).toEqual({
      type: "log",
      habit: "alcohol",
      occurredAt: "2026-07-26T03:00:00.000Z",
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

  it("rejects ambiguous, impossible, future, and unsupported date wording", () => {
    const options = { now: new Date("2026-07-28T05:51:00.000Z"), timeZone: "America/Los_Angeles" };
    expect(parseCommand("yoga yesterday", options)).toMatchObject({ type: "invalid" });
    expect(parseCommand("yoga yesterday 7", options)).toMatchObject({ type: "invalid" });
    expect(parseCommand("yoga yesterday 25:99pm", options)).toMatchObject({ type: "invalid" });
    expect(parseCommand("yoga today 11:30pm", options)).toMatchObject({ type: "invalid" });
    expect(parseCommand("yoga last night", options)).toMatchObject({ type: "invalid" });
    expect(parseCommand("yoga July 25 at 8pm", options)).toMatchObject({ type: "invalid" });
  });

  it("supports safe time-only, relative, and punctuated clock wording", () => {
    const options = { now: new Date("2026-07-28T05:51:00.000Z"), timeZone: "America/Los_Angeles" };
    expect(parseCommand("yoga 9pm", options)).toMatchObject({
      type: "log",
      habit: "yoga",
      occurredAt: "2026-07-28T04:00:00.000Z",
    });
    expect(parseCommand("yoga 2 hours ago", options)).toMatchObject({
      type: "log",
      habit: "yoga",
      occurredAt: "2026-07-28T03:51:00.000Z",
    });
    expect(parseCommand("yoga yesterday at 7 p.m.", options)).toMatchObject({
      type: "log",
      habit: "yoga",
      occurredAt: "2026-07-27T02:00:00.000Z",
    });
  });

  it("identifies names that cannot safely be used as text commands", () => {
    expect(habitTermValidationError("Yoga")).toBeNull();
    expect(habitTermValidationError("Morning yoga")).toBeNull();
    expect(habitTermValidationError("stop")).toContain("reserved");
    expect(habitTermValidationError("PAIR ABCD2345")).toContain("pairing");
    expect(habitTermValidationError("Yoga today")).toContain("command or date syntax");
    expect(habitTermValidationError("Yoga again")).toContain("command or date syntax");
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
    expect(contract.version).toBe(6);

    for (const testCase of contract.cases) {
      const command = parseCommand(testCase.input, {
        now: new Date(testCase.now),
        timeZone: testCase.timeZone,
      });
      expect(JSON.parse(JSON.stringify(command)), testCase.name).toEqual(testCase.expected);
    }
  });
});
