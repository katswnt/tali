ALTER TABLE sessions
ADD COLUMN refresh_token_hash TEXT;

ALTER TABLE sessions
ADD COLUMN previous_refresh_token_hash TEXT;

ALTER TABLE sessions
ADD COLUMN access_expires_at TEXT;

UPDATE sessions
SET access_expires_at = expires_at
WHERE access_expires_at IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS sessions_refresh_token_hash
ON sessions(refresh_token_hash)
WHERE refresh_token_hash IS NOT NULL;

CREATE INDEX IF NOT EXISTS sessions_previous_refresh_token_hash
ON sessions(previous_refresh_token_hash)
WHERE previous_refresh_token_hash IS NOT NULL;
