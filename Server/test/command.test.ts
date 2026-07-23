import { describe, expect, it } from "vitest";
import { parseCommand } from "../src/command";

const now = new Date("2026-07-22T19:00:00.000Z");

describe("parseCommand", () => {
  it("parses a bare habit", () => {
    expect(parseCommand("yoga", { now })).toEqual({ type: "log", habit: "yoga", occurredAt: undefined, note: undefined });
  });

  it("strips conversational prefixes and keeps a note", () => {
    expect(parseCommand("I did PT -- knee felt good", { now })).toEqual({
      type: "log",
      habit: "pt",
      occurredAt: undefined,
      note: "knee felt good",
    });
  });

  it("parses queries", () => {
    expect(parseCommand("since yoga", { now })).toEqual({ type: "since", habit: "yoga" });
    expect(parseCommand("history yoga", { now })).toEqual({ type: "history", habit: "yoga" });
    expect(parseCommand("habits", { now })).toEqual({ type: "list" });
    expect(parseCommand("undo", { now })).toEqual({ type: "undo" });
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
});
