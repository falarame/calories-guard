-- v35: Realtime publication + RLS policies for Community tables
-- ────────────────────────────────────────────────────────────────────────
-- Why this is its own migration:
--   * Realtime requires REPLICA IDENTITY FULL + table-in-publication.
--   * The new tables also need per-user RLS that joins to Supabase's
--     auth.jwt() — kept here so it's auditable in one place.
--
-- Backend continues to use the service role (RLS-bypassing). RLS only
-- gates direct Realtime/PostgREST access from authenticated Flutter clients.

BEGIN;

SET search_path TO cleangoal, public;

-- ── current_user_id(): JWT app_metadata.user_id → BIGINT ─────────────────
-- Every RLS policy below calls this. SECURITY DEFINER so it can read
-- auth.jwt() regardless of caller's grants on the auth schema. STABLE so
-- the planner can cache its value across a single statement.
CREATE OR REPLACE FUNCTION cleangoal.current_user_id() RETURNS BIGINT
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = cleangoal, public AS $$
  SELECT NULLIF((auth.jwt() -> 'app_metadata' ->> 'user_id'), '')::BIGINT
$$;
REVOKE ALL ON FUNCTION cleangoal.current_user_id() FROM public;
GRANT EXECUTE ON FUNCTION cleangoal.current_user_id() TO authenticated, anon;

-- ── Enable RLS + drop legacy deny policies (none exist yet for new tables,
--    but the v15_c pattern uses the same naming so DROP IF EXISTS is safe) ─
DO $$
DECLARE t text;
DECLARE tables text[] := ARRAY[
    'referral_codes',
    'referral_invitations',
    'referrals',
    'referral_rewards',
    'friendships',
    'conversations',
    'dm_pairs',
    'conversation_members',
    'messages',
    'user_presence'
];
BEGIN
  FOREACH t IN ARRAY tables LOOP
    EXECUTE format('ALTER TABLE cleangoal.%I ENABLE ROW LEVEL SECURITY;', t);
    EXECUTE format('DROP POLICY IF EXISTS "deny_anon" ON cleangoal.%I;', t);
    EXECUTE format('DROP POLICY IF EXISTS "deny_authed_until_auth_migration" ON cleangoal.%I;', t);
    -- anon never has any business here
    EXECUTE format(
      'CREATE POLICY "deny_anon" ON cleangoal.%I
         AS PERMISSIVE FOR ALL TO anon USING (false) WITH CHECK (false);',
      t);
  END LOOP;
END$$;

-- ────────────────────────────────────────────────────────────────────────
-- referral_codes: each user reads their own; writes via backend only
-- ────────────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS referral_codes_self_read ON cleangoal.referral_codes;
CREATE POLICY referral_codes_self_read ON cleangoal.referral_codes
  FOR SELECT TO authenticated
  USING (user_id = cleangoal.current_user_id());

-- ────────────────────────────────────────────────────────────────────────
-- referral_invitations: inviter reads their own outgoing invites
-- ────────────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS referral_inv_self_read ON cleangoal.referral_invitations;
CREATE POLICY referral_inv_self_read ON cleangoal.referral_invitations
  FOR SELECT TO authenticated
  USING (inviter_user_id = cleangoal.current_user_id());

-- ────────────────────────────────────────────────────────────────────────
-- referrals: both parties can see their bond
-- ────────────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS referrals_party_read ON cleangoal.referrals;
CREATE POLICY referrals_party_read ON cleangoal.referrals
  FOR SELECT TO authenticated
  USING (inviter_user_id = cleangoal.current_user_id()
      OR invitee_user_id = cleangoal.current_user_id());

-- ────────────────────────────────────────────────────────────────────────
-- referral_rewards: a user reads only rewards granted to themselves
-- ────────────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS referral_rewards_self_read ON cleangoal.referral_rewards;
CREATE POLICY referral_rewards_self_read ON cleangoal.referral_rewards
  FOR SELECT TO authenticated
  USING (user_id = cleangoal.current_user_id());

-- ────────────────────────────────────────────────────────────────────────
-- friendships: user sees own rows (both directions exist as 2 rows)
-- ────────────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS friendships_self_read ON cleangoal.friendships;
CREATE POLICY friendships_self_read ON cleangoal.friendships
  FOR SELECT TO authenticated
  USING (user_id = cleangoal.current_user_id()
      OR friend_id = cleangoal.current_user_id());

-- ────────────────────────────────────────────────────────────────────────
-- conversations: visible only if user is a member
-- ────────────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS conversations_member_read ON cleangoal.conversations;
CREATE POLICY conversations_member_read ON cleangoal.conversations
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM cleangoal.conversation_members m
       WHERE m.conversation_id = conversations.conversation_id
         AND m.user_id = cleangoal.current_user_id()
    )
  );

-- ────────────────────────────────────────────────────────────────────────
-- dm_pairs: helper table, members of the embedded conversation can read
-- ────────────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS dm_pairs_member_read ON cleangoal.dm_pairs;
CREATE POLICY dm_pairs_member_read ON cleangoal.dm_pairs
  FOR SELECT TO authenticated
  USING (
    user_low  = cleangoal.current_user_id()
 OR user_high = cleangoal.current_user_id()
  );

-- ────────────────────────────────────────────────────────────────────────
-- conversation_members
--   * SELECT: I can see my own membership rows AND the rows of other
--             members in conversations I belong to (so I can render the
--             member list of a group chat).
--   * UPDATE: only mutate my own row (e.g. last_read_message_id, muted).
-- ────────────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS conv_members_read ON cleangoal.conversation_members;
CREATE POLICY conv_members_read ON cleangoal.conversation_members
  FOR SELECT TO authenticated
  USING (
    user_id = cleangoal.current_user_id()
    OR EXISTS (
      SELECT 1 FROM cleangoal.conversation_members me
       WHERE me.conversation_id = conversation_members.conversation_id
         AND me.user_id = cleangoal.current_user_id()
    )
  );

DROP POLICY IF EXISTS conv_members_self_update ON cleangoal.conversation_members;
CREATE POLICY conv_members_self_update ON cleangoal.conversation_members
  FOR UPDATE TO authenticated
  USING (user_id = cleangoal.current_user_id())
  WITH CHECK (user_id = cleangoal.current_user_id());

-- ────────────────────────────────────────────────────────────────────────
-- messages
--   * SELECT: members of the conversation
--   * INSERT: sender_user_id must equal me AND I am a member
--   * UPDATE: sender only (edit own message)
-- ────────────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS messages_member_read ON cleangoal.messages;
CREATE POLICY messages_member_read ON cleangoal.messages
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM cleangoal.conversation_members m
       WHERE m.conversation_id = messages.conversation_id
         AND m.user_id = cleangoal.current_user_id()
    )
  );

DROP POLICY IF EXISTS messages_member_insert ON cleangoal.messages;
CREATE POLICY messages_member_insert ON cleangoal.messages
  FOR INSERT TO authenticated
  WITH CHECK (
    sender_user_id = cleangoal.current_user_id()
    AND EXISTS (
      SELECT 1 FROM cleangoal.conversation_members m
       WHERE m.conversation_id = messages.conversation_id
         AND m.user_id = cleangoal.current_user_id()
    )
  );

DROP POLICY IF EXISTS messages_self_update ON cleangoal.messages;
CREATE POLICY messages_self_update ON cleangoal.messages
  FOR UPDATE TO authenticated
  USING (sender_user_id = cleangoal.current_user_id())
  WITH CHECK (sender_user_id = cleangoal.current_user_id());

-- ────────────────────────────────────────────────────────────────────────
-- user_presence: readable by any authenticated user (status is public-among
-- logged-in). Writes only via backend (service role).
-- ────────────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS presence_read_all ON cleangoal.user_presence;
CREATE POLICY presence_read_all ON cleangoal.user_presence
  FOR SELECT TO authenticated USING (true);

-- ────────────────────────────────────────────────────────────────────────
-- Realtime publication — only the 3 tables Flutter subscribes to
-- ────────────────────────────────────────────────────────────────────────
ALTER TABLE cleangoal.messages              REPLICA IDENTITY FULL;
ALTER TABLE cleangoal.conversation_members  REPLICA IDENTITY FULL;
ALTER TABLE cleangoal.conversations         REPLICA IDENTITY FULL;

-- ADD TABLE is idempotent only by virtue of pg_publication_tables check
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
     WHERE pubname = 'supabase_realtime'
       AND schemaname = 'cleangoal'
       AND tablename = 'messages'
  ) THEN
    EXECUTE 'ALTER PUBLICATION supabase_realtime ADD TABLE cleangoal.messages';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
     WHERE pubname = 'supabase_realtime'
       AND schemaname = 'cleangoal'
       AND tablename = 'conversation_members'
  ) THEN
    EXECUTE 'ALTER PUBLICATION supabase_realtime ADD TABLE cleangoal.conversation_members';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
     WHERE pubname = 'supabase_realtime'
       AND schemaname = 'cleangoal'
       AND tablename = 'conversations'
  ) THEN
    EXECUTE 'ALTER PUBLICATION supabase_realtime ADD TABLE cleangoal.conversations';
  END IF;
END$$;

INSERT INTO cleangoal.schema_migrations(version) VALUES ('v35_realtime_rls')
    ON CONFLICT (version) DO NOTHING;

COMMIT;

-- ROLLBACK:
-- BEGIN;
-- ALTER PUBLICATION supabase_realtime DROP TABLE IF EXISTS cleangoal.messages;
-- ALTER PUBLICATION supabase_realtime DROP TABLE IF EXISTS cleangoal.conversation_members;
-- ALTER PUBLICATION supabase_realtime DROP TABLE IF EXISTS cleangoal.conversations;
-- DO $$ DECLARE t text; BEGIN
--   FOREACH t IN ARRAY ARRAY['referral_codes','referral_invitations','referrals','referral_rewards',
--                            'friendships','conversations','dm_pairs','conversation_members',
--                            'messages','user_presence'] LOOP
--     EXECUTE format('ALTER TABLE cleangoal.%I DISABLE ROW LEVEL SECURITY;', t);
--     EXECUTE format('DROP POLICY IF EXISTS "deny_anon" ON cleangoal.%I;', t);
--   END LOOP;
-- END$$;
-- DROP FUNCTION IF EXISTS cleangoal.current_user_id();
-- DELETE FROM cleangoal.schema_migrations WHERE version = 'v35_realtime_rls';
-- COMMIT;
