CREATE TABLE IF NOT EXISTS spent_refresh_tokens (
    token_hash TEXT PRIMARY KEY,
    user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    session_id TEXT NOT NULL,
    spent_at TEXT NOT NULL,
    expires_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS spent_refresh_tokens_user_id
ON spent_refresh_tokens(user_id);

CREATE INDEX IF NOT EXISTS spent_refresh_tokens_expires_at
ON spent_refresh_tokens(expires_at);
