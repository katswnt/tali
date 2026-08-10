import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { createHash } from "node:crypto";

const baseURL = process.env.TALI_BASE_URL ?? "http://127.0.0.1:8787";
const persistenceArgs = process.env.TALI_PERSIST_TO
  ? ["--persist-to", process.env.TALI_PERSIST_TO]
  : [];
const token = "local-test-token";
const yogaID = "11111111-1111-4111-8111-111111111111";
const appEventID = "22222222-2222-4222-8222-222222222222";
const uppercaseEventID = "AAAAAAAA-AAAA-4AAA-8AAA-AAAAAAAAAAAA";
const createdAt = "2026-07-22T19:00:00.000Z";
const duplicateHabitID = crypto.randomUUID();
const duplicateEventID = crypto.randomUUID();
const secondUserID = "33333333-3333-4333-8333-333333333333";
const secondToken = "second-local-test-token";
const otherSessionToken = "other-local-test-token";
const secondPhone = "+15555550125";
const limitedPhone = "+15555550126";
const secondSessionID = "44444444-4444-4444-8444-444444444444";
const otherSessionID = "77777777-7777-4777-8777-777777777777";
const claimToken = "legacy-claim-test-token";
const claimCode = "PAIR2345";
const rotationUserID = "88888888-8888-4888-8888-888888888888";
const rotationSessionID = "99999999-9999-4999-8999-999999999999";
const rotationAccessToken = "rotation-access-token";
const rotationRefreshToken = "rotation-refresh-token";
const integrationSuffix = crypto.randomUUID().slice(0, 8);
const typoSourceName = `Yoga ${integrationSuffix}`;
const typoName = `Uoga ${integrationSuffix}`;
const typoHabitID = crypto.randomUUID();
const createdHabitName = `Meditation ${integrationSuffix}`;

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
    {
      id: typoHabitID,
      name: typoSourceName,
      aliases: [],
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

seedUppercaseEvent(canonicalYoga.id);
const afterCaseVariantSync = await sync({
  habits: [],
  events: [{
    id: uppercaseEventID.toLowerCase(),
    habitId: canonicalYoga.id,
    occurredAt: createdAt,
    createdAt,
    updatedAt: "2026-07-22T20:00:00.000Z",
    source: "app",
    note: "updated without duplicating",
  }],
});
const caseVariants = afterCaseVariantSync.events.filter(
  (event) => event.id.toLowerCase() === uppercaseEventID.toLowerCase()
);
assert.equal(caseVariants.length, 1);
assert.equal(caseVariants[0].note, "updated without duplicating");

const typoResponse = await sendSMS(new URLSearchParams({
  From: "+15555550123",
  To: "+15555550124",
  Body: typoName,
  MessageSid: `SM-TYPO-${crypto.randomUUID()}`,
}));
assert.match(typoResponse, /Did you mean/);
assert.equal(typoResponse.includes(typoSourceName), true);
assert.equal((await sync({ habits: [], events: [] })).habits.some(
  (habit) => habit.name === typoName
), false);

const guardedAddResponse = await sendSMS(new URLSearchParams({
  From: "+15555550123",
  To: "+15555550124",
  Body: `add habit ${typoName}`,
  MessageSid: `SM-ADD-GUARD-${crypto.randomUUID()}`,
}));
assert.match(guardedAddResponse, /Did you mean/);
assert.equal(guardedAddResponse.includes(typoSourceName), true);
assert.equal(guardedAddResponse.includes(`add habit ${typoName} anyway`), true);

const forcedAddResponse = await sendSMS(new URLSearchParams({
  From: "+15555550123",
  To: "+15555550124",
  Body: `add habit ${typoName} anyway`,
  MessageSid: `SM-ADD-FORCE-${crypto.randomUUID()}`,
}));
assert.equal(forcedAddResponse.includes(`Added ${typoName}`), true);

const addResponse = await sendSMS(new URLSearchParams({
  From: "+15555550123",
  To: "+15555550124",
  Body: `add habit ${createdHabitName}`,
  MessageSid: `SM-ADD-${crypto.randomUUID()}`,
}));
assert.equal(addResponse.includes(`Added ${createdHabitName}`), true);
const afterAdd = await sync({ habits: [], events: [] });
assert.equal(afterAdd.habits.some((habit) => habit.name === createdHabitName), true);
assert.equal(afterAdd.habits.some((habit) => habit.name === typoName), true);

const conflictingName = await sendSMS(new URLSearchParams({
  From: "+15555550123",
  To: "+15555550124",
  Body: "add habit help",
  MessageSid: `SM-ADD-CONFLICT-${crypto.randomUUID()}`,
}));
assert.match(conflictingName, /reserved for a Tali or texting command/);

const reservedName = await sendSMS(new URLSearchParams({
  From: "+15555550123",
  To: "+15555550124",
  Body: "add habit STOP",
  MessageSid: `SM-ADD-RESERVED-${crypto.randomUUID()}`,
}));
assert.match(reservedName, /reserved for a Tali or texting command/);

const beforeRejectedInputs = await sync({ habits: [], events: [] });
const yogaEventsBeforeRejectedInputs = beforeRejectedInputs.events.filter(
  (event) => event.habitId === canonicalYoga.id
).length;
for (const [body, expected] of [
  ["yoga today.", /What time today/],
  ["yoga yesterday 25:99pm", /understand that time/],
  ["yoga last night", /nothing was logged/],
  ["yoga extra words", /find/],
]) {
  const response = await sendSMS(new URLSearchParams({
    From: "+15555550123",
    To: "+15555550124",
    Body: body,
    MessageSid: `SM-REJECT-${crypto.randomUUID()}`,
  }));
  assert.match(response, expected);
}
const afterRejectedInputs = await sync({ habits: [], events: [] });
assert.equal(afterRejectedInputs.events.filter(
  (event) => event.habitId === canonicalYoga.id
).length, yogaEventsBeforeRejectedInputs);

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
assert.match(smsResponse, /Logged yoga/i);
assert.equal(duplicateResponse, smsResponse);

const final = await sync({ habits: [], events: [] });
const finalYoga = final.habits.find((habit) => habit.name.trim().toLowerCase() === "yoga");
assert.ok(finalYoga);
const smsEvents = final.events.filter((event) => event.source === "sms" && event.habitId === finalYoga.id);
assert.equal(smsEvents.length, 1);
assert.equal(smsEvents[0].note, "integration test");
assert.equal(
  Date.now() - Date.parse(smsEvents[0].createdAt) < 5 * 60_000,
  true,
  `Expected recent SMS event, received ${smsEvents[0].createdAt}`,
);

const guardedDuplicate = await sendSMS(new URLSearchParams({
  From: "+15555550123",
  To: "+15555550124",
  Body: "yoga",
  MessageSid: `SM-DUPLICATE-GUARD-${crypto.randomUUID()}`,
}));
assert.match(guardedDuplicate, /already logged/);
assert.match(guardedDuplicate, /yoga again/i);

const duplicateOverride = await sendSMS(new URLSearchParams({
  From: "+15555550123",
  To: "+15555550124",
  Body: "yoga again",
  MessageSid: `SM-DUPLICATE-OVERRIDE-${crypto.randomUUID()}`,
}));
assert.match(duplicateOverride, /Logged yoga/i);
const afterDuplicateOverride = await sync({ habits: [], events: [] });
assert.equal(afterDuplicateOverride.events.filter(
  (event) => event.source === "sms" && event.habitId === finalYoga.id
).length, 2);

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
}, secondToken, "America/Chicago");
assert.equal(secondSnapshot.habits.some((habit) => habit.name === secondHabitName), true);
assert.equal(secondSnapshot.habits.some((habit) => habit.name.trim().toLowerCase() === "yoga"), false);

const legacyAfterSecondSync = await sync({ habits: [], events: [] });
assert.equal(legacyAfterSecondSync.habits.some((habit) => habit.name === secondHabitName), false);

assert.equal((await fetch(`${baseURL}/v1/account/time-zone`, {
  method: "POST",
  headers: {
    authorization: `Bearer ${secondToken}`,
    "x-tali-time-zone": "America/Los_Angeles",
  },
})).status, 204);
assert.equal((await fetch(`${baseURL}/v1/account/time-zone`, {
  method: "POST",
  headers: { "x-tali-time-zone": "America/New_York" },
})).status, 401);

const secondSMS = new URLSearchParams({
  From: secondPhone,
  To: "+15555550124",
  Body: `${secondHabitName} yesterday 7pm`,
  MessageSid: `SM-TENANT-${secondHabitID}`,
});
const secondSMSResponse = await sendSMS(secondSMS);
assert.match(secondSMSResponse, new RegExp(`Logged ${secondHabitName}`));
assert.match(secondSMSResponse, /PDT/);
const secondFinal = await sync({ habits: [], events: [] }, secondToken);
assert.equal(secondFinal.events.some((event) => event.habitId === secondHabitID && event.source === "sms"), true);
const legacyFinal = await sync({ habits: [], events: [] });
assert.equal(legacyFinal.events.some((event) => event.habitId === secondHabitID), false);

const versionedMutationID = crypto.randomUUID();
const versionedConflict = await versionedSync({
  baseRevision: 0,
  mutationId: versionedMutationID,
  snapshot: { habits: [], events: [] },
}, token, 409);
assert.equal(versionedConflict.code, "stale_revision");
assert.equal(versionedConflict.revision > 0, true);
assert.equal(versionedConflict.snapshot.habits.some((habit) =>
  habit.name.trim().toLowerCase() === "yoga"
), true);
const versionedResult = await versionedSync({
  baseRevision: versionedConflict.revision,
  mutationId: versionedMutationID,
  snapshot: versionedConflict.snapshot,
});
assert.equal(versionedResult.revision, versionedConflict.revision + 1);
const idempotentResult = await versionedSync({
  baseRevision: versionedConflict.revision,
  mutationId: versionedMutationID,
  snapshot: versionedConflict.snapshot,
});
assert.equal(idempotentResult.revision, versionedResult.revision);

seedRotatingSession();
const refreshedResponse = await fetch(`${baseURL}/v1/auth/refresh`, {
  method: "POST",
  headers: { "content-type": "application/json" },
  body: JSON.stringify({ refreshToken: rotationRefreshToken }),
});
assert.equal(refreshedResponse.status, 200);
const refreshed = await refreshedResponse.json();
assert.equal(typeof refreshed.accessToken, "string");
assert.equal(typeof refreshed.refreshToken, "string");
assert.equal((await fetch(`${baseURL}/v1/account`, {
  headers: { authorization: `Bearer ${rotationAccessToken}` },
})).status, 401);
assert.equal((await fetch(`${baseURL}/v1/account`, {
  headers: { authorization: `Bearer ${refreshed.accessToken}` },
})).status, 200);

const secondRefreshResponse = await fetch(`${baseURL}/v1/auth/refresh`, {
  method: "POST",
  headers: { "content-type": "application/json" },
  body: JSON.stringify({ refreshToken: refreshed.refreshToken }),
});
assert.equal(secondRefreshResponse.status, 200);
const secondRefresh = await secondRefreshResponse.json();
assert.equal((await fetch(`${baseURL}/v1/account`, {
  headers: { authorization: `Bearer ${refreshed.accessToken}` },
})).status, 401);
assert.equal((await fetch(`${baseURL}/v1/account`, {
  headers: { authorization: `Bearer ${secondRefresh.accessToken}` },
})).status, 200);

// The original token is now two rotations old. Reusing any spent token,
// not only the immediately previous one, revokes the account's session family.
const reuseResponse = await fetch(`${baseURL}/v1/auth/refresh`, {
  method: "POST",
  headers: { "content-type": "application/json" },
  body: JSON.stringify({ refreshToken: rotationRefreshToken }),
});
assert.equal(reuseResponse.status, 401);
assert.equal((await fetch(`${baseURL}/v1/account`, {
  headers: { authorization: `Bearer ${secondRefresh.accessToken}` },
})).status, 401);

const sessionsBeforeRevoke = await authorizedJSON("/v1/sessions", secondToken);
assert.equal(sessionsBeforeRevoke.sessions.some((session) =>
  session.id === secondSessionID && session.current === true && session.deviceName === "Integration iPhone"
), true);
assert.equal(sessionsBeforeRevoke.sessions.some((session) =>
  session.id === otherSessionID && session.current === false && session.deviceName === "Old iPhone"
), true);

const revokeResponse = await fetch(`${baseURL}/v1/sessions/${otherSessionID}`, {
  method: "DELETE",
  headers: { authorization: `Bearer ${secondToken}` },
});
assert.equal(revokeResponse.status, 204);
assert.equal((await authorizedJSON("/v1/sessions", secondToken)).sessions.some(
  (session) => session.id === otherSessionID
), false);

const exported = await authorizedJSON("/v1/account/export", secondToken);
assert.equal(exported.formatVersion, 1);
assert.equal(exported.phoneNumbers.some((row) => row.phone === secondPhone), true);
assert.equal(exported.habits.some((habit) => habit.name === secondHabitName), true);
assert.equal(exported.habits.some((habit) => habit.name.trim().toLowerCase() === "yoga"), false);
assert.equal(JSON.stringify(exported).includes("token_hash"), false);
assert.equal(JSON.stringify(exported).includes(otherSessionToken), false);

const pairingCodeStatuses = [];
for (let attempt = 0; attempt < 6; attempt += 1) {
  const response = await fetch(`${baseURL}/v1/pairing/code`, {
    method: "POST",
    headers: { authorization: `Bearer ${secondToken}` },
  });
  pairingCodeStatuses.push(response.status);
}
assert.deepEqual(pairingCodeStatuses, [200, 200, 200, 200, 200, 429]);

let finalPairingAttempt = "";
for (let attempt = 0; attempt < 11; attempt += 1) {
  finalPairingAttempt = await sendSMS(new URLSearchParams({
    From: limitedPhone,
    To: "+15555550124",
    Body: "PAIR ZZZZ9999",
    MessageSid: `SM-RATE-${attempt}`,
  }));
}
assert.match(finalPairingAttempt, /Too many pairing attempts/);

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

const rejectedDeletion = await fetch(`${baseURL}/v1/account`, {
  method: "DELETE",
  headers: {
    authorization: `Bearer ${secondToken}`,
    "content-type": "application/json",
  },
  body: JSON.stringify({ confirmation: "not yet" }),
});
assert.equal(rejectedDeletion.status, 400);

const deletion = await fetch(`${baseURL}/v1/account`, {
  method: "DELETE",
  headers: {
    authorization: `Bearer ${secondToken}`,
    "content-type": "application/json",
  },
  body: JSON.stringify({ confirmation: "DELETE" }),
});
assert.equal(deletion.status, 204);
assert.equal((await fetch(`${baseURL}/v1/account`, {
  headers: { authorization: `Bearer ${secondToken}` },
})).status, 401);

console.log(`Local SMS flow and two-user isolation passed: ${final.habits.length} legacy habit(s).`);

async function sync(snapshot, bearerToken = token, timeZone) {
  const headers = {
    authorization: `Bearer ${bearerToken}`,
    "content-type": "application/json",
  };
  if (timeZone) headers["x-tali-time-zone"] = timeZone;
  const response = await fetch(`${baseURL}/v1/sync`, {
    method: "POST",
    headers,
    body: JSON.stringify(snapshot),
  });
  if (response.status !== 200) {
    throw new Error(`Sync failed (${response.status}): ${await response.text()}`);
  }
  return response.json();
}

async function versionedSync(payload, bearerToken = token, expectedStatus = 200) {
  const response = await fetch(`${baseURL}/v2/sync`, {
    method: "POST",
    headers: {
      authorization: `Bearer ${bearerToken}`,
      "content-type": "application/json",
    },
    body: JSON.stringify(payload),
  });
  assert.equal(response.status, expectedStatus);
  return response.json();
}

function seedSecondUser() {
  const now = new Date().toISOString();
  const future = new Date(Date.now() + 60 * 60 * 1000).toISOString();
  const tokenHash = createHash("sha256").update(secondToken).digest("hex");
  const otherTokenHash = createHash("sha256").update(otherSessionToken).digest("hex");
  const userLimitKey = `pairing-user:${createHash("sha256").update(secondUserID).digest("hex")}`;
  const phoneLimitKey = `pairing-phone:${createHash("sha256").update(limitedPhone).digest("hex")}`;
  const sql = `
    DELETE FROM rate_limits WHERE key IN ('${userLimitKey}', '${phoneLimitKey}');
    INSERT OR REPLACE INTO users (id, apple_subject, time_zone, created_at, updated_at)
    VALUES ('${secondUserID}', 'integration-second-user', 'America/New_York', '${now}', '${now}');
    INSERT OR REPLACE INTO sessions (
      id, user_id, token_hash, device_name, created_at, last_used_at, expires_at, revoked_at
    )
    VALUES (
      '${secondSessionID}', '${secondUserID}', '${tokenHash}', 'Integration iPhone',
      '${now}', '${now}', '${future}', NULL
    );
    INSERT OR REPLACE INTO sessions (
      id, user_id, token_hash, device_name, created_at, last_used_at, expires_at, revoked_at
    )
    VALUES (
      '${otherSessionID}', '${secondUserID}', '${otherTokenHash}', 'Old iPhone',
      '${now}', '${now}', '${future}', NULL
    );
    INSERT OR REPLACE INTO phone_numbers (phone, user_id, paired_at)
    VALUES ('${secondPhone}', '${secondUserID}', '${now}');
  `;
  execFileSync("npx", [
    "wrangler", "d1", "execute", "tali", "--local", ...persistenceArgs, "--command", sql,
  ], {
    cwd: new URL("..", import.meta.url),
    stdio: "ignore",
  });
}

function seedUppercaseEvent(habitID) {
  const sql = `
    INSERT INTO events (
      id, user_id, habit_id, occurred_at, created_at, updated_at, source, note, voided_at
    )
    SELECT
      '${uppercaseEventID}', user_id, id, '${createdAt}', '${createdAt}',
      '${createdAt}', 'app', NULL, NULL
    FROM habits
    WHERE id = '${habitID}';
  `;
  execFileSync("npx", [
    "wrangler", "d1", "execute", "tali", "--local", ...persistenceArgs, "--command", sql,
  ], {
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
    DELETE FROM sessions WHERE id = '66666666-6666-4666-8666-666666666666';
    DELETE FROM pairing_codes WHERE code_hash = '${codeHash}';
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
  execFileSync("npx", [
    "wrangler", "d1", "execute", "tali", "--local", ...persistenceArgs, "--command", sql,
  ], {
    cwd: new URL("..", import.meta.url),
    stdio: "ignore",
  });
}

function seedRotatingSession() {
  const now = new Date().toISOString();
  const accessFuture = new Date(Date.now() + 15 * 60 * 1000).toISOString();
  const sessionFuture = new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString();
  const accessHash = createHash("sha256").update(rotationAccessToken).digest("hex");
  const refreshHash = createHash("sha256").update(rotationRefreshToken).digest("hex");
  const sql = `
    DELETE FROM sessions WHERE user_id = '${rotationUserID}';
    DELETE FROM users WHERE id = '${rotationUserID}';
    INSERT INTO users (id, apple_subject, time_zone, created_at, updated_at)
    VALUES ('${rotationUserID}', 'integration-rotation-user', 'UTC', '${now}', '${now}');
    INSERT INTO sessions (
      id, user_id, token_hash, refresh_token_hash, device_name, created_at,
      last_used_at, access_expires_at, expires_at, revoked_at
    )
    VALUES (
      '${rotationSessionID}', '${rotationUserID}', '${accessHash}', '${refreshHash}',
      'Rotation test', '${now}', '${now}', '${accessFuture}', '${sessionFuture}', NULL
    );
  `;
  execFileSync("npx", [
    "wrangler", "d1", "execute", "tali", "--local", ...persistenceArgs, "--command", sql,
  ], {
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

async function authorizedJSON(path, bearerToken) {
  const response = await fetch(`${baseURL}${path}`, {
    headers: { authorization: `Bearer ${bearerToken}` },
  });
  if (!response.ok) {
    throw new Error(`${path} failed (${response.status}): ${await response.text()}`);
  }
  return response.json();
}
