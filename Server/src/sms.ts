import { normalize, parseCommand } from "./command";
import type { EventRow, HabitRow } from "./types";

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
    if (!receipt) {
      if (mutations.length) await db.batch(mutations);
      return response;
    }

    const record = db.prepare(`
      INSERT INTO sms_messages (sid, user_id, from_phone, body, response, created_at)
      VALUES (?, ?, ?, ?, ?, ?)
    `).bind(receipt.sid, userID, receipt.from, body, response, new Date().toISOString());

    try {
      // D1 batches are transactional. A concurrent delivery with the same MessageSid
      // loses the primary-key race and its habit mutation is rolled back with the batch.
      await db.batch([...mutations, record]);
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

  const command = parseCommand(body, { timeZone });

  if (command.type === "help") {
    return commit("Try a habit name, 'since yoga', 'habits', or 'undo'. Add a note after --");
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
    return commit(`Undid ${event.habit_name}.`, [mutation]);
  }

  const habit = await resolveHabit(db, userID, command.habit);
  if (!habit) return commit(`I couldn't find '${command.habit}'. Add it in Tali first.`);

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

  const occurredAt = command.occurredAt ?? new Date().toISOString();
  const previous = await db.prepare(`
    SELECT * FROM events
    WHERE user_id = ? AND habit_id = ? AND voided_at IS NULL AND occurred_at < ?
    ORDER BY occurred_at DESC LIMIT 1
  `).bind(userID, habit.id, occurredAt).first<EventRow>();
  const now = new Date().toISOString();
  const mutation = db.prepare(`
    INSERT INTO events (id, user_id, habit_id, occurred_at, created_at, updated_at, source, note, voided_at)
    VALUES (?, ?, ?, ?, ?, ?, 'sms', ?, NULL)
  `).bind(crypto.randomUUID(), userID, habit.id, occurredAt, now, now, command.note ?? null);

  const response = previous
    ? `Logged ${habit.name}. Previous: ${elapsed(new Date(previous.occurred_at), new Date(occurredAt))}.`
    : `Logged ${habit.name}. No earlier entries.`;
  return commit(response, [mutation]);
}

export function complianceResponse(body: string): string | null {
  const keyword = normalize(body);
  if (["start", "yes", "unstop"].includes(keyword)) {
    return "Tali by Kathryn Swint: You're opted in to personal habit-tracking messages. Message frequency varies. Message and data rates may apply. Reply HELP for help or STOP to unsubscribe.";
  }
  if (["stop", "stopall", "cancel", "end", "quit", "unsubscribe"].includes(keyword)) {
    return "Tali by Kathryn Swint: You're unsubscribed and will receive no further messages. Reply START to subscribe again.";
  }
  if (["help", "info"].includes(keyword)) {
    return "Tali by Kathryn Swint: Text a habit name to log it, HABITS for your list, or UNDO to undo. Message and data rates may apply. Reply STOP to unsubscribe.";
  }
  return null;
}

async function resolveHabit(db: D1Database, userID: string, query: string): Promise<HabitRow | null> {
  const result = await db.prepare("SELECT * FROM habits WHERE user_id = ? AND is_archived = 0")
    .bind(userID)
    .all<HabitRow>();
  const normalized = normalize(query);
  const exact = result.results.filter((habit) => terms(habit).includes(normalized));
  if (exact.length === 1) return exact[0];
  if (exact.length > 1) return null;
  const partial = result.results.filter((habit) =>
    terms(habit).some((term) => term.startsWith(normalized) || normalized.startsWith(term)),
  );
  return partial.length === 1 ? partial[0] : null;
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
