import { sha256 } from "./auth";
import { LEGACY_USER_ID } from "./types";

const PAIRING_LIFETIME_MS = 10 * 60 * 1_000;
const PAIRING_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";

export async function createPairingCode(db: D1Database, userID: string): Promise<Response> {
  const now = new Date();
  const expiresAt = new Date(now.getTime() + PAIRING_LIFETIME_MS).toISOString();
  const code = pairingCode();
  await db.batch([
    db.prepare("DELETE FROM pairing_codes WHERE user_id = ? AND used_at IS NULL").bind(userID),
    db.prepare("DELETE FROM pairing_codes WHERE expires_at <= ?").bind(now.toISOString()),
    db.prepare(`
      INSERT INTO pairing_codes (code_hash, user_id, created_at, expires_at, used_at)
      VALUES (?, ?, ?, ?, NULL)
    `).bind(await sha256(code), userID, now.toISOString(), expiresAt),
  ]);
  return Response.json({ code, expiresAt });
}

export async function pairPhone(
  db: D1Database,
  code: string,
  phone: string,
  ownerPhone: string,
): Promise<string> {
  const codeHash = await sha256(code.toUpperCase());
  const now = new Date().toISOString();
  const pairing = await db.prepare(`
    SELECT user_id FROM pairing_codes
    WHERE code_hash = ? AND used_at IS NULL AND expires_at > ?
  `).bind(codeHash, now).first<{ user_id: string }>();
  if (!pairing) return "That pairing code is invalid or expired. Create a new code in Tali.";

  let targetUserID = pairing.user_id;
  if (phone === ownerPhone && targetUserID !== LEGACY_USER_ID) {
    targetUserID = await claimLegacyAccount(db, targetUserID, now);
  }

  const existing = await db.prepare("SELECT user_id FROM phone_numbers WHERE phone = ?")
    .bind(phone)
    .first<{ user_id: string }>();
  if (existing && existing.user_id !== targetUserID) {
    return "This phone number is already connected to another Tali account.";
  }

  await db.batch([
    db.prepare(`
      INSERT INTO phone_numbers (phone, user_id, paired_at) VALUES (?, ?, ?)
      ON CONFLICT(phone) DO UPDATE SET paired_at = excluded.paired_at
      WHERE phone_numbers.user_id = excluded.user_id
    `).bind(phone, targetUserID, now),
    db.prepare("UPDATE pairing_codes SET used_at = ? WHERE code_hash = ?").bind(now, codeHash),
  ]);
  return "Tali connected this number. Open the app and sync when you want to refresh its data.";
}

export async function userForPhone(
  db: D1Database,
  phone: string,
  ownerPhone: string,
  ownerTimeZone: string,
): Promise<{ id: string; timeZone: string } | null> {
  const row = await db.prepare(`
    SELECT users.id, users.time_zone
    FROM phone_numbers JOIN users ON users.id = phone_numbers.user_id
    WHERE phone_numbers.phone = ?
  `).bind(phone).first<{ id: string; time_zone: string }>();
  if (row) return { id: row.id, timeZone: row.time_zone };
  return phone === ownerPhone ? { id: LEGACY_USER_ID, timeZone: ownerTimeZone || "UTC" } : null;
}

export function pairingCodeFromMessage(message: string): string | null {
  const match = /^\s*pair\s+([a-z2-9]{8})\s*$/i.exec(message);
  return match?.[1]?.toUpperCase() ?? null;
}

async function claimLegacyAccount(db: D1Database, temporaryUserID: string, now: string): Promise<string> {
  const [legacy, temporary] = await Promise.all([
    db.prepare("SELECT apple_subject FROM users WHERE id = ?").bind(LEGACY_USER_ID)
      .first<{ apple_subject: string | null }>(),
    db.prepare("SELECT apple_subject, time_zone FROM users WHERE id = ?").bind(temporaryUserID)
      .first<{ apple_subject: string | null; time_zone: string }>(),
  ]);
  if (!legacy || !temporary?.apple_subject || legacy.apple_subject) return temporaryUserID;

  await db.batch([
    db.prepare("UPDATE users SET apple_subject = NULL, updated_at = ? WHERE id = ?")
      .bind(now, temporaryUserID),
    db.prepare("UPDATE users SET apple_subject = ?, time_zone = ?, updated_at = ? WHERE id = ?")
      .bind(temporary.apple_subject, temporary.time_zone, now, LEGACY_USER_ID),
    db.prepare("UPDATE sessions SET user_id = ? WHERE user_id = ?")
      .bind(LEGACY_USER_ID, temporaryUserID),
    db.prepare("DELETE FROM users WHERE id = ?").bind(temporaryUserID),
  ]);
  return LEGACY_USER_ID;
}

function pairingCode(): string {
  const random = crypto.getRandomValues(new Uint8Array(8));
  return [...random].map((byte) => PAIRING_ALPHABET[byte % PAIRING_ALPHABET.length]).join("");
}
