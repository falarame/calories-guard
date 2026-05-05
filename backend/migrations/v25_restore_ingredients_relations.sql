-- v25: Restore normalized ingredient source-of-truth relationships.
--
-- Background:
--   v22 archived and dropped cleangoal.ingredients + cleangoal.food_ingredients
--   because the active app flow used recipes.ingredients_json / recipe_ingredients
--   as free-text recipe detail. The product direction has changed: ingredients
--   must be a strong entity again, food_ingredients must describe each menu's
--   composition, and recipe_ingredients must be able to display ingredient names
--   plus nutrition calculated from the ingredient catalog.
--
-- Canonical relationship:
--   foods 1--N food_ingredients N--1 ingredients
--   foods 1--0/1 recipes 1--N recipe_ingredients
--   recipe_ingredients N--0/1 food_ingredients and N--0/1 ingredients

BEGIN;

-- -------------------------------------------------------------------------
-- 1. Restore ingredients as a strong entity
-- -------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS cleangoal.ingredients (
    ingredient_id          BIGSERIAL PRIMARY KEY,
    name                   VARCHAR(150) NOT NULL,
    source_food_code       VARCHAR(40),
    name_en                VARCHAR(255),
    scientific_name        VARCHAR(255),
    category               VARCHAR(50),
    default_unit_id        INTEGER REFERENCES cleangoal.units(unit_id) ON DELETE SET NULL,
    nutrition_basis_quantity NUMERIC(10,2) NOT NULL DEFAULT 100,
    nutrition_basis_unit_id  INTEGER REFERENCES cleangoal.units(unit_id) ON DELETE SET NULL,
    calories_per_unit      NUMERIC(8,2),
    protein_per_unit       NUMERIC(8,2) DEFAULT 0,
    carbs_per_unit         NUMERIC(8,2) DEFAULT 0,
    fat_per_unit           NUMERIC(8,2) DEFAULT 0,
    calories_per_100g      NUMERIC(8,2),
    protein_per_100g       NUMERIC(8,2) DEFAULT 0,
    carbs_per_100g         NUMERIC(8,2) DEFAULT 0,
    fat_per_100g           NUMERIC(8,2) DEFAULT 0,
    fiber_g_per_100g       NUMERIC(8,2) DEFAULT 0,
    water_g_per_100g       NUMERIC(8,2),
    sodium_mg_per_100g     NUMERIC(8,2) DEFAULT 0,
    sugar_g_per_100g       NUMERIC(8,2) DEFAULT 0,
    cholesterol_mg_per_100g NUMERIC(8,2) DEFAULT 0,
    calcium_mg_per_100g    NUMERIC(8,2),
    phosphorus_mg_per_100g NUMERIC(8,2),
    iron_mg_per_100g       NUMERIC(8,2),
    density_g_per_ml       NUMERIC(8,4),
    source_reference       VARCHAR(255),
    created_at             TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at             TIMESTAMPTZ
);

ALTER TABLE cleangoal.ingredients
    ADD COLUMN IF NOT EXISTS source_food_code VARCHAR(40),
    ADD COLUMN IF NOT EXISTS name_en VARCHAR(255),
    ADD COLUMN IF NOT EXISTS scientific_name VARCHAR(255),
    ADD COLUMN IF NOT EXISTS category VARCHAR(50),
    ADD COLUMN IF NOT EXISTS default_unit_id INTEGER,
    ADD COLUMN IF NOT EXISTS nutrition_basis_quantity NUMERIC(10,2) NOT NULL DEFAULT 100,
    ADD COLUMN IF NOT EXISTS nutrition_basis_unit_id INTEGER,
    ADD COLUMN IF NOT EXISTS calories_per_unit NUMERIC(8,2),
    ADD COLUMN IF NOT EXISTS protein_per_unit NUMERIC(8,2) DEFAULT 0,
    ADD COLUMN IF NOT EXISTS carbs_per_unit NUMERIC(8,2) DEFAULT 0,
    ADD COLUMN IF NOT EXISTS fat_per_unit NUMERIC(8,2) DEFAULT 0,
    ADD COLUMN IF NOT EXISTS calories_per_100g NUMERIC(8,2),
    ADD COLUMN IF NOT EXISTS protein_per_100g NUMERIC(8,2) DEFAULT 0,
    ADD COLUMN IF NOT EXISTS carbs_per_100g NUMERIC(8,2) DEFAULT 0,
    ADD COLUMN IF NOT EXISTS fat_per_100g NUMERIC(8,2) DEFAULT 0,
    ADD COLUMN IF NOT EXISTS fiber_g_per_100g NUMERIC(8,2) DEFAULT 0,
    ADD COLUMN IF NOT EXISTS water_g_per_100g NUMERIC(8,2),
    ADD COLUMN IF NOT EXISTS sodium_mg_per_100g NUMERIC(8,2) DEFAULT 0,
    ADD COLUMN IF NOT EXISTS sugar_g_per_100g NUMERIC(8,2) DEFAULT 0,
    ADD COLUMN IF NOT EXISTS cholesterol_mg_per_100g NUMERIC(8,2) DEFAULT 0,
    ADD COLUMN IF NOT EXISTS calcium_mg_per_100g NUMERIC(8,2),
    ADD COLUMN IF NOT EXISTS phosphorus_mg_per_100g NUMERIC(8,2),
    ADD COLUMN IF NOT EXISTS iron_mg_per_100g NUMERIC(8,2),
    ADD COLUMN IF NOT EXISTS density_g_per_ml NUMERIC(8,4),
    ADD COLUMN IF NOT EXISTS source_reference VARCHAR(255),
    ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conrelid = 'cleangoal.ingredients'::regclass
          AND conname = 'ingredients_default_unit_id_fkey'
    ) THEN
        ALTER TABLE cleangoal.ingredients
            ADD CONSTRAINT ingredients_default_unit_id_fkey
            FOREIGN KEY (default_unit_id)
            REFERENCES cleangoal.units(unit_id)
            ON DELETE SET NULL;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conrelid = 'cleangoal.ingredients'::regclass
          AND conname = 'ingredients_nutrition_basis_unit_id_fkey'
    ) THEN
        ALTER TABLE cleangoal.ingredients
            ADD CONSTRAINT ingredients_nutrition_basis_unit_id_fkey
            FOREIGN KEY (nutrition_basis_unit_id)
            REFERENCES cleangoal.units(unit_id)
            ON DELETE SET NULL;
    END IF;
END$$;

CREATE UNIQUE INDEX IF NOT EXISTS ingredients_name_lower_uq
    ON cleangoal.ingredients (lower(name));

CREATE UNIQUE INDEX IF NOT EXISTS ingredients_name_uq
    ON cleangoal.ingredients (name);

CREATE UNIQUE INDEX IF NOT EXISTS ingredients_source_food_code_uq
    ON cleangoal.ingredients (source_food_code)
    WHERE source_food_code IS NOT NULL;

-- Restore any archived rows if v22 archived data exists.
DO $$
BEGIN
    IF to_regclass('cleangoal.ingredients_archive') IS NOT NULL THEN
        INSERT INTO cleangoal.ingredients (
            ingredient_id, name, category, default_unit_id, calories_per_unit, created_at
        )
        SELECT ingredient_id, name, category, default_unit_id, calories_per_unit, created_at
        FROM cleangoal.ingredients_archive
        ON CONFLICT DO NOTHING;
    END IF;
END$$;

SELECT setval(
    pg_get_serial_sequence('cleangoal.ingredients', 'ingredient_id'),
    COALESCE((SELECT MAX(ingredient_id) FROM cleangoal.ingredients), 1),
    true
);

-- -------------------------------------------------------------------------
-- 2. Restore food_ingredients as the menu composition bridge
-- -------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS cleangoal.food_ingredients (
    food_ing_id      BIGSERIAL PRIMARY KEY,
    food_id          BIGINT NOT NULL REFERENCES cleangoal.foods(food_id) ON DELETE CASCADE,
    ingredient_id    BIGINT NOT NULL REFERENCES cleangoal.ingredients(ingredient_id) ON DELETE RESTRICT,
    amount           NUMERIC(10,2) NOT NULL,
    unit_id          INTEGER REFERENCES cleangoal.units(unit_id) ON DELETE SET NULL,
    calculated_grams NUMERIC(10,2),
    note             VARCHAR,
    sort_order       INTEGER NOT NULL DEFAULT 0,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMPTZ
);

ALTER TABLE cleangoal.food_ingredients
    ADD COLUMN IF NOT EXISTS sort_order INTEGER NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ;

ALTER TABLE cleangoal.food_ingredients
    ALTER COLUMN food_id SET NOT NULL,
    ALTER COLUMN ingredient_id SET NOT NULL,
    ALTER COLUMN amount SET NOT NULL;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conrelid = 'cleangoal.food_ingredients'::regclass
          AND conname = 'food_ingredients_food_id_fkey'
    ) THEN
        ALTER TABLE cleangoal.food_ingredients
            ADD CONSTRAINT food_ingredients_food_id_fkey
            FOREIGN KEY (food_id)
            REFERENCES cleangoal.foods(food_id)
            ON DELETE CASCADE;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conrelid = 'cleangoal.food_ingredients'::regclass
          AND conname = 'food_ingredients_ingredient_id_fkey'
    ) THEN
        ALTER TABLE cleangoal.food_ingredients
            ADD CONSTRAINT food_ingredients_ingredient_id_fkey
            FOREIGN KEY (ingredient_id)
            REFERENCES cleangoal.ingredients(ingredient_id)
            ON DELETE RESTRICT;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conrelid = 'cleangoal.food_ingredients'::regclass
          AND conname = 'food_ingredients_unit_id_fkey'
    ) THEN
        ALTER TABLE cleangoal.food_ingredients
            ADD CONSTRAINT food_ingredients_unit_id_fkey
            FOREIGN KEY (unit_id)
            REFERENCES cleangoal.units(unit_id)
            ON DELETE SET NULL;
    END IF;
END$$;

CREATE UNIQUE INDEX IF NOT EXISTS food_ingredients_food_ingredient_uq
    ON cleangoal.food_ingredients(food_id, ingredient_id);

CREATE INDEX IF NOT EXISTS idx_food_ingredients_food_sort
    ON cleangoal.food_ingredients(food_id, sort_order, food_ing_id);

CREATE INDEX IF NOT EXISTS idx_food_ingredients_ingredient
    ON cleangoal.food_ingredients(ingredient_id);

-- Ingredient-specific unit conversions are needed when an ingredient has a
-- variable household unit. Example: 1 piece of egg is not the same grams as
-- 1 piece of pork, so generic unit_conversions is not enough for all cases.
CREATE TABLE IF NOT EXISTS cleangoal.ingredient_unit_conversions (
    ingredient_unit_conversion_id BIGSERIAL PRIMARY KEY,
    ingredient_id BIGINT NOT NULL
        REFERENCES cleangoal.ingredients(ingredient_id) ON DELETE CASCADE,
    from_unit_id INTEGER NOT NULL
        REFERENCES cleangoal.units(unit_id) ON DELETE RESTRICT,
    to_unit_id INTEGER NOT NULL
        REFERENCES cleangoal.units(unit_id) ON DELETE RESTRICT,
    factor NUMERIC(12,6) NOT NULL,
    note VARCHAR,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (ingredient_id, from_unit_id, to_unit_id)
);

ALTER TABLE cleangoal.ingredient_unit_conversions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "public_read" ON cleangoal.ingredient_unit_conversions;
CREATE POLICY "public_read" ON cleangoal.ingredient_unit_conversions
    AS PERMISSIVE FOR SELECT TO anon, authenticated USING (true);

-- Restore archived rows only when matching food/ingredient rows exist.
DO $$
BEGIN
    IF to_regclass('cleangoal.food_ingredients_archive') IS NOT NULL THEN
        INSERT INTO cleangoal.food_ingredients (
            food_ing_id, food_id, ingredient_id, amount, unit_id,
            calculated_grams, note
        )
        SELECT a.food_ing_id, a.food_id, a.ingredient_id, a.amount, a.unit_id,
               a.calculated_grams, a.note
        FROM cleangoal.food_ingredients_archive a
        JOIN cleangoal.foods f ON f.food_id = a.food_id
        JOIN cleangoal.ingredients i ON i.ingredient_id = a.ingredient_id
        WHERE a.food_id IS NOT NULL
          AND a.ingredient_id IS NOT NULL
          AND a.amount IS NOT NULL
        ON CONFLICT DO NOTHING;
    END IF;
END$$;

SELECT setval(
    pg_get_serial_sequence('cleangoal.food_ingredients', 'food_ing_id'),
    COALESCE((SELECT MAX(food_ing_id) FROM cleangoal.food_ingredients), 1),
    true
);

-- -------------------------------------------------------------------------
-- 3. Connect recipe_ingredients back to normalized ingredient rows
-- -------------------------------------------------------------------------

-- Some deployments have recipe_ingredients.ing_id as an identity column,
-- while older dumps have it as a plain bigint without a default. Only add a
-- sequence fallback for the older shape.
DO $$
DECLARE is_identity text;
BEGIN
    SELECT a.attidentity
      INTO is_identity
      FROM pg_attribute a
     WHERE a.attrelid = 'cleangoal.recipe_ingredients'::regclass
       AND a.attname = 'ing_id'
       AND NOT a.attisdropped;

    IF COALESCE(is_identity, '') = '' THEN
        CREATE SEQUENCE IF NOT EXISTS cleangoal.recipe_ingredients_ing_id_seq;

        ALTER TABLE cleangoal.recipe_ingredients
            ALTER COLUMN ing_id SET DEFAULT nextval('cleangoal.recipe_ingredients_ing_id_seq');

        ALTER SEQUENCE cleangoal.recipe_ingredients_ing_id_seq
            OWNED BY cleangoal.recipe_ingredients.ing_id;

        PERFORM setval(
            'cleangoal.recipe_ingredients_ing_id_seq',
            COALESCE((SELECT MAX(ing_id) FROM cleangoal.recipe_ingredients), 1),
            true
        );
    END IF;
END$$;

ALTER TABLE cleangoal.recipe_ingredients
    ADD COLUMN IF NOT EXISTS food_ing_id BIGINT,
    ADD COLUMN IF NOT EXISTS ingredient_id BIGINT,
    ADD COLUMN IF NOT EXISTS unit_id INTEGER,
    ADD COLUMN IF NOT EXISTS calculated_grams NUMERIC(10,2),
    ADD COLUMN IF NOT EXISTS calculated_calories NUMERIC(10,2),
    ADD COLUMN IF NOT EXISTS calculated_protein NUMERIC(10,2),
    ADD COLUMN IF NOT EXISTS calculated_carbs NUMERIC(10,2),
    ADD COLUMN IF NOT EXISTS calculated_fat NUMERIC(10,2),
    ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conrelid = 'cleangoal.recipe_ingredients'::regclass
          AND conname = 'recipe_ingredients_food_ing_id_fkey'
    ) THEN
        ALTER TABLE cleangoal.recipe_ingredients
            ADD CONSTRAINT recipe_ingredients_food_ing_id_fkey
            FOREIGN KEY (food_ing_id)
            REFERENCES cleangoal.food_ingredients(food_ing_id)
            ON DELETE SET NULL;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conrelid = 'cleangoal.recipe_ingredients'::regclass
          AND conname = 'recipe_ingredients_ingredient_id_fkey'
    ) THEN
        ALTER TABLE cleangoal.recipe_ingredients
            ADD CONSTRAINT recipe_ingredients_ingredient_id_fkey
            FOREIGN KEY (ingredient_id)
            REFERENCES cleangoal.ingredients(ingredient_id)
            ON DELETE SET NULL;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conrelid = 'cleangoal.recipe_ingredients'::regclass
          AND conname = 'recipe_ingredients_unit_id_fkey'
    ) THEN
        ALTER TABLE cleangoal.recipe_ingredients
            ADD CONSTRAINT recipe_ingredients_unit_id_fkey
            FOREIGN KEY (unit_id)
            REFERENCES cleangoal.units(unit_id)
            ON DELETE SET NULL;
    END IF;
END$$;

CREATE UNIQUE INDEX IF NOT EXISTS recipe_ingredients_recipe_food_ing_uq
    ON cleangoal.recipe_ingredients(recipe_id, food_ing_id)
    WHERE food_ing_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_recipe_ingredients_food_ing
    ON cleangoal.recipe_ingredients(food_ing_id);

CREATE INDEX IF NOT EXISTS idx_recipe_ingredients_ingredient
    ON cleangoal.recipe_ingredients(ingredient_id);

-- -------------------------------------------------------------------------
-- 4. Food/recipe and nutrition display views for recipe detail/admin checks
-- -------------------------------------------------------------------------

CREATE OR REPLACE VIEW cleangoal.v_food_recipes AS
SELECT
    f.food_id,
    f.food_name,
    f.food_type,
    f.calories,
    f.protein,
    f.carbs,
    f.fat,
    r.recipe_id,
    r.description,
    r.instructions,
    r.prep_time_minutes,
    r.cooking_time_minutes,
    r.serving_people,
    r.generated_by,
    r.created_at AS recipe_created_at,
    r.deleted_at AS recipe_deleted_at
FROM cleangoal.foods f
LEFT JOIN cleangoal.recipes r
       ON r.food_id = f.food_id
      AND r.deleted_at IS NULL
WHERE f.deleted_at IS NULL;

CREATE OR REPLACE VIEW cleangoal.v_recipe_ingredients_nutrition AS
SELECT
    r.recipe_id,
    f.food_id,
    f.food_name,
    ri.ing_id,
    ri.food_ing_id,
    COALESCE(ri.ingredient_id, fi.ingredient_id) AS ingredient_id,
    COALESCE(i.name, ri.ingredient_name) AS ingredient_name,
    COALESCE(ri.quantity, fi.amount) AS quantity,
    COALESCE(u.name, ri.unit) AS unit,
    ri.is_optional,
    ri.note,
    ri.sort_order,
    x.grams::numeric(10,2) AS calculated_grams,
    ROUND(COALESCE(
        ri.calculated_calories,
        CASE
            WHEN i.calories_per_100g IS NOT NULL AND x.grams IS NOT NULL
                THEN i.calories_per_100g * x.grams / 100
            WHEN i.calories_per_unit IS NOT NULL
                THEN i.calories_per_unit * COALESCE(ri.quantity, fi.amount, 1)
            ELSE NULL
        END
    )::numeric, 2) AS calculated_calories,
    ROUND(COALESCE(
        ri.calculated_protein,
        CASE WHEN i.protein_per_100g IS NOT NULL AND x.grams IS NOT NULL
             THEN i.protein_per_100g * x.grams / 100 ELSE NULL END
    )::numeric, 2) AS calculated_protein,
    ROUND(COALESCE(
        ri.calculated_carbs,
        CASE WHEN i.carbs_per_100g IS NOT NULL AND x.grams IS NOT NULL
             THEN i.carbs_per_100g * x.grams / 100 ELSE NULL END
    )::numeric, 2) AS calculated_carbs,
    ROUND(COALESCE(
        ri.calculated_fat,
        CASE WHEN i.fat_per_100g IS NOT NULL AND x.grams IS NOT NULL
             THEN i.fat_per_100g * x.grams / 100 ELSE NULL END
    )::numeric, 2) AS calculated_fat
FROM cleangoal.recipe_ingredients ri
JOIN cleangoal.recipes r ON r.recipe_id = ri.recipe_id
JOIN cleangoal.foods f ON f.food_id = r.food_id
LEFT JOIN cleangoal.food_ingredients fi ON fi.food_ing_id = ri.food_ing_id
LEFT JOIN cleangoal.ingredients i
       ON i.ingredient_id = COALESCE(ri.ingredient_id, fi.ingredient_id)
LEFT JOIN cleangoal.units u
       ON u.unit_id = COALESCE(ri.unit_id, fi.unit_id)
LEFT JOIN cleangoal.units basis_u
       ON basis_u.unit_id = i.nutrition_basis_unit_id
LEFT JOIN LATERAL (
    SELECT COALESCE(
        ri.calculated_grams,
        fi.calculated_grams,
        CASE
            WHEN COALESCE(ri.unit_id, fi.unit_id) = i.nutrition_basis_unit_id
                 AND i.nutrition_basis_quantity > 0
                THEN COALESCE(ri.quantity, fi.amount) * 100 / i.nutrition_basis_quantity
            ELSE NULL
        END
    ) AS grams
) x ON true;

CREATE OR REPLACE VIEW cleangoal.v_food_ingredient_nutrition_totals AS
SELECT
    f.food_id,
    f.food_name,
    COUNT(fi.food_ing_id)::int AS ingredient_count,
    ROUND(SUM(CASE
        WHEN i.calories_per_100g IS NOT NULL AND fi.calculated_grams IS NOT NULL
            THEN i.calories_per_100g * fi.calculated_grams / 100
        WHEN i.calories_per_unit IS NOT NULL
            THEN i.calories_per_unit * fi.amount
        ELSE 0
    END)::numeric, 2) AS total_calories,
    ROUND(SUM(CASE
        WHEN i.protein_per_100g IS NOT NULL AND fi.calculated_grams IS NOT NULL
            THEN i.protein_per_100g * fi.calculated_grams / 100
        ELSE 0
    END)::numeric, 2) AS total_protein,
    ROUND(SUM(CASE
        WHEN i.carbs_per_100g IS NOT NULL AND fi.calculated_grams IS NOT NULL
            THEN i.carbs_per_100g * fi.calculated_grams / 100
        ELSE 0
    END)::numeric, 2) AS total_carbs,
    ROUND(SUM(CASE
        WHEN i.fat_per_100g IS NOT NULL AND fi.calculated_grams IS NOT NULL
            THEN i.fat_per_100g * fi.calculated_grams / 100
        ELSE 0
    END)::numeric, 2) AS total_fat
FROM cleangoal.foods f
JOIN cleangoal.food_ingredients fi ON fi.food_id = f.food_id
JOIN cleangoal.ingredients i ON i.ingredient_id = fi.ingredient_id
LEFT JOIN cleangoal.units basis_u ON basis_u.unit_id = i.nutrition_basis_unit_id
GROUP BY f.food_id, f.food_name;

-- Reference catalog read policies.
ALTER TABLE cleangoal.ingredients ENABLE ROW LEVEL SECURITY;
ALTER TABLE cleangoal.food_ingredients ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "public_read" ON cleangoal.ingredients;
CREATE POLICY "public_read" ON cleangoal.ingredients
    AS PERMISSIVE FOR SELECT TO anon, authenticated USING (true);

DROP POLICY IF EXISTS "public_read" ON cleangoal.food_ingredients;
CREATE POLICY "public_read" ON cleangoal.food_ingredients
    AS PERMISSIVE FOR SELECT TO anon, authenticated USING (true);

GRANT SELECT ON cleangoal.v_recipe_ingredients_nutrition TO anon, authenticated;
GRANT SELECT ON cleangoal.v_food_ingredient_nutrition_totals TO anon, authenticated;
GRANT SELECT ON cleangoal.v_food_recipes TO anon, authenticated;
GRANT SELECT ON cleangoal.ingredient_unit_conversions TO anon, authenticated;

COMMENT ON TABLE cleangoal.ingredients IS
    'Strong entity for normalized ingredient/raw material catalog and nutrition reference values.';
COMMENT ON TABLE cleangoal.food_ingredients IS
    'Bridge table describing which normalized ingredients compose each food/menu item.';
COMMENT ON TABLE cleangoal.ingredient_unit_conversions IS
    'Ingredient-specific household-unit conversions, e.g. piece to gram where generic unit conversion is not enough.';
COMMENT ON COLUMN cleangoal.ingredients.default_unit_id IS
    'Default practical unit for this ingredient, normally g for solid foods and ml for liquids.';
COMMENT ON COLUMN cleangoal.ingredients.nutrition_basis_unit_id IS
    'Unit used by nutrition reference values. ThaiFCD rows are usually per 100 g of food.';
COMMENT ON COLUMN cleangoal.ingredients.nutrition_basis_quantity IS
    'Quantity used by nutrition reference values, normally 100 for ThaiFCD per-100g data.';
COMMENT ON COLUMN cleangoal.recipe_ingredients.food_ing_id IS
    'Optional FK to the food_ingredients row used to display this recipe ingredient with normalized nutrition.';
COMMENT ON COLUMN cleangoal.recipe_ingredients.ingredient_id IS
    'Optional direct FK to ingredients for recipe rows that are not yet tied to a food_ingredients composition row.';
COMMENT ON VIEW cleangoal.v_food_recipes IS
    'Read model exposing the logical food_recipe relationship. Current physical schema is recipes.food_id because each food has at most one active recipe.';

INSERT INTO cleangoal.schema_migrations(version)
VALUES ('v25_restore_ingredients_relations')
ON CONFLICT (version) DO NOTHING;

COMMIT;

-- ROLLBACK:
-- BEGIN;
-- DROP VIEW IF EXISTS cleangoal.v_food_recipes;
-- DROP VIEW IF EXISTS cleangoal.v_food_ingredient_nutrition_totals;
-- DROP VIEW IF EXISTS cleangoal.v_recipe_ingredients_nutrition;
-- ALTER TABLE cleangoal.recipe_ingredients
--   DROP CONSTRAINT IF EXISTS recipe_ingredients_food_ing_id_fkey,
--   DROP CONSTRAINT IF EXISTS recipe_ingredients_ingredient_id_fkey,
--   DROP CONSTRAINT IF EXISTS recipe_ingredients_unit_id_fkey;
-- ALTER TABLE cleangoal.recipe_ingredients
--   DROP COLUMN IF EXISTS food_ing_id,
--   DROP COLUMN IF EXISTS ingredient_id,
--   DROP COLUMN IF EXISTS unit_id,
--   DROP COLUMN IF EXISTS calculated_grams,
--   DROP COLUMN IF EXISTS calculated_calories,
--   DROP COLUMN IF EXISTS calculated_protein,
--   DROP COLUMN IF EXISTS calculated_carbs,
--   DROP COLUMN IF EXISTS calculated_fat,
--   DROP COLUMN IF EXISTS updated_at;
-- DROP TABLE IF EXISTS cleangoal.food_ingredients;
-- DROP TABLE IF EXISTS cleangoal.ingredients;
-- DELETE FROM cleangoal.schema_migrations WHERE version = 'v25_restore_ingredients_relations';
-- COMMIT;
