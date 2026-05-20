-- v33: Conversations / Messages (Community Feature Phase 3)
-- ────────────────────────────────────────────────────────────────────────
-- Generic chat model that supports DM (type='dm') and Group (type='group').
--   * conversations              — header (denorm last_message_* for list sort)
--   * dm_pairs                   — uniqueness guard for DMs (LEAST/GREATEST)
--   * conversation_members       — membership, role, last_read_message_id
--   * messages                   — text + image + file + system
--
-- Read-receipts: stored on conversation_members.last_read_message_id.
-- Unread count = COUNT(messages WHERE id > last_read_message_id AND not deleted).
-- Soft-delete via deleted_at; messages are never hard-deleted by users.

BEGIN;

SET search_path TO cleangoal, public;

-- ── conversations ────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS cleangoal.conversations (
  conversation_id  BIGSERIAL PRIMARY KEY,
  type             VARCHAR(8) NOT NULL CHECK (type IN ('dm','group')),
  name             VARCHAR(120),                                        -- NULL = DM
  avatar_url       TEXT,
  created_by       BIGINT REFERENCES cleangoal.users(user_id) ON DELETE SET NULL,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  last_message_at  TIMESTAMPTZ,                                         -- DENORM
  last_message_id  BIGINT,                                              -- DENORM
  CONSTRAINT chk_group_has_name CHECK (type = 'dm' OR name IS NOT NULL)
);

-- หลัก: ใช้ sort list ของ user
CREATE INDEX IF NOT EXISTS idx_conversations_last_msg
  ON cleangoal.conversations (last_message_at DESC NULLS LAST);

-- ── dm_pairs ─────────────────────────────────────────────────────────────
-- แยก table เพื่อให้บังคับ uniqueness ของ DM ต่อคู่ — เขียนเข้าใน transaction
-- เดียวกับ INSERT conversations โดยมี ON CONFLICT DO NOTHING fallback ใน
-- backend handler (ป้องกัน race condition)
CREATE TABLE IF NOT EXISTS cleangoal.dm_pairs (
  user_low        BIGINT NOT NULL,
  user_high       BIGINT NOT NULL,
  conversation_id BIGINT NOT NULL UNIQUE REFERENCES cleangoal.conversations(conversation_id) ON DELETE CASCADE,
  PRIMARY KEY (user_low, user_high),
  CONSTRAINT chk_pair_ord CHECK (user_low < user_high)
);

CREATE INDEX IF NOT EXISTS idx_dm_pairs_high ON cleangoal.dm_pairs (user_high);

-- ── conversation_members ────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS cleangoal.conversation_members (
  conversation_id       BIGINT NOT NULL REFERENCES cleangoal.conversations(conversation_id) ON DELETE CASCADE,
  user_id               BIGINT NOT NULL REFERENCES cleangoal.users(user_id) ON DELETE CASCADE,
  role                  VARCHAR(8) NOT NULL DEFAULT 'member' CHECK (role IN ('admin','member')),
  joined_at             TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  last_read_message_id  BIGINT,
  muted                 BOOLEAN NOT NULL DEFAULT FALSE,
  archived              BOOLEAN NOT NULL DEFAULT FALSE,
  PRIMARY KEY (conversation_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_conv_members_user
  ON cleangoal.conversation_members (user_id);

-- ── messages ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS cleangoal.messages (
  message_id           BIGSERIAL PRIMARY KEY,
  conversation_id      BIGINT NOT NULL REFERENCES cleangoal.conversations(conversation_id) ON DELETE CASCADE,
  sender_user_id       BIGINT REFERENCES cleangoal.users(user_id) ON DELETE SET NULL,  -- NULL = system
  kind                 VARCHAR(8) NOT NULL DEFAULT 'text'
                       CHECK (kind IN ('text','image','file','system')),
  body                 TEXT,
  attachment_url       TEXT,
  attachment_mime      VARCHAR(80),
  attachment_size      INT,
  attachment_name      VARCHAR(255),
  reply_to_message_id  BIGINT REFERENCES cleangoal.messages(message_id) ON DELETE SET NULL,
  edited_at            TIMESTAMPTZ,
  deleted_at           TIMESTAMPTZ,
  created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT chk_has_content CHECK (
    body IS NOT NULL OR attachment_url IS NOT NULL OR kind = 'system'
  )
);

-- ใช้กับทั้ง history pagination (DESC) และ unread count (id > last_read)
CREATE INDEX IF NOT EXISTS idx_messages_conv_created
  ON cleangoal.messages (conversation_id, created_at DESC, message_id DESC);

CREATE INDEX IF NOT EXISTS idx_messages_sender
  ON cleangoal.messages (sender_user_id);

-- ── Trigger: maintain conversations.last_message_at / last_message_id ────
CREATE OR REPLACE FUNCTION cleangoal.trg_msg_after_insert()
RETURNS TRIGGER
LANGUAGE plpgsql SET search_path = cleangoal, public AS $$
BEGIN
  UPDATE cleangoal.conversations
     SET last_message_at = NEW.created_at,
         last_message_id = NEW.message_id
   WHERE conversation_id = NEW.conversation_id;
  RETURN NEW;
END$$;

DROP TRIGGER IF EXISTS trg_messages_after_insert ON cleangoal.messages;
CREATE TRIGGER trg_messages_after_insert
AFTER INSERT ON cleangoal.messages
FOR EACH ROW EXECUTE FUNCTION cleangoal.trg_msg_after_insert();

INSERT INTO cleangoal.schema_migrations(version) VALUES ('v33_conversations')
    ON CONFLICT (version) DO NOTHING;

COMMIT;

-- ROLLBACK:
-- BEGIN;
-- DROP TRIGGER IF EXISTS trg_messages_after_insert ON cleangoal.messages;
-- DROP FUNCTION IF EXISTS cleangoal.trg_msg_after_insert();
-- DROP TABLE IF EXISTS cleangoal.messages;
-- DROP TABLE IF EXISTS cleangoal.conversation_members;
-- DROP TABLE IF EXISTS cleangoal.dm_pairs;
-- DROP TABLE IF EXISTS cleangoal.conversations;
-- DELETE FROM cleangoal.schema_migrations WHERE version = 'v33_conversations';
-- COMMIT;
