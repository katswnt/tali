CREATE TABLE IF NOT EXISTS rate_limits (
    key TEXT PRIMARY KEY,
    window_start TEXT NOT NULL,
    count INTEGER NOT NULL,
    expires_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS rate_limits_expiration
ON rate_limits(expires_at);
