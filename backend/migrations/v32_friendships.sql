-- v32: Friendships (Community Feature Phase 2)
-- ────────────────────────────────────────────────────────────────────────
-- Two-row directed model:
--   * (A → B, status='pending')   — A requested
--   * (B → A, status='pending')   — does NOT exist yet
--   * On accept, app updates the existing row to 'accepted' and the trigger
--     inserts the mirror row (B → A, 'accepted') if not present.
--   * Block is unilateral — only the blocker's row goes to 'blocked'.
--
-- Why two-row: RLS becomes a simple `WHERE user_id = current_user_id()`;
-- easy to distinguish "I sent" vs "I received"; clean block semantics.

BEGIN;

SET search_path TO cleangoal, public;

CREATE TABLE IF NOT EXISTS cleangoal.friendships (
  user_id     BIGINT NOT NULL REFERENCES cleangoal.users(user_id) ON DELETE CASCADE,
  friend_id   BIGINT NOT NULL REFERENCES cleangoal.users(user_id) ON DELETE CASCADE,
  status      VARCHAR(12) NOT NULL DEFAULT 'pending'
              CHECK (status IN ('pending','accepted','blocked')),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  accepted_at TIMESTAMPTZ,
  PRIMARY KEY (user_id, friend_id),
  CONSTRAINT chk_no_self_friend CHECK (user_id <> friend_id)
);

-- ใช้ query reverse: "ใครส่งคำขอเป็นเพื่อนกับฉันบ้าง" (รับฝั่ง friend_id)
CREATE INDEX IF NOT EXISTS idx_friendships_friend
  ON cleangoal.friendships (friend_id, status);

-- ── Mirror trigger: ตอน accept ให้ insert/update inverse row ─────────────
CREATE OR REPLACE FUNCTION cleangoal.trg_friendships_accept_mirror()
RETURNS TRIGGER
LANGUAGE plpgsql SET search_path = cleangoal, public AS $$
BEGIN
  IF NEW.status = 'accepted' AND (TG_OP = 'INSERT' OR OLD.status IS DISTINCT FROM 'accepted') THEN
    INSERT INTO cleangoal.friendships (user_id, friend_id, status, created_at, accepted_at)
    VALUES (NEW.friend_id, NEW.user_id, 'accepted', COALESCE(NEW.created_at, NOW()), NOW())
    ON CONFLICT (user_id, friend_id) DO UPDATE
      SET status = 'accepted',
          accepted_at = COALESCE(cleangoal.friendships.accepted_at, NOW())
      -- ถ้าฝั่ง inverse เป็น 'blocked' อยู่ ไม่ overwrite (โดน WHERE clause กรอง)
      WHERE cleangoal.friendships.status <> 'blocked';
  END IF;
  RETURN NEW;
END$$;

DROP TRIGGER IF EXISTS trg_friendships_accept_mirror ON cleangoal.friendships;
CREATE TRIGGER trg_friendships_accept_mirror
AFTER INSERT OR UPDATE OF status ON cleangoal.friendships
FOR EACH ROW EXECUTE FUNCTION cleangoal.trg_friendships_accept_mirror();

INSERT INTO cleangoal.schema_migrations(version) VALUES ('v32_friendships')
    ON CONFLICT (version) DO NOTHING;

COMMIT;

-- ROLLBACK:
-- BEGIN;
-- DROP TRIGGER IF EXISTS trg_friendships_accept_mirror ON cleangoal.friendships;
-- DROP FUNCTION IF EXISTS cleangoal.trg_friendships_accept_mirror();
-- DROP TABLE IF EXISTS cleangoal.friendships;
-- DELETE FROM cleangoal.schema_migrations WHERE version = 'v32_friendships';
-- COMMIT;
