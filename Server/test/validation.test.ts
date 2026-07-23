import { describe, expect, it } from "vitest";
import { parseSyncRequest, parseSyncSnapshot, SyncPayloadError } from "../src/validation";

const habit = {
  id: "11111111-1111-4111-8111-111111111111",
  name: "Yoga",
  aliases: ["stretch"],
  createdAt: "2026-07-22T20:34:56Z",
  updatedAt: "2026-07-22T20:34:56.789Z",
  isArchived: false,
};

describe("sync payload validation", () => {
  it("canonicalizes every timestamp to millisecond ISO-8601", () => {
    const snapshot = parseSyncSnapshot({ habits: [habit], events: [] });
    expect(snapshot.habits[0].createdAt).toBe("2026-07-22T20:34:56.000Z");
    expect(snapshot.habits[0].updatedAt).toBe("2026-07-22T20:34:56.789Z");
  });

  it("rejects malformed IDs, dates, and event sources", () => {
    expect(() => parseSyncSnapshot({ habits: [{ ...habit, id: "nope" }], events: [] }))
      .toThrow(SyncPayloadError);
    expect(() => parseSyncSnapshot({ habits: [{ ...habit, updatedAt: "tomorrow" }], events: [] }))
      .toThrow(SyncPayloadError);
    expect(() => parseSyncSnapshot({
      habits: [habit],
      events: [{
        id: "22222222-2222-4222-8222-222222222222",
        habitId: habit.id,
        occurredAt: habit.createdAt,
        createdAt: habit.createdAt,
        updatedAt: habit.updatedAt,
        source: "carrier-pigeon",
      }],
    })).toThrow(SyncPayloadError);
  });

  it("rejects duplicate entity IDs", () => {
    expect(() => parseSyncSnapshot({ habits: [habit, habit], events: [] }))
      .toThrow("Each habit ID must be unique");
  });

  it("rejects oversized request bodies before parsing", async () => {
    const request = new Request("https://example.com/v1/sync", {
      method: "POST",
      headers: { "content-length": "2000001" },
      body: "{}",
    });
    await expect(parseSyncRequest(request)).rejects.toMatchObject({ status: 413 });
  });
});
