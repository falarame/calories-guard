-- v36: users.pending_referral_code — transient holder between register and verify_email
-- ────────────────────────────────────────────────────────────────────────
-- Lives on users (not in a side table) because:
--   * It's read exactly once — right after is_email_verified flips to TRUE.
--   * No cross-table join needed; reward grant clears it on success.
-- Holds either a permanent code (referral_codes.code) or a one-time token
-- (referral_invitations.token); the grant logic disambiguates by looking
-- the value up in each table.

BEGIN;

SET search_path TO cleangoal, public;

ALTER TABLE cleangoal.users
  ADD COLUMN IF NOT EXISTS pending_referral_code VARCHAR(40);

INSERT INTO cleangoal.schema_migrations(version) VALUES ('v36_users_pending_referral')
    ON CONFLICT (version) DO NOTHING;

COMMIT;

-- ROLLBACK:
-- BEGIN;
-- ALTER TABLE cleangoal.users DROP COLUMN IF EXISTS pending_referral_code;
-- DELETE FROM cleangoal.schema_migrations WHERE version = 'v36_users_pending_referral';
-- COMMIT;
