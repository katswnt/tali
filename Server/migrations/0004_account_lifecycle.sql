ALTER TABLE sessions
ADD COLUMN device_name TEXT NOT NULL DEFAULT 'Unknown device';

ALTER TABLE sessions
ADD COLUMN last_used_at TEXT;

UPDATE sessions
SET last_used_at = created_at
WHERE last_used_at IS NULL;

CREATE INDEX IF NOT EXISTS sessions_user_activity
ON sessions(user_id, revoked_at, expires_at);
