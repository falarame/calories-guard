-- v41: Normalization cleanup — drop dead leftover tables + close RLS holes.
--
-- Context
-- -------
-- After the v17–v25 normalization cycle the schema is already in 3NF. This
-- migration removes objects that are now genuinely dead and tightens security.
-- It is intentionally CONSERVATIVE: it touches nothing the application reads or
-- writes, and it KEEPS every intentional performance cache
-- (daily_summaries macro/water columns + their sync triggers, recipes.*_json).
--
-- Verified against live schema (project zawlghlnzgftlxcoipuf, schema cleangoal)
-- before writing this migration:
--   * No FOREIGN KEY references any drop target (information_schema check → 0 rows).
--   * No VIEW depends on any drop target (view_table_usage check → 0 rows).
--   * No backend Python code references any drop target (grep backend/**/*.py).
--   * foods.food_category / foods.serving_unit were already dropped by v21 (no-op now).
--
-- Drops (table — why dead):
--   1. food_requests_archive      0 rows. Empty leftover from v22 archive step. (RLS was OFF)
--   2. food_ingredients_archive   0 rows. Leftover; real table restored by v25.  (RLS was OFF)
--   3. ingredients_archive        0 rows. Leftover; real table restored by v25.  (RLS was OFF)
--   4. recipe_reviews_orphan_archive     ~20 rows. Audit snapshot from v17 normalization.
--   5. recipe_relation_orphan_archive   ~100 rows. Audit snapshot from v17/v18 normalization.
--   6. unit_conversion_orphan_archive    ~19 rows. Audit snapshot from v18 normalization.
--   7. ingredient_unit_conversions        0 rows. Designed-but-unused; no code/FK references.
--
-- Security fix (NOT a drop):
--   * ai_feedback is an ACTIVE feature table (written by /api/feedback in
--     app/routers/feedback.py) but had RLS DISABLED, exposing it to the anon key.
--     We ENABLE RLS. The backend connects as the privileged `postgres` role, which
--     BYPASSES RLS, so this does not affect the API; it only blocks direct anon/
--     authenticated Supabase-client access (the desired state for a service-only table).
--
-- Delivery: script only. Review, then run via `python backend/run_migrations.py`
-- or apply manually. Each statement is idempotent and wrapped in one transaction.

BEGIN;

-- -------------------------------------------------------------------------
-- 1. Drop dead leftover archive tables (empty, superseded)
-- -------------------------------------------------------------------------

DROP TABLE IF EXISTS cleangoal.food_requests_archive;
DROP TABLE IF EXISTS cleangoal.food_ingredients_archive;
DROP TABLE IF EXISTS cleangoal.ingredients_archive;

-- -------------------------------------------------------------------------
-- 2. Drop one-off audit/orphan archives from past normalization migrations
--    (historical snapshots; not read by the app)
-- -------------------------------------------------------------------------

DROP TABLE IF EXISTS cleangoal.recipe_reviews_orphan_archive;
DROP TABLE IF EXISTS cleangoal.recipe_relation_orphan_archive;
DROP TABLE IF EXISTS cleangoal.unit_conversion_orphan_archive;

-- -------------------------------------------------------------------------
-- 3. Drop empty, unreferenced designed table
-- -------------------------------------------------------------------------

DROP TABLE IF EXISTS cleangoal.ingredient_unit_conversions;

-- -------------------------------------------------------------------------
-- 4. Close RLS security hole on the active ai_feedback table
--    (kept, not dropped). Service-only: backend role bypasses RLS.
-- -------------------------------------------------------------------------

ALTER TABLE cleangoal.ai_feedback ENABLE ROW LEVEL SECURITY;

-- -------------------------------------------------------------------------
-- 5. Record migration
-- -------------------------------------------------------------------------

INSERT INTO cleangoal.schema_migrations(version) VALUES ('v41_normalize_cleanup')
    ON CONFLICT (version) DO NOTHING;

COMMIT;

-- ROLLBACK (schema only — dropped tables' data is NOT recoverable from here):
-- BEGIN;
-- ALTER TABLE cleangoal.ai_feedback DISABLE ROW LEVEL SECURITY;
-- -- Recreate empty structures if needed (see init_database.sql / v22 / v25 / v17–v18 for column defs):
-- --   cleangoal.ingredient_unit_conversions, cleangoal.*_orphan_archive, cleangoal.*_archive
-- DELETE FROM cleangoal.schema_migrations WHERE version = 'v41_normalize_cleanup';
-- COMMIT;
