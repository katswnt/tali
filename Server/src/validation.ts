import type { EventDTO, HabitDTO, SyncSnapshot } from "./types";

const MAX_BODY_BYTES = 2_000_000;
const MAX_HABITS = 1_000;
const MAX_EVENTS = 50_000;
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const EVENT_SOURCES = new Set(["app", "messages", "shortcut", "sms"]);

export class SyncPayloadError extends Error {
  constructor(message: string, readonly status = 400) {
    super(message);
  }
}

export async function parseSyncRequest(request: Request): Promise<SyncSnapshot> {
  return parseSyncSnapshot(await parseJSONBody(request));
}

export async function parseJSONRecord(
  request: Request,
  maximumBytes: number,
): Promise<Record<string, unknown>> {
  return record(await parseJSONBody(request, maximumBytes), "Request body");
}

export async function parseVersionedSyncRequest(request: Request): Promise<{
  baseRevision: number;
  mutationID: string;
  snapshot: SyncSnapshot;
}> {
  const root = record(await parseJSONBody(request), "Versioned sync payload");
  if (!Number.isSafeInteger(root.baseRevision) || (root.baseRevision as number) < 0) {
    throw new SyncPayloadError("baseRevision must be a non-negative integer.");
  }
  return {
    baseRevision: root.baseRevision as number,
    mutationID: uuid(root.mutationId, "mutationId"),
    snapshot: parseSyncSnapshot(root.snapshot),
  };
}

async function parseJSONBody(
  request: Request,
  maximumBytes = MAX_BODY_BYTES,
): Promise<unknown> {
  const declaredLength = Number(request.headers.get("content-length") ?? 0);
  if (declaredLength > maximumBytes) throw new SyncPayloadError("Request body is too large.", 413);

  const text = await request.text();
  if (new TextEncoder().encode(text).byteLength > maximumBytes) {
    throw new SyncPayloadError("Request body is too large.", 413);
  }

  let input: unknown;
  try {
    input = JSON.parse(text);
  } catch {
    throw new SyncPayloadError("Sync payload must be valid JSON.");
  }
  return input;
}

export function parseSyncSnapshot(input: unknown): SyncSnapshot {
  const root = record(input, "Sync payload");
  const habitsInput = array(root.habits, "habits", MAX_HABITS);
  const eventsInput = array(root.events, "events", MAX_EVENTS);
  const habits = habitsInput.map((value, index) => habit(value, index));
  const events = eventsInput.map((value, index) => event(value, index));

  requireUnique(habits.map((value) => value.id), "habit ID");
  requireUnique(events.map((value) => value.id), "event ID");
  return { habits, events };
}

function habit(input: unknown, index: number): HabitDTO {
  const value = record(input, `habits[${index}]`);
  const aliases = array(value.aliases, `habits[${index}].aliases`, 20).map((alias, aliasIndex) =>
    boundedString(alias, `habits[${index}].aliases[${aliasIndex}]`, 100),
  );
  return {
    id: uuid(value.id, `habits[${index}].id`),
    name: boundedString(value.name, `habits[${index}].name`, 100),
    aliases,
    createdAt: timestamp(value.createdAt, `habits[${index}].createdAt`),
    updatedAt: timestamp(value.updatedAt, `habits[${index}].updatedAt`),
    isArchived: boolean(value.isArchived, `habits[${index}].isArchived`),
  };
}

function event(input: unknown, index: number): EventDTO {
  const value = record(input, `events[${index}]`);
  const source = boundedString(value.source, `events[${index}].source`, 20);
  if (!EVENT_SOURCES.has(source)) throw new SyncPayloadError(`events[${index}].source is invalid.`);
  return {
    id: uuid(value.id, `events[${index}].id`),
    habitId: uuid(value.habitId, `events[${index}].habitId`),
    occurredAt: timestamp(value.occurredAt, `events[${index}].occurredAt`),
    createdAt: timestamp(value.createdAt, `events[${index}].createdAt`),
    updatedAt: timestamp(value.updatedAt, `events[${index}].updatedAt`),
    source,
    note: nullableString(value.note, `events[${index}].note`, 1_000),
    voidedAt: nullableTimestamp(value.voidedAt, `events[${index}].voidedAt`),
  };
}

function record(value: unknown, label: string): Record<string, unknown> {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new SyncPayloadError(`${label} must be an object.`);
  }
  return value as Record<string, unknown>;
}

function array(value: unknown, label: string, maximum: number): unknown[] {
  if (!Array.isArray(value)) throw new SyncPayloadError(`${label} must be an array.`);
  if (value.length > maximum) throw new SyncPayloadError(`${label} contains too many items.`, 413);
  return value;
}

function boundedString(value: unknown, label: string, maximum: number): string {
  if (typeof value !== "string") throw new SyncPayloadError(`${label} must be a string.`);
  const trimmed = value.trim();
  if (!trimmed || trimmed.length > maximum) {
    throw new SyncPayloadError(`${label} must contain 1–${maximum} characters.`);
  }
  return trimmed;
}

function nullableString(value: unknown, label: string, maximum: number): string | null {
  if (value === undefined || value === null) return null;
  if (typeof value !== "string" || value.length > maximum) {
    throw new SyncPayloadError(`${label} must be at most ${maximum} characters.`);
  }
  return value;
}

function boolean(value: unknown, label: string): boolean {
  if (typeof value !== "boolean") throw new SyncPayloadError(`${label} must be a boolean.`);
  return value;
}

function uuid(value: unknown, label: string): string {
  if (typeof value !== "string" || !UUID.test(value)) {
    throw new SyncPayloadError(`${label} must be a UUID.`);
  }
  return value.toLowerCase();
}

function timestamp(value: unknown, label: string): string {
  if (typeof value !== "string") throw new SyncPayloadError(`${label} must be an ISO-8601 timestamp.`);
  const milliseconds = Date.parse(value);
  if (!Number.isFinite(milliseconds)) throw new SyncPayloadError(`${label} must be an ISO-8601 timestamp.`);
  return new Date(milliseconds).toISOString();
}

function nullableTimestamp(value: unknown, label: string): string | null {
  return value === undefined || value === null ? null : timestamp(value, label);
}

function requireUnique(values: string[], label: string): void {
  if (new Set(values).size !== values.length) throw new SyncPayloadError(`Each ${label} must be unique.`);
}
