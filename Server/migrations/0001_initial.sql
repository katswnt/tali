PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS habits (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    normalized_name TEXT NOT NULL,
    aliases_json TEXT NOT NULL DEFAULT '[]',
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    is_archived INTEGER NOT NULL DEFAULT 0
);

CREATE INDEX IF NOT EXISTS habits_normalized_name
ON habits(normalized_name);

CREATE TABLE IF NOT EXISTS events (
    id TEXT PRIMARY KEY,
    habit_id TEXT NOT NULL REFERENCES habits(id) ON DELETE CASCADE,
    occurred_at TEXT NOT NULL,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    source TEXT NOT NULL,
    note TEXT,
    voided_at TEXT
);

CREATE INDEX IF NOT EXISTS events_habit_occurred
ON events(habit_id, occurred_at DESC);

CREATE TABLE IF NOT EXISTS sms_messages (
    sid TEXT PRIMARY KEY,
    from_phone TEXT NOT NULL,
    body TEXT NOT NULL,
    response TEXT NOT NULL,
    created_at TEXT NOT NULL
);
