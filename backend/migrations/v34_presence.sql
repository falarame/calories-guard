-- v34: User presence (Community Feature Phase 4)
-- ────────────────────────────────────────────────────────────────────────
-- One row per user. Updated by the /presence/heartbeat backend endpoint and
-- by a background sweeper that flips stale 'online' rows to 'offline' after
-- 3 minutes of inactivity.
--
-- We do NOT add this table to the supabase_realtime publication — Flutter
-- uses Supabase Presence (channel `presence:user_global`) for the live
-- "green dot". The DB row only powers the "last seen 5 min ago" copy in
-- the conversations list (loaded with the REST seed).

BEGIN;

SET search_path TO cleangoal, public;

CREATE TABLE IF NOT EXISTS cleangoal.user_presence (
  user_id      BIGINT PRIMARY KEY REFERENCES cleangoal.users(user_id) ON DELETE CASCADE,
  status       VARCHAR(8) NOT NULL DEFAULT 'offline' CHECK (status IN ('online','away','offline')),
  last_seen_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_user_presence_last_seen
  ON cleangoal.user_presence (last_seen_at DESC);

INSERT INTO cleangoal.schema_migrations(version) VALUES ('v34_presence')
    ON CONFLICT (version) DO NOTHING;

COMMIT;

-- ROLLBACK:
-- BEGIN;
-- DROP TABLE IF EXISTS cleangoal.user_presence;
-- DELETE FROM cleangoal.schema_migrations WHERE version = 'v34_presence';
-- COMMIT;
