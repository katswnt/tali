import { mergeSnapshot, readSnapshot } from "./database";
import type { SyncSnapshot } from "./types";

export interface VersionedSyncInput {
  baseRevision: number;
  mutationID: string;
  snapshot: SyncSnapshot;
}

export async function versionedSync(
  db: D1Database,
  userID: string,
  input: VersionedSyncInput,
): Promise<Response> {
  await ensureSyncState(db, userID);

  const prior = await db.prepare(`
    SELECT revision FROM sync_mutations
    WHERE user_id = ? AND mutation_id = ?
  `).bind(userID, input.mutationID).first<{ revision: number }>();
  if (prior) return versionedSnapshotResponse(db, userID, await currentRevision(db, userID));

  const current = await currentRevision(db, userID);
  if (input.baseRevision !== current) {
    return Response.json({
      error: "Sync cursor is stale. Merge the server snapshot and retry.",
      code: "stale_revision",
      revision: current,
      snapshot: await readSnapshot(db, userID),
    }, { status: 409, headers: { "cache-control": "no-store" } });
  }

  // Reserve the next revision with a compare-and-swap before applying the
  // idempotent last-write-wins merge. A racing request loses cleanly.
  const nextRevision = current + 1;
  const reserved = await db.prepare(`
    UPDATE sync_state SET revision = ?, updated_at = ?
    WHERE user_id = ? AND revision = ?
  `).bind(nextRevision, new Date().toISOString(), userID, current).run();
  if ((reserved.meta.changes ?? 0) !== 1) {
    const latest = await currentRevision(db, userID);
    return Response.json({
      error: "Sync cursor changed during the request. Merge the server snapshot and retry.",
      code: "stale_revision",
      revision: latest,
      snapshot: await readSnapshot(db, userID),
    }, { status: 409, headers: { "cache-control": "no-store" } });
  }

  await mergeSnapshot(db, userID, input.snapshot, { bumpRevision: false });
  await db.prepare(`
    INSERT INTO sync_mutations (user_id, mutation_id, revision, created_at)
    VALUES (?, ?, ?, ?)
  `).bind(userID, input.mutationID, nextRevision, new Date().toISOString()).run();
  await pruneMutationHistory(db, userID);
  return versionedSnapshotResponse(db, userID, nextRevision);
}

async function ensureSyncState(db: D1Database, userID: string): Promise<void> {
  await db.prepare(`
    INSERT OR IGNORE INTO sync_state (user_id, revision, updated_at)
    VALUES (?, 0, ?)
  `).bind(userID, new Date().toISOString()).run();
}

async function currentRevision(db: D1Database, userID: string): Promise<number> {
  const row = await db.prepare("SELECT revision FROM sync_state WHERE user_id = ?")
    .bind(userID)
    .first<{ revision: number }>();
  return row?.revision ?? 0;
}

async function versionedSnapshotResponse(
  db: D1Database,
  userID: string,
  revision: number,
): Promise<Response> {
  return Response.json({
    revision,
    snapshot: await readSnapshot(db, userID),
  }, { headers: { "cache-control": "no-store" } });
}

async function pruneMutationHistory(db: D1Database, userID: string): Promise<void> {
  await db.prepare(`
    DELETE FROM sync_mutations
    WHERE user_id = ?
      AND mutation_id NOT IN (
        SELECT mutation_id FROM sync_mutations
        WHERE user_id = ?
        ORDER BY revision DESC
        LIMIT 500
      )
  `).bind(userID, userID).run();
}
