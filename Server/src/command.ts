export const HABIT_NAME_MAX_LENGTH = 80;
export const HABIT_ALIAS_MAX_LENGTH = 80;
export const HABIT_ALIAS_MAX_COUNT = 20;
export const NOTE_MAX_LENGTH = 1_000;

export type Command =
  | { type: "log"; habit: string; occurredAt?: string; note?: string }
  | { type: "add"; habit: string; force: boolean }
  | { type: "since"; habit: string }
  | { type: "history"; habit: string }
  | { type: "undo" }
  | { type: "list" }
  | { type: "contact" }
  | { type: "help" }
  | { type: "invalid"; message: string };

type DateExtraction =
  | { habit: string; occurredAt?: string }
  | { habit: string; error: string };

const dayWords = "today|yesterday|sunday|monday|tuesday|wednesday|thursday|friday|saturday";
const clockPattern = "[0-9]{1,2}(?::[0-9]{2})?\\s*(?:a\\.?m\\.?|p\\.?m\\.?)?";
const trailingPunctuation = "[.!]?";
const ambiguousTimeMessage = "Include AM or PM for times from 1–12. Example: yoga yesterday 7pm.";
const invalidTimeMessage = "I couldn't understand that time. Try a time like 7pm or 19:00.";
const unsupportedDateMessage =
  "I couldn't understand that date or time, so nothing was logged. Try: yoga yesterday 7pm.";

const reservedHabitTerms = new Set([
  "start",
  "yes",
  "unstop",
  "stop",
  "stopall",
  "cancel",
  "end",
  "quit",
  "unsubscribe",
  "help",
  "info",
  "commands",
  "command list",
  "menu",
  "options",
  "what can you do",
  "what are the commands",
  "show commands",
  "show me the commands",
  "instructions",
  "how to use tali",
  "how do i use tali",
  "how do i use this",
  "how does this work",
  "how does tali work",
  "undo",
  "undo last",
  "never mind",
  "nevermind",
  "habits",
  "list",
  "list habits",
  "reshare contact",
  "share contact",
  "resend contact",
  "send contact",
  "history",
  "stats",
  "since",
  "time since",
  "last",
  "log",
]);

export function normalize(value: string): string {
  return value
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLocaleLowerCase("en-US")
    .trim()
    .replace(/\s+/g, " ");
}

export function habitTermValidationError(
  value: string,
  allowedLogTargets: ReadonlySet<string> = new Set(),
): string | null {
  const trimmed = value.trim();
  const normalized = normalize(trimmed);
  if (!trimmed) return "Enter a habit name.";
  if (Array.from(trimmed).length > HABIT_NAME_MAX_LENGTH) {
    return `Habit names and aliases must be ${HABIT_NAME_MAX_LENGTH} characters or fewer.`;
  }
  if (reservedHabitTerms.has(normalized)) return `'${trimmed}' is reserved for a Tali or texting command.`;
  if (/^pair\s+[a-z2-9]{8}$/i.test(trimmed)) return `'${trimmed}' is reserved for phone pairing.`;
  const parsed = parseCommand(trimmed, {
    now: new Date("2026-07-23T01:42:00.000Z"),
    timeZone: "America/Los_Angeles",
  });
  if (parsed.type !== "log"
    || (normalize(parsed.habit) !== normalized && !allowedLogTargets.has(normalize(parsed.habit)))
    || parsed.occurredAt !== undefined
    || parsed.note !== undefined
    || /\s+again$/i.test(trimmed)) {
    return `'${trimmed}' conflicts with Tali's command or date syntax.`;
  }
  return null;
}

export function parseCommand(
  input: string,
  options: { now?: Date; timeZone?: string } = {},
): Command {
  const trimmed = input.trim();
  const value = normalize(trimmed);
  const commandValue = value.replace(/[.!?]+$/, "").trim();
  const now = options.now ?? new Date();
  const timeZone = options.timeZone ?? "UTC";

  if (["undo", "undo last", "never mind", "nevermind"].includes(commandValue)) {
    return { type: "undo" };
  }
  if (["habits", "list", "list habits"].includes(commandValue)) {
    return { type: "list" };
  }
  if ([
    "help",
    "info",
    "commands",
    "command list",
    "menu",
    "options",
    "what can you do",
    "what are the commands",
    "show commands",
    "show me the commands",
    "instructions",
    "how to use tali",
    "how do i use tali",
    "how do i use this",
    "how does this work",
    "how does tali work",
  ].includes(commandValue) || !commandValue) {
    return { type: "help" };
  }
  if (["reshare contact", "share contact", "resend contact", "send contact"].includes(commandValue)) {
    return { type: "contact" };
  }
  if (["history", "stats", "since", "time since", "last", "log"].includes(commandValue)) {
    return { type: "help" };
  }

  const addMatch = trimmed.match(/^(?:add|create|new)\s+habit(?:\s+(.*))?$/i);
  if (addMatch) {
    const requested = (addMatch[1] ?? "").trim();
    if (!requested) return { type: "help" };
    const forceMatch = requested.match(/^(.*?)\s+anyway$/i);
    const habit = (forceMatch?.[1] ?? requested).trim();
    return habit
      ? { type: "add", habit, force: Boolean(forceMatch) }
      : { type: "help" };
  }

  const since = afterPrefix(commandValue, [
    "time since ",
    "how long since ",
    "since ",
    "when did i ",
    "when was ",
    "last ",
  ]);
  if (since !== undefined) return since ? { type: "since", habit: since } : { type: "help" };

  const history = afterPrefix(commandValue, ["history ", "stats "]);
  if (history !== undefined) return history ? { type: "history", habit: history } : { type: "help" };

  const logText = trimmed.replace(/^(?:#did|i\s+did|did|log)\s+/i, "");
  const [habitAndDate, ...noteParts] = logText.split(/\s+--\s+/);
  const note = noteParts.join(" -- ").trim() || undefined;
  if (note && Array.from(note).length > NOTE_MAX_LENGTH) {
    return { type: "invalid", message: `Notes must be ${NOTE_MAX_LENGTH} characters or fewer.` };
  }

  const dated = extractDate(habitAndDate, now, timeZone);
  if ("error" in dated) return { type: "invalid", message: dated.error };
  if (!dated.habit) return { type: "help" };
  if (Array.from(dated.habit).length > HABIT_NAME_MAX_LENGTH) {
    return {
      type: "invalid",
      message: `Habit names must be ${HABIT_NAME_MAX_LENGTH} characters or fewer.`,
    };
  }
  return { type: "log", habit: dated.habit, occurredAt: dated.occurredAt, note };
}

function afterPrefix(value: string, prefixes: string[]): string | undefined {
  const prefix = prefixes.find((candidate) => value.startsWith(candidate));
  return prefix ? value.slice(prefix.length).trim() : undefined;
}

function extractDate(value: string, now: Date, timeZone: string): DateExtraction {
  const timeFirst = value.match(new RegExp(
    `\\s+(?:at\\s+)?(${clockPattern})\\s+(?:on\\s+)?(?:(last)\\s+)?(${dayWords})${trailingPunctuation}$`,
    "i",
  ));
  const dayFirst = timeFirst ? null : value.match(new RegExp(
    `\\s+(?:on\\s+)?(?:(last)\\s+)?(${dayWords})(?:\\s+(?:at\\s+)?(${clockPattern}))?${trailingPunctuation}$`,
    "i",
  ));

  if (timeFirst || dayFirst) {
    const match = timeFirst ?? dayFirst!;
    if (match.index === undefined) return { habit: value.trim() };
    const explicitlyLast = Boolean(timeFirst ? match[2] : match[1]);
    const dayWord = (timeFirst ? match[3] : match[2]).toLowerCase();
    const clockValue = timeFirst ? match[1] : match[3];
    const habit = value.slice(0, match.index).trim();
    if (!habit) return { habit: "", error: "Include a habit before the date and time." };
    if (!clockValue) {
      return {
        habit,
        error: `What time ${dayWord}? Example: ${habit} ${dayWord} 7pm.`,
      };
    }

    const time = parseTime(clockValue);
    if ("error" in time) return { habit, error: time.error };
    const dayOffset = offsetForDay(dayWord, now, timeZone, explicitlyLast);
    let occurredAt = dateInTimeZone(now, timeZone, dayOffset, time.hour, time.minute);
    if (!occurredAt) {
      return { habit, error: "That local time doesn't exist because of a daylight-saving change." };
    }
    if (weekdayNumber(dayWord) !== null && !explicitlyLast && occurredAt > now) {
      occurredAt = dateInTimeZone(now, timeZone, dayOffset - 7, time.hour, time.minute);
    }
    if (!occurredAt) {
      return { habit, error: "That local time doesn't exist because of a daylight-saving change." };
    }
    if (occurredAt.getTime() > now.getTime() + 60_000) {
      return { habit, error: "That time is in the future, so nothing was logged." };
    }
    return { habit, occurredAt: occurredAt.toISOString() };
  }

  const agoMatch = value.match(/\s+([0-9]+)\s+(minute|hour|day)s?\s+ago[.!]?$/i);
  if (agoMatch?.index !== undefined) {
    const habit = value.slice(0, agoMatch.index).trim();
    const amount = Number(agoMatch[1]);
    const unit = agoMatch[2].toLowerCase();
    const maximum = unit === "day" ? 3650 : unit === "hour" ? 87_600 : 5_256_000;
    if (!habit || amount < 1 || amount > maximum) {
      return { habit, error: unsupportedDateMessage };
    }
    const milliseconds = unit === "day" ? 86_400_000 : unit === "hour" ? 3_600_000 : 60_000;
    return { habit, occurredAt: new Date(now.getTime() - amount * milliseconds).toISOString() };
  }

  const timeOnly = value.match(new RegExp(
    `\\s+(?:at\\s+)?(${clockPattern})${trailingPunctuation}$`,
    "i",
  ));
  if (timeOnly?.index !== undefined) {
    const habit = value.slice(0, timeOnly.index).trim();
    const time = parseTime(timeOnly[1]);
    if (!habit) return { habit: "", error: "Include a habit before the time." };
    if (looksTemporal(habit)) return { habit, error: unsupportedDateMessage };
    if ("error" in time) return { habit, error: time.error };
    const occurredAt = dateInTimeZone(now, timeZone, 0, time.hour, time.minute);
    if (!occurredAt) {
      return { habit, error: "That local time doesn't exist because of a daylight-saving change." };
    }
    if (occurredAt.getTime() > now.getTime() + 60_000) {
      return {
        habit,
        error: `That time is still in the future today. Include a day, such as '${habit} yesterday ${timeOnly[1]}'.`,
      };
    }
    return { habit, occurredAt: occurredAt.toISOString() };
  }

  if (looksTemporal(value)) return { habit: value.trim(), error: unsupportedDateMessage };
  return { habit: value.trim() };
}

function offsetForDay(word: string, now: Date, timeZone: string, explicitlyLast: boolean): number {
  if (word === "today") return 0;
  if (word === "yesterday") return -1;
  const target = weekdayNumber(word);
  if (target === null) return 0;
  const parts = zonedParts(now, timeZone);
  const current = new Date(Date.UTC(parts.year, parts.month - 1, parts.day)).getUTCDay();
  let daysBack = (current - target + 7) % 7;
  if (explicitlyLast && daysBack === 0) daysBack = 7;
  return -daysBack;
}

function weekdayNumber(word: string): number | null {
  const weekdays: Record<string, number> = {
    sunday: 0,
    monday: 1,
    tuesday: 2,
    wednesday: 3,
    thursday: 4,
    friday: 5,
    saturday: 6,
  };
  return weekdays[word] ?? null;
}

function parseTime(value: string):
  | { hour: number; minute: number }
  | { error: string } {
  const compact = value.toLowerCase().replace(/[\s.]/g, "");
  const match = compact.match(/^(\d{1,2})(?::(\d{2}))?(am|pm)?$/);
  if (!match) return { error: invalidTimeMessage };
  let hour = Number(match[1]);
  const minute = Number(match[2] ?? 0);
  const meridiem = match[3];
  if (minute > 59) return { error: invalidTimeMessage };
  if (meridiem) {
    if (hour < 1 || hour > 12) return { error: invalidTimeMessage };
    if (meridiem === "pm" && hour < 12) hour += 12;
    if (meridiem === "am" && hour === 12) hour = 0;
    return { hour, minute };
  }
  if (hour >= 1 && hour <= 12) return { error: ambiguousTimeMessage };
  if (hour < 0 || hour > 23) return { error: invalidTimeMessage };
  return { hour, minute };
}

function dateInTimeZone(
  now: Date,
  timeZone: string,
  dayOffset: number,
  hour: number,
  minute: number,
): Date | null {
  const parts = zonedParts(now, timeZone);
  const targetWallClock = Date.UTC(parts.year, parts.month - 1, parts.day + dayOffset, hour, minute);
  const target = new Date(targetWallClock);
  let candidate = new Date(targetWallClock);
  for (let index = 0; index < 2; index += 1) {
    candidate = new Date(targetWallClock - zoneOffsetMilliseconds(candidate, timeZone));
  }
  const resolved = zonedDateTimeParts(candidate, timeZone);
  if (
    resolved.year !== target.getUTCFullYear()
    || resolved.month !== target.getUTCMonth() + 1
    || resolved.day !== target.getUTCDate()
    || resolved.hour !== hour
    || resolved.minute !== minute
  ) {
    return null;
  }
  return candidate;
}

function zonedParts(date: Date, timeZone: string): { year: number; month: number; day: number } {
  const parts = zonedDateTimeParts(date, timeZone);
  return { year: parts.year, month: parts.month, day: parts.day };
}

function zonedDateTimeParts(
  date: Date,
  timeZone: string,
): { year: number; month: number; day: number; hour: number; minute: number } {
  const formatter = new Intl.DateTimeFormat("en-US", {
    timeZone,
    year: "numeric",
    month: "numeric",
    day: "numeric",
    hour: "numeric",
    minute: "numeric",
    hourCycle: "h23",
  });
  const values = Object.fromEntries(formatter.formatToParts(date).map((part) => [part.type, part.value]));
  return {
    year: Number(values.year),
    month: Number(values.month),
    day: Number(values.day),
    hour: Number(values.hour),
    minute: Number(values.minute),
  };
}

function zoneOffsetMilliseconds(date: Date, timeZone: string): number {
  const formatter = new Intl.DateTimeFormat("en-US", {
    timeZone,
    timeZoneName: "longOffset",
  });
  const name = formatter.formatToParts(date).find((part) => part.type === "timeZoneName")?.value ?? "GMT";
  const match = name.match(/^GMT([+-])(\d{2}):(\d{2})$/);
  if (!match) return 0;
  const sign = match[1] === "+" ? 1 : -1;
  return sign * (Number(match[2]) * 60 + Number(match[3])) * 60_000;
}

function looksTemporal(value: string): boolean {
  return /\s+(today|yesterday|tomorrow|tonight|morning|afternoon|evening|night|sunday|monday|tuesday|wednesday|thursday|friday|saturday|ago)\b/i.test(value)
    || /\s+(?:jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|jun(?:e)?|jul(?:y)?|aug(?:ust)?|sep(?:tember)?|oct(?:ober)?|nov(?:ember)?|dec(?:ember)?)\s+[0-9]{1,2}\b/i.test(value)
    || /\s+[0-9]{1,2}[/-][0-9]{1,2}(?:[/-][0-9]{2,4})?\b/.test(value)
    || /\s+[0-9]{1,2}(?::[0-9]{2})?\s*(?:a\.?m\.?|p\.?m\.?)\b/i.test(value)
    || /\s+[0-9]{1,2}:[0-9]{2}\b/.test(value);
}
