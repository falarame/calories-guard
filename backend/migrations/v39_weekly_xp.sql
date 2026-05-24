-- v39: Add weekly_xp + weekly_xp_week to user_gamification (V2.1 Gamification)
-- weekly_xp resets every Monday (managed by Flutter client + POST /weekly-reset-claim)
-- weekly_xp_week: ISO week key e.g. "2026-W21" — detects rollover on client

ALTER TABLE cleangoal.user_gamification
  ADD COLUMN IF NOT EXISTS weekly_xp      INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS weekly_xp_week TEXT    NOT NULL DEFAULT '';

CREATE INDEX IF NOT EXISTS idx_user_gamification_weekly_xp
  ON cleangoal.user_gamification (weekly_xp DESC);
