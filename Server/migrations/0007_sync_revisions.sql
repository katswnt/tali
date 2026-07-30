CREATE TABLE IF NOT EXISTS sync_state (
    user_id TEXT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    revision INTEGER NOT NULL DEFAULT 0,
    updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS sync_mutations (
    user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    mutation_id TEXT NOT NULL,
    revision INTEGER NOT NULL,
    created_at TEXT NOT NULL,
    PRIMARY KEY (user_id, mutation_id)
);

CREATE INDEX IF NOT EXISTS sync_mutations_created_at
ON sync_mutations(created_at);
