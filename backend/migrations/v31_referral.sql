-- v31: Referral / Invite system (Community Feature Phase 1)
-- ────────────────────────────────────────────────────────────────────────
-- Two-sided referral: invitee verifies email → both sides get gems + XP.
--
-- Tables:
--   referral_codes        — one immutable per-user shareable code
--   referral_invitations  — per-email invite with one-time URL token
--   referrals             — actual inviter↔invitee binding (1 per invitee)
--   referral_rewards      — audit ledger (idempotent via UNIQUE)
--
-- Helper function gen_referral_code() returns a URL-safe 8-char code.
-- Existing users get a code backfilled at the bottom of this migration.
--
-- See docs/COMMUNITY_FEATURE.md (created with this rollout) for context.

BEGIN;

SET search_path TO cleangoal, public;

-- ── gen_referral_code() ──────────────────────────────────────────────────
-- 8 chars from a Crockford-Base32-ish alphabet (no 0/O/1/I to avoid OCR
-- confusion). Loops on UNIQUE collision (probability is astronomically low
-- but we still guard against it). Marked VOLATILE because each call should
-- produce a new code.
CREATE OR REPLACE FUNCTION cleangoal.gen_referral_code()
RETURNS VARCHAR(12)
LANGUAGE plpgsql VOLATILE SET search_path = cleangoal, public AS $$
DECLARE
  alphabet TEXT := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  candidate TEXT;
  i INT;
BEGIN
  LOOP
    candidate := '';
    FOR i IN 1..8 LOOP
      candidate := candidate || substr(alphabet, 1 + floor(random() * length(alphabet))::INT, 1);
    END LOOP;
    -- restart loop if it collides (extremely rare for 32^8 = 1.1 trillion codes)
    EXIT WHEN NOT EXISTS (
      SELECT 1 FROM cleangoal.referral_codes WHERE code = candidate
    );
  END LOOP;
  RETURN candidate;
END$$;

-- ── referral_codes ───────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS cleangoal.referral_codes (
  user_id     BIGINT      PRIMARY KEY REFERENCES cleangoal.users(user_id) ON DELETE CASCADE,
  code        VARCHAR(12) NOT NULL UNIQUE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_referral_codes_code ON cleangoal.referral_codes (code);

-- ── referral_invitations ─────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS cleangoal.referral_invitations (
  invitation_id    BIGSERIAL PRIMARY KEY,
  inviter_user_id  BIGINT      NOT NULL REFERENCES cleangoal.users(user_id) ON DELETE CASCADE,
  invitee_email    TEXT        NOT NULL,                       -- always stored LOWER()
  token            VARCHAR(40) NOT NULL UNIQUE,
  status           VARCHAR(16) NOT NULL DEFAULT 'pending'
                   CHECK (status IN ('pending','sent','accepted','expired')),
  expires_at       TIMESTAMPTZ NOT NULL,
  sent_at          TIMESTAMPTZ,
  accepted_at      TIMESTAMPTZ,
  accepted_user_id BIGINT REFERENCES cleangoal.users(user_id) ON DELETE SET NULL,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- กัน inviter spam invite ซ้ำไป email เดียวกันขณะที่ยังไม่ accept/expire
CREATE UNIQUE INDEX IF NOT EXISTS uq_referral_inv_active
  ON cleangoal.referral_invitations (inviter_user_id, invitee_email)
  WHERE status IN ('pending','sent');

CREATE INDEX IF NOT EXISTS idx_referral_inv_email
  ON cleangoal.referral_invitations (invitee_email);

CREATE INDEX IF NOT EXISTS idx_referral_inv_inviter_created
  ON cleangoal.referral_invitations (inviter_user_id, created_at DESC);

-- ── referrals ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS cleangoal.referrals (
  referral_id        BIGSERIAL PRIMARY KEY,
  inviter_user_id    BIGINT NOT NULL REFERENCES cleangoal.users(user_id) ON DELETE CASCADE,
  invitee_user_id    BIGINT NOT NULL REFERENCES cleangoal.users(user_id) ON DELETE CASCADE,
  source             VARCHAR(8) NOT NULL CHECK (source IN ('link','email','code')),
  invitation_id      BIGINT REFERENCES cleangoal.referral_invitations(invitation_id) ON DELETE SET NULL,
  status             VARCHAR(16) NOT NULL DEFAULT 'pending'
                     CHECK (status IN ('pending','rewarded','revoked')),
  reward_granted_at  TIMESTAMPTZ,
  created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT chk_no_self_referral CHECK (inviter_user_id <> invitee_user_id)
);

-- 1 user เป็น invitee ได้ครั้งเดียวเท่านั้น — กัน reward farming
CREATE UNIQUE INDEX IF NOT EXISTS uq_referrals_invitee
  ON cleangoal.referrals (invitee_user_id);

CREATE INDEX IF NOT EXISTS idx_referrals_inviter
  ON cleangoal.referrals (inviter_user_id, created_at DESC);

-- ── referral_rewards (audit ledger) ──────────────────────────────────────
CREATE TABLE IF NOT EXISTS cleangoal.referral_rewards (
  reward_id    BIGSERIAL PRIMARY KEY,
  referral_id  BIGINT NOT NULL REFERENCES cleangoal.referrals(referral_id) ON DELETE CASCADE,
  user_id      BIGINT NOT NULL REFERENCES cleangoal.users(user_id) ON DELETE CASCADE,
  role         VARCHAR(8) NOT NULL CHECK (role IN ('inviter','invitee')),
  gems_delta   INT NOT NULL,
  xp_delta     INT NOT NULL,
  granted_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  -- idempotency: ทำให้ retry ของ reward-grant ไม่ award ซ้ำ
  CONSTRAINT uq_reward_per_role UNIQUE (referral_id, role)
);

CREATE INDEX IF NOT EXISTS idx_referral_rewards_user
  ON cleangoal.referral_rewards (user_id, granted_at DESC);

-- ── Backfill: ให้ทุก existing user ที่ active มี referral code ──────────
INSERT INTO cleangoal.referral_codes (user_id, code)
SELECT u.user_id, cleangoal.gen_referral_code()
FROM cleangoal.users u
WHERE u.deleted_at IS NULL
  AND NOT EXISTS (
    SELECT 1 FROM cleangoal.referral_codes rc WHERE rc.user_id = u.user_id
  );

INSERT INTO cleangoal.schema_migrations(version) VALUES ('v31_referral')
    ON CONFLICT (version) DO NOTHING;

COMMIT;

-- ROLLBACK:
-- BEGIN;
-- DROP TABLE IF EXISTS cleangoal.referral_rewards;
-- DROP TABLE IF EXISTS cleangoal.referrals;
-- DROP TABLE IF EXISTS cleangoal.referral_invitations;
-- DROP TABLE IF EXISTS cleangoal.referral_codes;
-- DROP FUNCTION IF EXISTS cleangoal.gen_referral_code();
-- DELETE FROM cleangoal.schema_migrations WHERE version = 'v31_referral';
-- COMMIT;
