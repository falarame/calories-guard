-- v29: FCM token + last_active_at tracking on users.
--
-- Adds:
--   * fcm_token              — Firebase Cloud Messaging device token (nullable)
--   * fcm_token_updated_at   — last upsert timestamp; helps prune stale tokens
--   * last_active_at         — touched by authenticated middleware, drives
--                              server-side re-engagement push (Tier 3.2).
--
-- Idempotent: re-running won't add the columns twice.

BEGIN;

SET search_path TO cleangoal, public;

ALTER TABLE cleangoal.users
  ADD COLUMN IF NOT EXISTS fcm_token TEXT,
  ADD COLUMN IF NOT EXISTS fcm_token_updated_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS last_active_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_users_last_active_at
  ON cleangoal.users(last_active_at)
  WHERE deleted_at IS NULL AND fcm_token IS NOT NULL;

COMMIT;
