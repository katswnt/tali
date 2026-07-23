import { logOperational } from "./observability";

export const RETENTION = {
  pairingHistoryDays: 1,
  revokedSessionDays: 30,
  smsReceiptDays: 30,
} as const;

export function retentionCutoffs(now = new Date()): {
  pairing: string;
  session: string;
  sms: string;
  current: string;
} {
  const daysAgo = (days: number) =>
    new Date(now.getTime() - days * 24 * 60 * 60 * 1_000).toISOString();
  return {
    pairing: daysAgo(RETENTION.pairingHistoryDays),
    session: daysAgo(RETENTION.revokedSessionDays),
    sms: daysAgo(RETENTION.smsReceiptDays),
    current: now.toISOString(),
  };
}

export async function enforceRetention(db: D1Database, now = new Date()): Promise<void> {
  const cutoffs = retentionCutoffs(now);
  const results = await db.batch([
    db.prepare(`
      DELETE FROM pairing_codes
      WHERE expires_at < ? AND (used_at IS NULL OR used_at < ?)
    `).bind(cutoffs.pairing, cutoffs.pairing),
    db.prepare(`
      DELETE FROM sessions
      WHERE (revoked_at IS NOT NULL AND revoked_at < ?)
         OR (expires_at < ? AND expires_at < ?)
    `).bind(cutoffs.session, cutoffs.current, cutoffs.session),
    db.prepare("DELETE FROM sms_messages WHERE created_at < ?").bind(cutoffs.sms),
    db.prepare("DELETE FROM rate_limits WHERE expires_at < ?").bind(cutoffs.current),
  ]);

  logOperational("info", "retention.completed", {
    pairingCodesDeleted: results[0]?.meta.changes ?? 0,
    sessionsDeleted: results[1]?.meta.changes ?? 0,
    smsReceiptsDeleted: results[2]?.meta.changes ?? 0,
    rateLimitsDeleted: results[3]?.meta.changes ?? 0,
  });
}
