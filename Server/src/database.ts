import type { EventDTO, EventRow, HabitDTO, HabitRow, SyncSnapshot } from "./types";

export async function mergeSnapshot(
  db: D1Database,
  userID: string,
  snapshot: SyncSnapshot,
): Promise<SyncSnapshot> {
  const existing = await db.prepare("SELECT * FROM habits WHERE user_id = ? ORDER BY created_at, id")
    .bind(userID)
    .all<HabitRow>();
  const habitsByID = new Map<string, HabitRow>();
  const habitsByName = new Map<string, HabitRow>();
  const canonicalHabitID = new Map<string, string>();
  const cleanup: D1PreparedStatement[] = [];

  // Older builds seeded a fresh set of defaults before the first server sync. Consolidate
  // same-name rows in place and move their events to the earliest canonical habit.
  for (const row of existing.results) {
    const key = normalize(row.name);
    const canonical = habitsByName.get(key);
    if (!canonical) {
      habitsByID.set(row.id, row);
      habitsByName.set(key, row);
      canonicalHabitID.set(row.id, row.id);
      continue;
    }

    canonicalHabitID.set(row.id, canonical.id);
    cleanup.push(
      db.prepare("UPDATE events SET habit_id = ? WHERE user_id = ? AND habit_id = ?")
        .bind(canonical.id, userID, row.id),
      db.prepare("DELETE FROM habits WHERE user_id = ? AND id = ?").bind(userID, row.id),
    );

    const merged = mergedDuplicate(canonical, row);
    Object.assign(canonical, merged);
    cleanup.push(updateHabitStatement(db, userID, canonical));
  }

  const statements: D1PreparedStatement[] = [...cleanup];

  for (const habit of snapshot.habits) {
    const key = normalize(habit.name);
    const exact = habitsByID.get(habit.id);
    const sameName = habitsByName.get(key);
    let target = exact ?? sameName;

    if (exact && sameName && exact.id !== sameName.id) {
      target = sameName;
      canonicalHabitID.set(exact.id, target.id);
      statements.push(
        db.prepare("UPDATE events SET habit_id = ? WHERE user_id = ? AND habit_id = ?")
          .bind(target.id, userID, exact.id),
        db.prepare("DELETE FROM habits WHERE user_id = ? AND id = ?").bind(userID, exact.id),
      );
      Object.assign(target, mergedDuplicate(target, exact));
      habitsByID.delete(exact.id);
      habitsByID.set(target.id, target);
      if (habitsByName.get(exact.normalized_name)?.id === exact.id) {
        habitsByName.delete(exact.normalized_name);
      }
      habitsByName.set(target.normalized_name, target);
    }

    if (!target) {
      const row = rowFromDTO(habit, userID);
      habitsByID.set(row.id, row);
      habitsByName.set(row.normalized_name, row);
      canonicalHabitID.set(row.id, row.id);
      statements.push(insertHabitStatement(db, userID, row));
      continue;
    }

    canonicalHabitID.set(habit.id, target.id);
    const oldKey = target.normalized_name;
    const updated = target.id === habit.id
      ? newerDTO(target, habit, userID)
      : mergedDuplicate(target, rowFromDTO(habit, userID));
    Object.assign(target, updated);
    habitsByID.set(target.id, target);
    if (oldKey !== target.normalized_name) habitsByName.delete(oldKey);
    habitsByName.set(target.normalized_name, target);
    statements.push(updateHabitStatement(db, userID, target));
  }

  for (const event of snapshot.events) {
    const habitID = canonicalHabitID.get(event.habitId) ?? event.habitId;
    if (!habitsByID.has(habitID)) {
      throw new Error(`Event ${event.id} references an unknown habit.`);
    }
    statements.push(
      db.prepare(`
        INSERT INTO events (id, user_id, habit_id, occurred_at, created_at, updated_at, source, note, voided_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
          habit_id = excluded.habit_id,
          occurred_at = excluded.occurred_at,
          created_at = excluded.created_at,
          updated_at = excluded.updated_at,
          source = excluded.source,
          note = excluded.note,
          voided_at = excluded.voided_at
        WHERE events.user_id = excluded.user_id
          AND julianday(excluded.updated_at) > julianday(events.updated_at)
      `).bind(
        event.id,
        userID,
        habitID,
        event.occurredAt,
        event.createdAt,
        event.updatedAt,
        event.source,
        event.note ?? null,
        event.voidedAt ?? null,
      ),
    );
  }

  assertUniqueHabitTerms(habitsByID.values());
  if (statements.length) await db.batch(statements);
  return readSnapshot(db, userID);
}

function rowFromDTO(habit: HabitDTO, userID: string): HabitRow {
  return {
    id: habit.id,
    user_id: userID,
    name: habit.name.trim(),
    normalized_name: normalize(habit.name),
    aliases_json: JSON.stringify(habit.aliases.map(normalize).filter(Boolean)),
    created_at: habit.createdAt,
    updated_at: habit.updatedAt,
    is_archived: habit.isArchived ? 1 : 0,
  };
}

function newerDTO(current: HabitRow, incoming: HabitDTO, userID: string): HabitRow {
  return isNewer(incoming.updatedAt, current.updated_at)
    ? rowFromDTO({ ...incoming, id: current.id }, userID)
    : current;
}

function mergedDuplicate(canonical: HabitRow, duplicate: HabitRow): HabitRow {
  const newest = isNewer(duplicate.updated_at, canonical.updated_at) ? duplicate : canonical;
  const aliases = Array.from(new Set([
    ...(JSON.parse(canonical.aliases_json) as string[]),
    ...(JSON.parse(duplicate.aliases_json) as string[]),
  ].map(normalize).filter(Boolean)));
  return {
    ...newest,
    id: canonical.id,
    aliases_json: JSON.stringify(aliases),
    created_at: isNewer(canonical.created_at, duplicate.created_at) ? duplicate.created_at : canonical.created_at,
  };
}

function insertHabitStatement(db: D1Database, userID: string, habit: HabitRow): D1PreparedStatement {
  return db.prepare(`
    INSERT INTO habits (id, user_id, name, normalized_name, aliases_json, created_at, updated_at, is_archived)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
  `).bind(
    habit.id,
    userID,
    habit.name,
    habit.normalized_name,
    habit.aliases_json,
    habit.created_at,
    habit.updated_at,
    habit.is_archived,
  );
}

function updateHabitStatement(db: D1Database, userID: string, habit: HabitRow): D1PreparedStatement {
  return db.prepare(`
    UPDATE habits SET
      name = ?, normalized_name = ?, aliases_json = ?, created_at = ?, updated_at = ?, is_archived = ?
    WHERE user_id = ? AND id = ?
  `).bind(
    habit.name,
    habit.normalized_name,
    habit.aliases_json,
    habit.created_at,
    habit.updated_at,
    habit.is_archived,
    userID,
    habit.id,
  );
}

export async function readSnapshot(db: D1Database, userID: string): Promise<SyncSnapshot> {
  const [habitResult, eventResult] = await Promise.all([
    db.prepare("SELECT * FROM habits WHERE user_id = ? ORDER BY name").bind(userID).all<HabitRow>(),
    db.prepare("SELECT * FROM events WHERE user_id = ? ORDER BY occurred_at DESC").bind(userID).all<EventRow>(),
  ]);

  return {
    habits: habitResult.results.map(habitDTO),
    events: eventResult.results.map(eventDTO),
  };
}

export async function readAccountExport(
  db: D1Database,
  userID: string,
  currentSessionID?: string,
): Promise<Record<string, unknown>> {
  const [
    user,
    sessions,
    phones,
    pairingHistory,
    messages,
    snapshot,
  ] = await Promise.all([
    db.prepare(`
      SELECT id, apple_subject, time_zone, created_at, updated_at
      FROM users WHERE id = ?
    `).bind(userID).first<Record<string, unknown>>(),
    db.prepare(`
      SELECT id, device_name, created_at, last_used_at, expires_at, revoked_at
      FROM sessions WHERE user_id = ? ORDER BY created_at
    `).bind(userID).all<Record<string, unknown>>(),
    db.prepare(`
      SELECT phone, paired_at
      FROM phone_numbers WHERE user_id = ? ORDER BY paired_at
    `).bind(userID).all<Record<string, unknown>>(),
    db.prepare(`
      SELECT created_at, expires_at, used_at
      FROM pairing_codes WHERE user_id = ? ORDER BY created_at
    `).bind(userID).all<Record<string, unknown>>(),
    db.prepare(`
      SELECT sid, from_phone, body, response, created_at
      FROM sms_messages WHERE user_id = ? ORDER BY created_at
    `).bind(userID).all<Record<string, unknown>>(),
    readSnapshot(db, userID),
  ]);

  return {
    formatVersion: 1,
    exportedAt: new Date().toISOString(),
    account: user,
    sessions: sessions.results.map((session) => ({
      ...session,
      current: session.id === currentSessionID,
    })),
    phoneNumbers: phones.results,
    pairingHistory: pairingHistory.results,
    smsMessages: messages.results,
    habits: snapshot.habits,
    events: snapshot.events,
  };
}

export function habitDTO(row: HabitRow): HabitDTO {
  return {
    id: row.id,
    name: row.name,
    aliases: JSON.parse(row.aliases_json) as string[],
    createdAt: row.created_at,
    updatedAt: row.updated_at,
    isArchived: Boolean(row.is_archived),
  };
}

export function eventDTO(row: EventRow): EventDTO {
  return {
    id: row.id,
    habitId: row.habit_id,
    occurredAt: row.occurred_at,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
    source: row.source,
    note: row.note,
    voidedAt: row.voided_at,
  };
}

function normalize(value: string): string {
  return value
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLocaleLowerCase("en-US")
    .trim()
    .replace(/\s+/g, " ");
}

function isNewer(candidate: string, current: string): boolean {
  return Date.parse(candidate) > Date.parse(current);
}

function assertUniqueHabitTerms(rows: Iterable<HabitRow>): void {
  const ownerByTerm = new Map<string, string>();
  for (const row of rows) {
    const terms = [row.normalized_name, ...(JSON.parse(row.aliases_json) as string[])];
    for (const rawTerm of terms) {
      const term = normalize(rawTerm);
      if (!term) continue;
      const owner = ownerByTerm.get(term);
      if (owner && owner !== row.id) {
        throw new Error(`Habit name or alias '${term}' is already in use.`);
      }
      ownerByTerm.set(term, row.id);
    }
  }
}
