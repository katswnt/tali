PRAGMA foreign_keys = ON;

-- Older app builds serialized UUIDs with uppercase letters while the server
-- canonicalizes new UUIDs to lowercase. SQLite TEXT primary keys are
-- case-sensitive, so the same logical event could be inserted twice.

UPDATE events
SET habit_id = (
    SELECT keeper.id
    FROM habits AS keeper
    WHERE lower(keeper.id) = lower(events.habit_id)
    ORDER BY
        CASE WHEN keeper.id = lower(keeper.id) THEN 0 ELSE 1 END,
        julianday(keeper.updated_at) DESC,
        keeper.id
    LIMIT 1
)
WHERE EXISTS (
    SELECT 1
    FROM habits AS candidate
    WHERE lower(candidate.id) = lower(events.habit_id)
);

DELETE FROM events
WHERE rowid IN (
    SELECT rowid
    FROM (
        SELECT
            rowid,
            row_number() OVER (
                PARTITION BY lower(id)
                ORDER BY
                    CASE WHEN id = lower(id) THEN 0 ELSE 1 END,
                    julianday(updated_at) DESC,
                    id
            ) AS duplicate_rank
        FROM events
    )
    WHERE duplicate_rank > 1
);

DELETE FROM habits
WHERE rowid IN (
    SELECT rowid
    FROM (
        SELECT
            rowid,
            row_number() OVER (
                PARTITION BY lower(id)
                ORDER BY
                    CASE WHEN id = lower(id) THEN 0 ELSE 1 END,
                    julianday(updated_at) DESC,
                    id
            ) AS duplicate_rank
        FROM habits
    )
    WHERE duplicate_rank > 1
);

CREATE UNIQUE INDEX IF NOT EXISTS habits_id_nocase_unique
ON habits(id COLLATE NOCASE);

CREATE UNIQUE INDEX IF NOT EXISTS events_id_nocase_unique
ON events(id COLLATE NOCASE);
