PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS users (
    id TEXT PRIMARY KEY,
    apple_subject TEXT UNIQUE,
    time_zone TEXT NOT NULL DEFAULT 'UTC',
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS sessions (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash TEXT NOT NULL UNIQUE,
    created_at TEXT NOT NULL,
    expires_at TEXT NOT NULL,
    revoked_at TEXT
);

CREATE INDEX IF NOT EXISTS sessions_user_id
ON sessions(user_id);

CREATE TABLE IF NOT EXISTS phone_numbers (
    phone TEXT PRIMARY KEY,
    user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    paired_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS phone_numbers_user_id
ON phone_numbers(user_id);

CREATE TABLE IF NOT EXISTS pairing_codes (
    code_hash TEXT PRIMARY KEY,
    user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TEXT NOT NULL,
    expires_at TEXT NOT NULL,
    used_at TEXT
);

CREATE INDEX IF NOT EXISTS pairing_codes_user_id
ON pairing_codes(user_id);

INSERT OR IGNORE INTO users (id, apple_subject, time_zone, created_at, updated_at)
VALUES (
    '00000000-0000-4000-8000-000000000001',
    NULL,
    'America/Los_Angeles',
    strftime('%Y-%m-%dT%H:%M:%fZ', 'now'),
    strftime('%Y-%m-%dT%H:%M:%fZ', 'now')
);

ALTER TABLE habits
ADD COLUMN user_id TEXT NOT NULL DEFAULT '00000000-0000-4000-8000-000000000001';

ALTER TABLE events
ADD COLUMN user_id TEXT NOT NULL DEFAULT '00000000-0000-4000-8000-000000000001';

ALTER TABLE sms_messages
ADD COLUMN user_id TEXT NOT NULL DEFAULT '00000000-0000-4000-8000-000000000001';

DROP INDEX IF EXISTS habits_normalized_name_unique;

CREATE UNIQUE INDEX IF NOT EXISTS habits_user_normalized_name_unique
ON habits(user_id, normalized_name);

CREATE INDEX IF NOT EXISTS habits_user_id
ON habits(user_id);

CREATE INDEX IF NOT EXISTS events_user_id
ON events(user_id);

CREATE INDEX IF NOT EXISTS sms_messages_user_id
ON sms_messages(user_id);
