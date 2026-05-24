-- v38: Referral code system + gem buff buff
CREATE TABLE IF NOT EXISTS cleangoal.referral_codes (
    code        TEXT PRIMARY KEY,
    owner_id    INT  NOT NULL REFERENCES cleangoal.users(user_id) ON DELETE CASCADE,
    created_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS cleangoal.referral_redemptions (
    redemption_id  SERIAL PRIMARY KEY,
    code           TEXT NOT NULL REFERENCES cleangoal.referral_codes(code) ON DELETE CASCADE,
    redeemed_by    INT  NOT NULL UNIQUE REFERENCES cleangoal.users(user_id) ON DELETE CASCADE,
    redeemed_at    TIMESTAMPTZ DEFAULT NOW()
);

-- Gem buff: multiplier applied to mission gem rewards, expires after 7 days
ALTER TABLE cleangoal.user_gamification
  ADD COLUMN IF NOT EXISTS gem_buff_multiplier  INT         NOT NULL DEFAULT 1,
  ADD COLUMN IF NOT EXISTS gem_buff_expires_at  TIMESTAMPTZ;
