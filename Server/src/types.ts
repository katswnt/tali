export interface Env {
  DB: D1Database;
  SYNC_TOKEN: string;
  OWNER_PHONE: string;
  OWNER_TIME_ZONE: string;
  APPLE_CLIENT_ID: string;
  TWILIO_AUTH_TOKEN: string;
  ALLOW_UNSIGNED_TWILIO?: string;
}

export const LEGACY_USER_ID = "00000000-0000-4000-8000-000000000001";

export interface AuthenticatedUser {
  id: string;
  timeZone: string;
  authentication: "legacy" | "session";
}

export interface HabitDTO {
  id: string;
  name: string;
  aliases: string[];
  createdAt: string;
  updatedAt: string;
  isArchived: boolean;
}

export interface EventDTO {
  id: string;
  habitId: string;
  occurredAt: string;
  createdAt: string;
  updatedAt: string;
  source: string;
  note?: string | null;
  voidedAt?: string | null;
}

export interface SyncSnapshot {
  habits: HabitDTO[];
  events: EventDTO[];
}

export interface HabitRow {
  id: string;
  user_id: string;
  name: string;
  normalized_name: string;
  aliases_json: string;
  created_at: string;
  updated_at: string;
  is_archived: number;
}

export interface EventRow {
  id: string;
  user_id: string;
  habit_id: string;
  occurred_at: string;
  created_at: string;
  updated_at: string;
  source: string;
  note: string | null;
  voided_at: string | null;
}
