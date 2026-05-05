-- v26: Food versioning + immutable meal-log snapshots.
--
-- Problem:
--   v24 introduced a foods -> detail_items sync trigger. That makes catalogue
--   edits rewrite historical user logs, which is unsafe: meal logs are facts
--   at the time the user recorded them, while foods is mutable master data.
--
-- Decision:
--   1) Stop syncing catalogue edits into existing detail_items.
--   2) Add food_versions as the auditable master-data history.
--   3) Add detail_items.food_version_id and detail_items.food_snapshot so new
--      logs can point to the catalogue version used at record time, while old
--      logs keep their existing per-unit snapshot values.

BEGIN;

-- -------------------------------------------------------------------------
-- 1. Retire the dangerous catalogue-to-history sync trigger
-- -------------------------------------------------------------------------

DROP TRIGGER IF EXISTS trg_foods_sync_detail_items ON cleangoal.foods;
DROP FUNCTION IF EXISTS cleangoal.fn_sync_detail_items_from_foods();

COMMENT ON TABLE cleangoal.detail_items IS
    'Historical meal-log item snapshots. Do not overwrite from foods after insert.';

-- -------------------------------------------------------------------------
-- 2. Food version history
-- -------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS cleangoal.food_versions (
    food_version_id   BIGSERIAL PRIMARY KEY,
    food_id           BIGINT NOT NULL
        REFERENCES cleangoal.foods(food_id) ON DELETE CASCADE,
    version_number    INTEGER NOT NULL,
    food_name         VARCHAR(200) NOT NULL,
    food_type         cleangoal.food_type,
    calories          NUMERIC,
    protein           NUMERIC,
    carbs             NUMERIC,
    fat               NUMERIC,
    sodium            NUMERIC,
    sugar             NUMERIC,
    cholesterol       NUMERIC,
    fiber_g           NUMERIC,
    serving_quantity  NUMERIC,
    serving_unit_id   INTEGER REFERENCES cleangoal.units(unit_id) ON DELETE SET NULL,
    dish_id           BIGINT REFERENCES cleangoal.dishes(dish_id) ON DELETE SET NULL,
    image_url         VARCHAR(500),
    source            VARCHAR(40) NOT NULL DEFAULT 'catalog',
    change_reason     TEXT,
    is_current        BOOLEAN NOT NULL DEFAULT true,
    effective_from    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    effective_to      TIMESTAMPTZ,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by        BIGINT REFERENCES cleangoal.users(user_id) ON DELETE SET NULL,
    UNIQUE (food_id, version_number)
);

CREATE UNIQUE INDEX IF NOT EXISTS food_versions_one_current_uq
    ON cleangoal.food_versions(food_id)
    WHERE is_current;

CREATE INDEX IF NOT EXISTS idx_food_versions_food_effective
    ON cleangoal.food_versions(food_id, effective_from DESC);

ALTER TABLE cleangoal.food_versions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "public_read" ON cleangoal.food_versions;
CREATE POLICY "public_read" ON cleangoal.food_versions
    AS PERMISSIVE FOR SELECT TO anon, authenticated USING (true);

ALTER TABLE cleangoal.foods
    ADD COLUMN IF NOT EXISTS current_version_id BIGINT;

-- Backfill one current version per existing food.
WITH src AS (
    SELECT f.*
    FROM cleangoal.foods f
    WHERE NOT EXISTS (
        SELECT 1
        FROM cleangoal.food_versions fv
        WHERE fv.food_id = f.food_id
    )
),
inserted AS (
    INSERT INTO cleangoal.food_versions (
        food_id, version_number, food_name, food_type,
        calories, protein, carbs, fat, sodium, sugar, cholesterol, fiber_g,
        serving_quantity, serving_unit_id, dish_id, image_url,
        source, change_reason, is_current,
        effective_from, created_at
    )
    SELECT
        food_id, 1, food_name, food_type,
        calories, protein, carbs, fat, sodium, sugar, cholesterol, fiber_g,
        serving_quantity, serving_unit_id, dish_id, image_url,
        'backfill', 'Initial version created by v26 migration', true,
        COALESCE(created_at, NOW()), NOW()
    FROM src
    RETURNING food_id, food_version_id
)
UPDATE cleangoal.foods f
   SET current_version_id = inserted.food_version_id
  FROM inserted
 WHERE f.food_id = inserted.food_id
   AND f.current_version_id IS NULL;

-- If a food already had versions but no pointer, point it to the current one.
UPDATE cleangoal.foods f
   SET current_version_id = fv.food_version_id
  FROM cleangoal.food_versions fv
 WHERE f.food_id = fv.food_id
   AND fv.is_current
   AND f.current_version_id IS NULL;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conrelid = 'cleangoal.foods'::regclass
          AND conname = 'foods_current_version_id_fkey'
    ) THEN
        ALTER TABLE cleangoal.foods
            ADD CONSTRAINT foods_current_version_id_fkey
            FOREIGN KEY (current_version_id)
            REFERENCES cleangoal.food_versions(food_version_id)
            ON DELETE SET NULL;
    END IF;
END$$;

CREATE INDEX IF NOT EXISTS idx_foods_current_version_id
    ON cleangoal.foods(current_version_id);

-- -------------------------------------------------------------------------
-- 3. Versioning trigger for future catalogue changes
-- -------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION cleangoal.fn_create_food_version()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = cleangoal, public
AS $$
DECLARE
    next_version_number INTEGER;
    new_version_id BIGINT;
BEGIN
    IF TG_OP = 'UPDATE' THEN
        IF NEW.food_name IS NOT DISTINCT FROM OLD.food_name
           AND NEW.food_type IS NOT DISTINCT FROM OLD.food_type
           AND NEW.calories IS NOT DISTINCT FROM OLD.calories
           AND NEW.protein IS NOT DISTINCT FROM OLD.protein
           AND NEW.carbs IS NOT DISTINCT FROM OLD.carbs
           AND NEW.fat IS NOT DISTINCT FROM OLD.fat
           AND NEW.sodium IS NOT DISTINCT FROM OLD.sodium
           AND NEW.sugar IS NOT DISTINCT FROM OLD.sugar
           AND NEW.cholesterol IS NOT DISTINCT FROM OLD.cholesterol
           AND NEW.fiber_g IS NOT DISTINCT FROM OLD.fiber_g
           AND NEW.serving_quantity IS NOT DISTINCT FROM OLD.serving_quantity
           AND NEW.serving_unit_id IS NOT DISTINCT FROM OLD.serving_unit_id
           AND NEW.dish_id IS NOT DISTINCT FROM OLD.dish_id
           AND NEW.image_url IS NOT DISTINCT FROM OLD.image_url THEN
            RETURN NEW;
        END IF;

        UPDATE cleangoal.food_versions
           SET is_current = false,
               effective_to = NOW()
         WHERE food_id = NEW.food_id
           AND is_current = true;
    END IF;

    SELECT COALESCE(MAX(version_number), 0) + 1
      INTO next_version_number
      FROM cleangoal.food_versions
     WHERE food_id = NEW.food_id;

    INSERT INTO cleangoal.food_versions (
        food_id, version_number, food_name, food_type,
        calories, protein, carbs, fat, sodium, sugar, cholesterol, fiber_g,
        serving_quantity, serving_unit_id, dish_id, image_url,
        source, change_reason, is_current,
        effective_from, created_at
    )
    VALUES (
        NEW.food_id, next_version_number, NEW.food_name, NEW.food_type,
        NEW.calories, NEW.protein, NEW.carbs, NEW.fat, NEW.sodium, NEW.sugar,
        NEW.cholesterol, NEW.fiber_g, NEW.serving_quantity, NEW.serving_unit_id,
        NEW.dish_id, NEW.image_url,
        CASE WHEN TG_OP = 'INSERT' THEN 'insert_trigger' ELSE 'update_trigger' END,
        CASE WHEN TG_OP = 'INSERT' THEN 'Food created' ELSE 'Food updated; new version created' END,
        true, NOW(), NOW()
    )
    RETURNING food_version_id INTO new_version_id;

    UPDATE cleangoal.foods
       SET current_version_id = new_version_id
     WHERE food_id = NEW.food_id;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_foods_create_version_insert ON cleangoal.foods;
CREATE TRIGGER trg_foods_create_version_insert
    AFTER INSERT ON cleangoal.foods
    FOR EACH ROW
    EXECUTE FUNCTION cleangoal.fn_create_food_version();

DROP TRIGGER IF EXISTS trg_foods_create_version_update ON cleangoal.foods;
CREATE TRIGGER trg_foods_create_version_update
    AFTER UPDATE OF food_name, food_type, calories, protein, carbs, fat,
                    sodium, sugar, cholesterol, fiber_g, serving_quantity,
                    serving_unit_id, dish_id, image_url
    ON cleangoal.foods
    FOR EACH ROW
    EXECUTE FUNCTION cleangoal.fn_create_food_version();

-- -------------------------------------------------------------------------
-- 4. Detail-item version pointers and immutable food snapshots
-- -------------------------------------------------------------------------

ALTER TABLE cleangoal.detail_items
    ADD COLUMN IF NOT EXISTS food_version_id BIGINT,
    ADD COLUMN IF NOT EXISTS food_snapshot JSONB;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conrelid = 'cleangoal.detail_items'::regclass
          AND conname = 'detail_items_food_version_id_fkey'
    ) THEN
        ALTER TABLE cleangoal.detail_items
            ADD CONSTRAINT detail_items_food_version_id_fkey
            FOREIGN KEY (food_version_id)
            REFERENCES cleangoal.food_versions(food_version_id)
            ON DELETE SET NULL;
    END IF;
END$$;

CREATE INDEX IF NOT EXISTS idx_detail_items_food_version_id
    ON cleangoal.detail_items(food_version_id);

-- Preserve existing log values as a JSON snapshot. These values are already
-- historical facts, so do not backfill them from current foods.
UPDATE cleangoal.detail_items di
   SET food_snapshot = jsonb_strip_nulls(jsonb_build_object(
        'food_id', di.food_id,
        'food_version_id', di.food_version_id,
        'food_name', di.food_name,
        'amount', di.amount,
        'unit_id', di.unit_id,
        'cal_per_unit', di.cal_per_unit,
        'protein_per_unit', di.protein_per_unit,
        'carbs_per_unit', di.carbs_per_unit,
        'fat_per_unit', di.fat_per_unit,
        'snapshot_source', 'v26_existing_detail_item',
        'snapshotted_at', NOW()
   ))
 WHERE di.food_snapshot IS NULL;

CREATE OR REPLACE FUNCTION cleangoal.fn_detail_items_set_food_snapshot()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = cleangoal, public
AS $$
DECLARE
    fv cleangoal.food_versions%ROWTYPE;
BEGIN
    IF NEW.food_id IS NOT NULL AND NEW.food_version_id IS NULL THEN
        SELECT *
          INTO fv
          FROM cleangoal.food_versions
         WHERE food_id = NEW.food_id
           AND is_current = true
         ORDER BY version_number DESC
         LIMIT 1;

        IF fv.food_version_id IS NOT NULL THEN
            NEW.food_version_id := fv.food_version_id;
        END IF;
    END IF;

    IF NEW.food_snapshot IS NULL THEN
        NEW.food_snapshot := jsonb_strip_nulls(jsonb_build_object(
            'food_id', NEW.food_id,
            'food_version_id', NEW.food_version_id,
            'food_name', NEW.food_name,
            'amount', NEW.amount,
            'unit_id', NEW.unit_id,
            'cal_per_unit', NEW.cal_per_unit,
            'protein_per_unit', NEW.protein_per_unit,
            'carbs_per_unit', NEW.carbs_per_unit,
            'fat_per_unit', NEW.fat_per_unit,
            'snapshot_source', 'detail_item_insert',
            'snapshotted_at', NOW()
        ));
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_detail_items_set_food_snapshot ON cleangoal.detail_items;
CREATE TRIGGER trg_detail_items_set_food_snapshot
    BEFORE INSERT ON cleangoal.detail_items
    FOR EACH ROW
    EXECUTE FUNCTION cleangoal.fn_detail_items_set_food_snapshot();

COMMENT ON TABLE cleangoal.food_versions IS
    'Immutable version history for mutable food catalogue rows. User logs should point to the version used when recorded.';
COMMENT ON COLUMN cleangoal.foods.current_version_id IS
    'Current active catalogue version. Updating food nutrition creates a new food_versions row instead of mutating user history.';
COMMENT ON COLUMN cleangoal.detail_items.food_version_id IS
    'Food catalogue version used when this historical log item was recorded.';
COMMENT ON COLUMN cleangoal.detail_items.food_snapshot IS
    'Immutable JSON snapshot of food/log values at insert time. Existing rows were backfilled from their current detail_items values, not from foods.';

INSERT INTO cleangoal.schema_migrations(version)
VALUES ('v26_food_versioning_and_log_snapshots')
ON CONFLICT (version) DO NOTHING;

COMMIT;

-- ROLLBACK:
-- BEGIN;
-- DROP TRIGGER IF EXISTS trg_detail_items_set_food_snapshot ON cleangoal.detail_items;
-- DROP FUNCTION IF EXISTS cleangoal.fn_detail_items_set_food_snapshot();
-- ALTER TABLE cleangoal.detail_items DROP CONSTRAINT IF EXISTS detail_items_food_version_id_fkey;
-- ALTER TABLE cleangoal.detail_items DROP COLUMN IF EXISTS food_version_id;
-- ALTER TABLE cleangoal.detail_items DROP COLUMN IF EXISTS food_snapshot;
-- DROP TRIGGER IF EXISTS trg_foods_create_version_insert ON cleangoal.foods;
-- DROP TRIGGER IF EXISTS trg_foods_create_version_update ON cleangoal.foods;
-- DROP FUNCTION IF EXISTS cleangoal.fn_create_food_version();
-- ALTER TABLE cleangoal.foods DROP CONSTRAINT IF EXISTS foods_current_version_id_fkey;
-- ALTER TABLE cleangoal.foods DROP COLUMN IF EXISTS current_version_id;
-- DROP TABLE IF EXISTS cleangoal.food_versions;
-- DELETE FROM cleangoal.schema_migrations WHERE version = 'v26_food_versioning_and_log_snapshots';
-- COMMIT;
