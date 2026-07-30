import {
  HABIT_NAME_MAX_LENGTH,
  habitTermValidationError,
  normalize,
  parseCommand,
} from "./command";
import { bumpSyncRevisionStatement } from "./database";
import type { EventRow, HabitRow } from "./types";

const contactCardURL = "https://tali-sms.katswint.workers.dev/tali-green-contact.vcf";

interface SMSReceipt {
  sid: string;
  from: string;
}

export async function executeSMSCommand(
  db: D1Database,
  userID: string,
  body: string,
  timeZone: string,
  receipt?: SMSReceipt,
): Promise<string> {
  if (receipt) {
    const duplicate = await db.prepare("SELECT response FROM sms_messages WHERE user_id = ? AND sid = ?")
      .bind(userID, receipt.sid)
      .first<{ response: string }>();
    if (duplicate) return duplicate.response;
  }

  const commit = async (response: string, mutations: D1PreparedStatement[] = []): Promise<string> => {
    const revision = mutations.length ? [bumpSyncRevisionStatement(db, userID)] : [];
    if (!receipt) {
      if (mutations.length) await db.batch([...mutations, ...revision]);
      return response;
    }

    const record = db.prepare(`
      INSERT INTO sms_messages (sid, user_id, from_phone, body, response, created_at)
      VALUES (?, ?, ?, ?, ?, ?)
    `).bind(receipt.sid, userID, receipt.from, body, response, new Date().toISOString());

    try {
      // D1 batches are transactional. A concurrent delivery with the same MessageSid
      // loses the primary-key race and its habit mutation is rolled back with the batch.
      await db.batch([...mutations, ...revision, record]);
      return response;
    } catch (error) {
      const duplicate = await db.prepare("SELECT response FROM sms_messages WHERE user_id = ? AND sid = ?")
        .bind(userID, receipt.sid)
        .first<{ response: string }>();
      if (duplicate) return duplicate.response;
      throw error;
    }
  };

  const compliance = complianceResponse(body);
  if (compliance) return commit(compliance);

  const againMatch = body.trim().match(/^(.*?)\s+again$/i);
  const commandText = (againMatch?.[1] ?? body).trim();
  const duplicateOverride = Boolean(againMatch);
  const command = parseCommand(commandText, { timeZone });

  if (command.type === "invalid") {
    return commit(command.message);
  }

  if (duplicateOverride && command.type !== "log") {
    return commit("'again' can only follow a habit log, such as 'yoga again'.");
  }

  if (command.type === "help") {
    return commit(commandHelpResponse());
  }

  if (command.type === "contact") {
    return commit(
      `Save Tali’s number again: ${contactCardURL}\nFor the green photo, open Tali → Texting → Save Tali to Contacts.`,
    );
  }

  if (command.type === "add") {
    const name = command.habit.trim();
    if (!name || Array.from(name).length > HABIT_NAME_MAX_LENGTH) {
      return commit(`Habit names must be between 1 and ${HABIT_NAME_MAX_LENGTH} characters.`);
    }
    const validationError = habitTermValidationError(name);
    if (validationError) {
      return commit(validationError);
    }

    const habits = await loadHabits(db, userID, true);
    const normalized = normalize(name);
    const exact = habits.filter((habit) => terms(habit).includes(normalized));
    if (exact.length > 1) {
      return commit(`'${name}' matches more than one habit. Choose a more specific name.`);
    }
    if (exact.length === 1) {
      const existing = exact[0];
      if (!existing.is_archived) {
        return commit(`'${existing.name}' already exists. Text '${existing.name}' to log it.`);
      }
      const now = new Date().toISOString();
      const restore = db.prepare(`
        UPDATE habits SET is_archived = 0, updated_at = ? WHERE user_id = ? AND id = ?
      `).bind(now, userID, existing.id);
      return commit(`Restored ${existing.name}. Text '${existing.name}' anytime to log it.`, [restore]);
    }

    const suggestion = command.force
      ? null
      : suggestedHabit(habits.filter((habit) => !habit.is_archived), name);
    if (suggestion) {
      return commit(
        `Did you mean '${suggestion.name}'? Text '${suggestion.name}' to log it, `
        + `or 'add habit ${name} anyway' to create a new habit.`,
      );
    }

    const now = new Date().toISOString();
    const insert = db.prepare(`
      INSERT INTO habits (id, user_id, name, normalized_name, aliases_json, created_at, updated_at, is_archived)
      VALUES (?, ?, ?, ?, '[]', ?, ?, 0)
    `).bind(crypto.randomUUID(), userID, name, normalized, now, now);
    return commit(`Added ${name}. Text '${name}' anytime to log it.`, [insert]);
  }

  if (command.type === "list") {
    const result = await db.prepare(`
      SELECT name FROM habits WHERE user_id = ? AND is_archived = 0 ORDER BY name
    `).bind(userID).all<{ name: string }>();
    return commit(result.results.length
      ? result.results.map((habit) => habit.name).join(", ")
      : "No habits yet. Open Tali and sync first.");
  }

  if (command.type === "undo") {
    const event = await db.prepare(`
      SELECT events.*, habits.name AS habit_name
      FROM events JOIN habits ON habits.id = events.habit_id
      WHERE events.user_id = ? AND events.voided_at IS NULL
      ORDER BY events.created_at DESC LIMIT 1
    `).bind(userID).first<EventRow & { habit_name: string }>();
    if (!event) return commit("There isn't a recent log to undo.");
    const now = new Date().toISOString();
    const mutation = db.prepare("UPDATE events SET voided_at = ?, updated_at = ? WHERE user_id = ? AND id = ?")
      .bind(now, now, userID, event.id);
    return commit(
      `Undid ${event.habit_name} from ${formattedTimestamp(new Date(event.occurred_at), timeZone)}.`,
      [mutation],
    );
  }

  const habits = await loadHabits(db, userID);
  const habit = resolveHabit(habits, command.habit);
  if (!habit) {
    const suggestion = suggestedHabit(habits, command.habit);
    return commit(suggestion
      ? `Did you mean '${suggestion.name}'?`
      : `I couldn't find '${command.habit}'. To create it, text 'add habit ${command.habit}'.`);
  }

  if (command.type === "since") {
    const event = await latestEvent(db, userID, habit.id);
    return commit(event ? `${habit.name}: ${elapsed(new Date(event.occurred_at))}.` : `${habit.name} has never been logged.`);
  }

  if (command.type === "history") {
    const result = await db.prepare(`
      SELECT * FROM events
      WHERE user_id = ? AND habit_id = ? AND voided_at IS NULL
      ORDER BY occurred_at DESC LIMIT 10
    `).bind(userID, habit.id).all<EventRow>();
    return commit(result.results.length
      ? `${habit.name}: ${result.results.length} recent logs. Latest ${elapsed(new Date(result.results[0].occurred_at))}.`
      : `${habit.name} has no history yet.`);
  }

  const nowDate = new Date();
  const occurredAt = command.occurredAt ?? nowDate.toISOString();
  if (!duplicateOverride) {
    if (command.occurredAt) {
      const duplicate = await db.prepare(`
        SELECT id FROM events
        WHERE user_id = ? AND habit_id = ? AND voided_at IS NULL AND occurred_at = ?
        LIMIT 1
      `).bind(userID, habit.id, occurredAt).first<{ id: string }>();
      if (duplicate) {
        return commit(
          `${habit.name} is already logged for ${formattedTimestamp(new Date(occurredAt), timeZone)}. `
          + `Text '${commandText} again' to log another.`,
        );
      }
    } else {
      const recent = await db.prepare(`
        SELECT occurred_at, created_at FROM events
        WHERE user_id = ? AND habit_id = ? AND voided_at IS NULL
        ORDER BY created_at DESC LIMIT 1
      `).bind(userID, habit.id).first<Pick<EventRow, "occurred_at" | "created_at">>();
      if (
        recent
        && nowDate.getTime() - new Date(recent.created_at).getTime() < 5 * 60_000
        && Math.abs(nowDate.getTime() - new Date(recent.occurred_at).getTime()) < 5 * 60_000
      ) {
        return commit(
          `${habit.name} was already logged ${elapsed(new Date(recent.created_at), nowDate)}. `
          + `Text '${habit.name} again' to log another.`,
        );
      }
    }
  }
  const previous = await db.prepare(`
    SELECT * FROM events
    WHERE user_id = ? AND habit_id = ? AND voided_at IS NULL AND occurred_at < ?
    ORDER BY occurred_at DESC LIMIT 1
  `).bind(userID, habit.id, occurredAt).first<EventRow>();
  const now = nowDate.toISOString();
  const mutation = db.prepare(`
    INSERT INTO events (id, user_id, habit_id, occurred_at, created_at, updated_at, source, note, voided_at)
    VALUES (?, ?, ?, ?, ?, ?, 'sms', ?, NULL)
  `).bind(crypto.randomUUID(), userID, habit.id, occurredAt, now, now, command.note ?? null);

  const interpreted = command.occurredAt
    ? ` for ${formattedTimestamp(new Date(occurredAt), timeZone)}`
    : "";
  const response = previous
    ? `Logged ${habit.name}${interpreted}. Previous: ${elapsed(new Date(previous.occurred_at), new Date(occurredAt))}.`
    : `Logged ${habit.name}${interpreted}. No earlier entries.`;
  return commit(response, [mutation]);
}

export function complianceResponse(body: string): string | null {
  const keyword = normalize(body).replace(/[.!?]+$/, "").trim();
  if (["start", "yes", "unstop"].includes(keyword)) {
    return "Tali by Kathryn Swint: You're opted in to personal habit-tracking messages. Message frequency varies. Message and data rates may apply. Reply HELP for help or STOP to unsubscribe.";
  }
  if (["stop", "stopall", "cancel", "end", "quit", "unsubscribe"].includes(keyword)) {
    return "Tali by Kathryn Swint: You're unsubscribed and will receive no further messages. Reply START to subscribe again.";
  }
  if (["help", "info"].includes(keyword)) {
    return commandHelpResponse();
  }
  return null;
}

export function commandHelpResponse(): string {
  return [
    "Tali by Kathryn Swint:",
    "To log: yoga",
    "To add habit: add habit yoga",
    "To backdate: yoga yesterday 7pm",
    "To add note: yoga -- note",
    "Time since: time since yoga",
    "History: history yoga",
    "List habits: habits",
    "Undo last log: undo",
    "Reshare contact: reshare contact",
    "Msg & data rates may apply. STOP to unsubscribe.",
  ].join("\n");
}

async function loadHabits(
  db: D1Database,
  userID: string,
  includeArchived = false,
): Promise<HabitRow[]> {
  const result = await db.prepare(`
    SELECT * FROM habits WHERE user_id = ? AND (? = 1 OR is_archived = 0)
  `)
    .bind(userID, includeArchived ? 1 : 0)
    .all<HabitRow>();
  return result.results;
}

function resolveHabit(habits: HabitRow[], query: string): HabitRow | null {
  const normalized = normalize(query);
  const exact = habits.filter((habit) => terms(habit).includes(normalized));
  if (exact.length === 1) return exact[0];
  return null;
}

export function suggestedHabit(habits: HabitRow[], query: string): HabitRow | null {
  const normalized = normalize(query);
  if (normalized.length < 3) return null;
  const maximumDistance = normalized.length <= 4 ? 1 : normalized.length <= 8 ? 2 : 3;
  const ranked = habits
    .map((habit) => ({
      habit,
      distance: Math.min(...terms(habit).map((term) => editDistance(normalized, term))),
    }))
    .filter((candidate) => candidate.distance > 0 && candidate.distance <= maximumDistance)
    .sort((left, right) => left.distance - right.distance);
  if (!ranked.length) return null;
  if (ranked[1]?.distance === ranked[0].distance) return null;
  return ranked[0].habit;
}

function editDistance(left: string, right: string): number {
  const source = Array.from(left);
  const target = Array.from(right);
  const matrix = Array.from(
    { length: source.length + 1 },
    (_, row) => Array.from({ length: target.length + 1 }, (_, column) => row ? 0 : column),
  );
  for (let row = 1; row <= source.length; row += 1) {
    matrix[row][0] = row;
    for (let column = 1; column <= target.length; column += 1) {
      const substitution = matrix[row - 1][column - 1]
        + (source[row - 1] === target[column - 1] ? 0 : 1);
      matrix[row][column] = Math.min(
        matrix[row - 1][column] + 1,
        matrix[row][column - 1] + 1,
        substitution,
      );
      if (
        row > 1
        && column > 1
        && source[row - 1] === target[column - 2]
        && source[row - 2] === target[column - 1]
      ) {
        matrix[row][column] = Math.min(matrix[row][column], matrix[row - 2][column - 2] + 1);
      }
    }
  }
  return matrix[source.length][target.length];
}

function terms(habit: HabitRow): string[] {
  return [habit.normalized_name, ...(JSON.parse(habit.aliases_json) as string[])];
}

async function latestEvent(db: D1Database, userID: string, habitID: string): Promise<EventRow | null> {
  return db.prepare(`
    SELECT * FROM events WHERE user_id = ? AND habit_id = ? AND voided_at IS NULL
    ORDER BY occurred_at DESC LIMIT 1
  `).bind(userID, habitID).first<EventRow>();
}

function elapsed(start: Date, end = new Date()): string {
  const minutes = Math.max(0, Math.floor((end.getTime() - start.getTime()) / 60_000));
  if (minutes < 1) return "just now";
  if (minutes < 60) return `${minutes} ${minutes === 1 ? "minute" : "minutes"} ago`;
  const hours = Math.floor(minutes / 60);
  if (hours < 24) return `${hours} ${hours === 1 ? "hour" : "hours"} ago`;
  const days = Math.floor(hours / 24);
  const remainder = hours % 24;
  return remainder ? `${days}d ${remainder}h ago` : `${days} ${days === 1 ? "day" : "days"} ago`;
}

function formattedTimestamp(date: Date, timeZone: string): string {
  return new Intl.DateTimeFormat("en-US", {
    timeZone,
    weekday: "short",
    month: "short",
    day: "numeric",
    hour: "numeric",
    minute: "2-digit",
    timeZoneName: "short",
  }).format(date);
}
