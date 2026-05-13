-- v29: Add gems currency to user_gamification (Gamification Redesign)
-- gems = spendable currency (expires 30 days), tama_points = XP (permanent, for tier)

ALTER TABLE cleangoal.user_gamification
  ADD COLUMN IF NOT EXISTS gems            INTEGER     NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS gems_updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();
