import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { createHash } from "node:crypto";

const baseURL = "http://127.0.0.1:8787";
const token = "local-test-token";
const yogaID = "11111111-1111-4111-8111-111111111111";
const appEventID = "22222222-2222-4222-8222-222222222222";
const createdAt = "2026-07-22T19:00:00.000Z";
const duplicateHabitID = crypto.randomUUID();
const duplicateEventID = crypto.randomUUID();
const secondUserID = "33333333-3333-4333-8333-333333333333";
const secondToken = "second-local-test-token";
const secondPhone = "+15555550125";
const claimToken = "legacy-claim-test-token";
const claimCode = "PAIR2345";

const health = await fetch(`${baseURL}/health`).then((response) => response.json());
assert.equal(health.ok, true);

const initial = await sync({
  habits: [
    {
      id: yogaID,
      name: "Yoga",
      aliases: ["did yoga"],
      createdAt,
      updatedAt: createdAt,
      isArchived: false,
    },
  ],
  events: [
    {
      id: appEventID,
      habitId: yogaID,
      occurredAt: createdAt,
      createdAt,
      updatedAt: createdAt,
      source: "app",
    },
  ],
});
const canonicalYoga = initial.habits.find((habit) => habit.name.trim().toLowerCase() === "yoga");
assert.ok(canonicalYoga);
const appEvent = initial.events.find((event) => event.id === appEventID);
assert.equal(appEvent?.note, null);
assert.equal(appEvent?.voidedAt, null);

const deduplicated = await sync({
  habits: [
    {
      id: duplicateHabitID,
      name: " yoga ",
      aliases: ["stretching"],
      createdAt: "2026-07-22T20:00:00.000Z",
      updatedAt: "2026-07-22T20:00:00.000Z",
      isArchived: false,
    },
  ],
  events: [
    {
      id: duplicateEventID,
      habitId: duplicateHabitID,
      occurredAt: "2026-07-22T20:00:00.000Z",
      createdAt: "2026-07-22T20:00:00.000Z",
      updatedAt: "2026-07-22T20:00:00.000Z",
      source: "app",
    },
  ],
});
const yogaHabits = deduplicated.habits.filter((habit) => habit.name.trim().toLowerCase() === "yoga");
assert.equal(yogaHabits.length, 1);
assert.equal(deduplicated.events.find((event) => event.id === duplicateEventID)?.habitId, yogaHabits[0].id);
assert.equal(yogaHabits[0].aliases.includes("stretching"), true);

const form = new URLSearchParams({
  From: "+15555550123",
  To: "+15555550124",
  Body: "yoga -- integration test",
  MessageSid: "SM-INTEGRATION-YOGA-1",
});
const [smsResponse, duplicateResponse] = await Promise.all([
  sendSMS(form),
  sendSMS(form),
]);
assert.match(smsResponse, /Logged Yoga/);
assert.equal(duplicateResponse, smsResponse);

const final = await sync({ habits: [], events: [] });
const finalYoga = final.habits.find((habit) => habit.name.trim().toLowerCase() === "yoga");
assert.ok(finalYoga);
const smsEvents = final.events.filter((event) => event.source === "sms" && event.habitId === finalYoga.id);
assert.equal(smsEvents.length, 1);
assert.equal(smsEvents[0].note, "integration test");

seedSecondUser();
const secondHabitID = crypto.randomUUID();
const secondHabitName = `Tenant ${secondHabitID.slice(0, 8)}`;
const secondSnapshot = await sync({
  habits: [{
    id: secondHabitID,
    name: secondHabitName,
    aliases: [],
    createdAt,
    updatedAt: createdAt,
    isArchived: false,
  }],
  events: [],
}, secondToken);
assert.equal(secondSnapshot.habits.some((habit) => habit.name === secondHabitName), true);
assert.equal(secondSnapshot.habits.some((habit) => habit.name.trim().toLowerCase() === "yoga"), false);

const legacyAfterSecondSync = await sync({ habits: [], events: [] });
assert.equal(legacyAfterSecondSync.habits.some((habit) => habit.name === secondHabitName), false);

const secondSMS = new URLSearchParams({
  From: secondPhone,
  To: "+15555550124",
  Body: secondHabitName,
  MessageSid: `SM-TENANT-${secondHabitID}`,
});
assert.match(await sendSMS(secondSMS), new RegExp(`Logged ${secondHabitName}`));
const secondFinal = await sync({ habits: [], events: [] }, secondToken);
assert.equal(secondFinal.events.some((event) => event.habitId === secondHabitID && event.source === "sms"), true);
const legacyFinal = await sync({ habits: [], events: [] });
assert.equal(legacyFinal.events.some((event) => event.habitId === secondHabitID), false);

seedLegacyClaim();
const claimResponse = await sendSMS(new URLSearchParams({
  From: "+15555550123",
  To: "+15555550124",
  Body: `PAIR ${claimCode}`,
  MessageSid: `SM-CLAIM-${crypto.randomUUID()}`,
}));
assert.match(claimResponse, /connected this number/);
const claimedAccountResponse = await fetch(`${baseURL}/v1/account`, {
  headers: { authorization: `Bearer ${claimToken}` },
});
assert.equal(claimedAccountResponse.status, 200);
const claimedAccount = await claimedAccountResponse.json();
assert.equal(claimedAccount.account.paired, true);

console.log(`Local SMS flow and two-user isolation passed: ${final.habits.length} legacy habit(s).`);

async function sync(snapshot, bearerToken = token) {
  const response = await fetch(`${baseURL}/v1/sync`, {
    method: "POST",
    headers: {
      authorization: `Bearer ${bearerToken}`,
      "content-type": "application/json",
    },
    body: JSON.stringify(snapshot),
  });
  if (response.status !== 200) {
    throw new Error(`Sync failed (${response.status}): ${await response.text()}`);
  }
  return response.json();
}

function seedSecondUser() {
  const now = new Date().toISOString();
  const future = new Date(Date.now() + 60 * 60 * 1000).toISOString();
  const tokenHash = createHash("sha256").update(secondToken).digest("hex");
  const sql = `
    INSERT OR REPLACE INTO users (id, apple_subject, time_zone, created_at, updated_at)
    VALUES ('${secondUserID}', 'integration-second-user', 'America/New_York', '${now}', '${now}');
    INSERT OR REPLACE INTO sessions (id, user_id, token_hash, created_at, expires_at, revoked_at)
    VALUES ('44444444-4444-4444-8444-444444444444', '${secondUserID}', '${tokenHash}', '${now}', '${future}', NULL);
    INSERT OR REPLACE INTO phone_numbers (phone, user_id, paired_at)
    VALUES ('${secondPhone}', '${secondUserID}', '${now}');
  `;
  execFileSync("npx", ["wrangler", "d1", "execute", "tali", "--local", "--command", sql], {
    cwd: new URL("..", import.meta.url),
    stdio: "ignore",
  });
}

function seedLegacyClaim() {
  const temporaryUserID = "55555555-5555-4555-8555-555555555555";
  const now = new Date().toISOString();
  const future = new Date(Date.now() + 60 * 60 * 1000).toISOString();
  const tokenHash = createHash("sha256").update(claimToken).digest("hex");
  const codeHash = createHash("sha256").update(claimCode).digest("hex");
  const sql = `
    DELETE FROM sessions WHERE user_id = '${temporaryUserID}';
    DELETE FROM pairing_codes WHERE user_id = '${temporaryUserID}';
    DELETE FROM users WHERE id = '${temporaryUserID}';
    UPDATE users SET apple_subject = NULL WHERE id = '00000000-0000-4000-8000-000000000001';
    INSERT INTO users (id, apple_subject, time_zone, created_at, updated_at)
    VALUES ('${temporaryUserID}', 'integration-legacy-claim', 'America/Los_Angeles', '${now}', '${now}');
    INSERT INTO sessions (id, user_id, token_hash, created_at, expires_at, revoked_at)
    VALUES ('66666666-6666-4666-8666-666666666666', '${temporaryUserID}', '${tokenHash}', '${now}', '${future}', NULL);
    INSERT INTO pairing_codes (code_hash, user_id, created_at, expires_at, used_at)
    VALUES ('${codeHash}', '${temporaryUserID}', '${now}', '${future}', NULL);
  `;
  execFileSync("npx", ["wrangler", "d1", "execute", "tali", "--local", "--command", sql], {
    cwd: new URL("..", import.meta.url),
    stdio: "ignore",
  });
}

async function sendSMS(form) {
  return fetch(`${baseURL}/twilio/incoming`, {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: form,
  }).then((response) => response.text());
}
