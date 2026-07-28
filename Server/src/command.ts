export type Command =
  | { type: "log"; habit: string; occurredAt?: string; note?: string }
  | { type: "add"; habit: string; force: boolean }
  | { type: "since"; habit: string }
  | { type: "history"; habit: string }
  | { type: "undo" }
  | { type: "list" }
  | { type: "contact" }
  | { type: "help" };

export function normalize(value: string): string {
  return value
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLocaleLowerCase("en-US")
    .trim()
    .replace(/\s+/g, " ");
}

export function parseCommand(
  input: string,
  options: { now?: Date; timeZone?: string } = {},
): Command {
  const trimmed = input.trim();
  const value = normalize(trimmed);
  const now = options.now ?? new Date();
  const timeZone = options.timeZone ?? "UTC";

  if (["undo", "undo last", "never mind", "nevermind"].includes(value)) {
    return { type: "undo" };
  }
  if (["habits", "list", "list habits"].includes(value)) {
    return { type: "list" };
  }
  if ([
    "help",
    "commands",
    "command list",
    "menu",
    "options",
    "what can you do",
    "how do i use tali",
    "how does this work",
    "?",
  ].includes(value) || !value) {
    return { type: "help" };
  }
  if (["reshare contact", "share contact", "resend contact", "send contact"].includes(value)) {
    return { type: "contact" };
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

  const since = afterPrefix(value, [
    "time since ",
    "how long since ",
    "since ",
    "when did i ",
    "when was ",
    "last ",
  ]);
  if (since !== undefined) return since ? { type: "since", habit: since } : { type: "help" };

  const history = afterPrefix(value, ["history ", "stats "]);
  if (history !== undefined) return history ? { type: "history", habit: history } : { type: "help" };

  const logText = trimmed.replace(/^(?:#did|i\s+did|did|log)\s+/i, "");

  const [habitAndDate, ...noteParts] = logText.split(" -- ");
  const note = noteParts.join(" -- ").trim() || undefined;
  const dated = extractDate(habitAndDate, now, timeZone);
  return dated.habit ? { type: "log", habit: dated.habit, occurredAt: dated.occurredAt, note } : { type: "help" };
}

function afterPrefix(value: string, prefixes: string[]): string | undefined {
  const prefix = prefixes.find((candidate) => value.startsWith(candidate));
  return prefix ? value.slice(prefix.length).trim() : undefined;
}

function extractDate(value: string, now: Date, timeZone: string): { habit: string; occurredAt?: string } {
  const days = "today|yesterday|sunday|monday|tuesday|wednesday|thursday|friday|saturday";
  const clock = "[0-9]{1,2}(?::[0-9]{2})?\\s*(?:am|pm)?";
  let match = value.match(new RegExp(
    `\\s+(?:at\\s+)?(${clock})\\s+(?:on\\s+)?(?:(last)\\s+)?(${days})$`,
    "i",
  ));
  let explicitlyLast = Boolean(match?.[2]);
  let dayWord = match?.[3]?.toLowerCase();
  let clockValue = match?.[1];

  if (!match) {
    match = value.match(new RegExp(
      `\\s+(?:on\\s+)?(?:(last)\\s+)?(${days})(?:\\s+(?:at\\s+)?(${clock}))?$`,
      "i",
    ));
    explicitlyLast = Boolean(match?.[1]);
    dayWord = match?.[2]?.toLowerCase();
    clockValue = match?.[3];
  }

  if (!match || match.index === undefined || !dayWord) return { habit: value.trim() };

  const time = parseTime(clockValue);
  const dayOffset = offsetForDay(dayWord, now, timeZone, explicitlyLast);
  let occurredAt = dateInTimeZone(now, timeZone, dayOffset, time.hour, time.minute);
  if (weekdayNumber(dayWord) !== null && !explicitlyLast && occurredAt > now) {
    occurredAt = dateInTimeZone(now, timeZone, dayOffset - 7, time.hour, time.minute);
  }
  return {
    habit: value.slice(0, match.index).trim(),
    occurredAt: occurredAt.toISOString(),
  };
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

function parseTime(value?: string): { hour: number; minute: number } {
  if (!value) return { hour: 0, minute: 0 };
  const compact = value.toLowerCase().replace(/\s/g, "");
  const match = compact.match(/^(\d{1,2})(?::(\d{2}))?(am|pm)?$/);
  if (!match) return { hour: 0, minute: 0 };
  let hour = Number(match[1]);
  const minute = Number(match[2] ?? 0);
  if (match[3] === "pm" && hour < 12) hour += 12;
  if (match[3] === "am" && hour === 12) hour = 0;
  return { hour, minute };
}

function dateInTimeZone(
  now: Date,
  timeZone: string,
  dayOffset: number,
  hour: number,
  minute: number,
): Date {
  const parts = zonedParts(now, timeZone);
  const targetWallClock = Date.UTC(parts.year, parts.month - 1, parts.day + dayOffset, hour, minute);
  let candidate = new Date(targetWallClock);
  for (let index = 0; index < 2; index += 1) {
    candidate = new Date(targetWallClock - zoneOffsetMilliseconds(candidate, timeZone));
  }
  return candidate;
}

function zonedParts(date: Date, timeZone: string): { year: number; month: number; day: number } {
  const formatter = new Intl.DateTimeFormat("en-US", {
    timeZone,
    year: "numeric",
    month: "numeric",
    day: "numeric",
  });
  const values = Object.fromEntries(formatter.formatToParts(date).map((part) => [part.type, part.value]));
  return { year: Number(values.year), month: Number(values.month), day: Number(values.day) };
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
