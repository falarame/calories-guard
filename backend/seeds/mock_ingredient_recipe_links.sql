-- Mock ingredient links for v25_restore_ingredients_relations.
--
-- This seed is idempotent and intentionally small. It proves the restored
-- relationship chain:
--   foods -> recipes -> recipe_ingredients -> food_ingredients -> ingredients
--
-- Covered examples:
--   * dish: ข้าวมันไก่ต้ม
--   * dish: ผัดไทยกุ้งสด
--   * beverage/drink: ชาไทยเย็น

BEGIN;

-- -------------------------------------------------------------------------
-- 1. Ingredient catalog
-- -------------------------------------------------------------------------

WITH u AS (
    SELECT
        (SELECT unit_id FROM cleangoal.units WHERE lower(name) = 'g' LIMIT 1) AS g,
        (SELECT unit_id FROM cleangoal.units WHERE lower(name) = 'ml' LIMIT 1) AS ml,
        (SELECT unit_id FROM cleangoal.units WHERE lower(name) = 'piece' LIMIT 1) AS piece
)
INSERT INTO cleangoal.ingredients (
    name, category, default_unit_id,
    calories_per_100g, protein_per_100g, carbs_per_100g, fat_per_100g,
    sodium_mg_per_100g, sugar_g_per_100g, source_reference
)
SELECT *
FROM (
    VALUES
      ('ข้าวสวย', 'grain', (SELECT g FROM u), 130, 2.70, 28.20, 0.30, 1, 0.10, 'mock:v25'),
      ('เนื้อไก่ต้ม', 'protein', (SELECT g FROM u), 165, 31.00, 0.00, 3.60, 74, 0.00, 'mock:v25'),
      ('หนังไก่', 'protein', (SELECT g FROM u), 349, 13.30, 0.00, 32.40, 56, 0.00, 'mock:v25'),
      ('น้ำมันไก่', 'fat', (SELECT g FROM u), 884, 0.00, 0.00, 100.00, 0, 0.00, 'mock:v25'),
      ('แตงกวา', 'vegetable', (SELECT g FROM u), 15, 0.70, 3.60, 0.10, 2, 1.70, 'mock:v25'),
      ('น้ำจิ้มข้าวมันไก่', 'sauce', (SELECT g FROM u), 120, 2.00, 20.00, 2.00, 900, 12.00, 'mock:v25'),
      ('เส้นจันท์', 'grain', (SELECT g FROM u), 364, 6.00, 80.00, 1.00, 10, 0.50, 'mock:v25'),
      ('กุ้งสด', 'protein', (SELECT g FROM u), 99, 24.00, 0.20, 0.30, 111, 0.00, 'mock:v25'),
      ('ไข่ไก่', 'protein', (SELECT g FROM u), 143, 12.60, 0.70, 9.50, 142, 0.40, 'mock:v25'),
      ('เต้าหู้แข็ง', 'protein', (SELECT g FROM u), 144, 15.70, 3.90, 8.70, 14, 0.60, 'mock:v25'),
      ('ถั่วงอก', 'vegetable', (SELECT g FROM u), 30, 3.00, 6.00, 0.20, 6, 4.10, 'mock:v25'),
      ('น้ำมะขามเปียก', 'sauce', (SELECT g FROM u), 239, 2.80, 62.50, 0.60, 28, 57.40, 'mock:v25'),
      ('น้ำปลา', 'seasoning', (SELECT g FROM u), 35, 5.00, 3.00, 0.00, 7900, 3.00, 'mock:v25'),
      ('น้ำตาลปี๊บ', 'sweetener', (SELECT g FROM u), 383, 0.00, 98.00, 0.00, 25, 98.00, 'mock:v25'),
      ('น้ำมันพืช', 'fat', (SELECT g FROM u), 884, 0.00, 0.00, 100.00, 0, 0.00, 'mock:v25'),
      ('ชาไทย', 'beverage_base', (SELECT ml FROM u), 1, 0.00, 0.20, 0.00, 1, 0.10, 'mock:v25'),
      ('นมข้นหวาน', 'dairy', (SELECT g FROM u), 321, 7.90, 54.40, 8.70, 127, 54.40, 'mock:v25'),
      ('นมสด', 'dairy', (SELECT ml FROM u), 61, 3.20, 4.80, 3.30, 43, 5.10, 'mock:v25'),
      ('น้ำตาลทราย', 'sweetener', (SELECT g FROM u), 387, 0.00, 100.00, 0.00, 1, 100.00, 'mock:v25')
) AS v(
    name, category, default_unit_id,
    calories_per_100g, protein_per_100g, carbs_per_100g, fat_per_100g,
    sodium_mg_per_100g, sugar_g_per_100g, source_reference
)
ON CONFLICT (name) DO UPDATE SET
    category = EXCLUDED.category,
    default_unit_id = EXCLUDED.default_unit_id,
    calories_per_100g = EXCLUDED.calories_per_100g,
    protein_per_100g = EXCLUDED.protein_per_100g,
    carbs_per_100g = EXCLUDED.carbs_per_100g,
    fat_per_100g = EXCLUDED.fat_per_100g,
    sodium_mg_per_100g = EXCLUDED.sodium_mg_per_100g,
    sugar_g_per_100g = EXCLUDED.sugar_g_per_100g,
    source_reference = EXCLUDED.source_reference,
    updated_at = NOW();

-- -------------------------------------------------------------------------
-- 2. Menu composition: foods -> food_ingredients -> ingredients
-- -------------------------------------------------------------------------

WITH unit_g AS (
    SELECT unit_id FROM cleangoal.units WHERE lower(name) = 'g' LIMIT 1
),
unit_ml AS (
    SELECT unit_id FROM cleangoal.units WHERE lower(name) = 'ml' LIMIT 1
),
rows(food_name, ingredient_name, amount, unit_name, calculated_grams, sort_order, note) AS (
    VALUES
      ('ข้าวมันไก่ต้ม', 'ข้าวสวย', 180, 'g', 180, 1, 'mock composition'),
      ('ข้าวมันไก่ต้ม', 'เนื้อไก่ต้ม', 120, 'g', 120, 2, 'mock composition'),
      ('ข้าวมันไก่ต้ม', 'หนังไก่', 25, 'g', 25, 3, 'mock composition'),
      ('ข้าวมันไก่ต้ม', 'น้ำมันไก่', 12, 'g', 12, 4, 'mock composition'),
      ('ข้าวมันไก่ต้ม', 'แตงกวา', 30, 'g', 30, 5, 'mock composition'),
      ('ข้าวมันไก่ต้ม', 'น้ำจิ้มข้าวมันไก่', 25, 'g', 25, 6, 'mock composition'),
      ('ผัดไทยกุ้งสด', 'เส้นจันท์', 120, 'g', 120, 1, 'mock composition'),
      ('ผัดไทยกุ้งสด', 'กุ้งสด', 80, 'g', 80, 2, 'mock composition'),
      ('ผัดไทยกุ้งสด', 'ไข่ไก่', 50, 'g', 50, 3, 'mock composition'),
      ('ผัดไทยกุ้งสด', 'เต้าหู้แข็ง', 40, 'g', 40, 4, 'mock composition'),
      ('ผัดไทยกุ้งสด', 'ถั่วงอก', 60, 'g', 60, 5, 'mock composition'),
      ('ผัดไทยกุ้งสด', 'น้ำมะขามเปียก', 25, 'g', 25, 6, 'mock composition'),
      ('ผัดไทยกุ้งสด', 'น้ำปลา', 10, 'g', 10, 7, 'mock composition'),
      ('ผัดไทยกุ้งสด', 'น้ำตาลปี๊บ', 12, 'g', 12, 8, 'mock composition'),
      ('ผัดไทยกุ้งสด', 'น้ำมันพืช', 15, 'g', 15, 9, 'mock composition'),
      ('ชาไทยเย็น', 'ชาไทย', 180, 'ml', 180, 1, 'mock beverage composition'),
      ('ชาไทยเย็น', 'นมข้นหวาน', 35, 'g', 35, 2, 'mock beverage composition'),
      ('ชาไทยเย็น', 'นมสด', 80, 'ml', 80, 3, 'mock beverage composition'),
      ('ชาไทยเย็น', 'น้ำตาลทราย', 12, 'g', 12, 4, 'mock beverage composition')
)
INSERT INTO cleangoal.food_ingredients (
    food_id, ingredient_id, amount, unit_id, calculated_grams, sort_order, note
)
SELECT
    f.food_id,
    i.ingredient_id,
    r.amount,
    CASE WHEN r.unit_name = 'ml' THEN (SELECT unit_id FROM unit_ml) ELSE (SELECT unit_id FROM unit_g) END,
    r.calculated_grams,
    r.sort_order,
    r.note
FROM rows r
JOIN cleangoal.foods f ON f.food_name = r.food_name AND f.deleted_at IS NULL
JOIN cleangoal.ingredients i ON i.name = r.ingredient_name
ON CONFLICT (food_id, ingredient_id) DO UPDATE SET
    amount = EXCLUDED.amount,
    unit_id = EXCLUDED.unit_id,
    calculated_grams = EXCLUDED.calculated_grams,
    sort_order = EXCLUDED.sort_order,
    note = EXCLUDED.note,
    updated_at = NOW();

-- -------------------------------------------------------------------------
-- 3. Recipe display rows linked back to normalized composition rows
-- -------------------------------------------------------------------------

INSERT INTO cleangoal.recipe_ingredients (
    recipe_id,
    ingredient_name,
    quantity,
    unit,
    is_optional,
    note,
    sort_order,
    food_ing_id,
    ingredient_id,
    unit_id,
    calculated_grams
)
SELECT
    r.recipe_id,
    i.name,
    fi.amount,
    COALESCE(u.name, 'g'),
    false,
    fi.note,
    fi.sort_order,
    fi.food_ing_id,
    i.ingredient_id,
    fi.unit_id,
    fi.calculated_grams
FROM cleangoal.food_ingredients fi
JOIN cleangoal.ingredients i ON i.ingredient_id = fi.ingredient_id
JOIN cleangoal.recipes r ON r.food_id = fi.food_id AND r.deleted_at IS NULL
LEFT JOIN cleangoal.units u ON u.unit_id = fi.unit_id
JOIN cleangoal.foods f ON f.food_id = fi.food_id
WHERE f.food_name IN ('ข้าวมันไก่ต้ม', 'ผัดไทยกุ้งสด', 'ชาไทยเย็น')
ON CONFLICT (recipe_id, food_ing_id) WHERE food_ing_id IS NOT NULL DO UPDATE SET
    ingredient_name = EXCLUDED.ingredient_name,
    quantity = EXCLUDED.quantity,
    unit = EXCLUDED.unit,
    note = EXCLUDED.note,
    sort_order = EXCLUDED.sort_order,
    ingredient_id = EXCLUDED.ingredient_id,
    unit_id = EXCLUDED.unit_id,
    calculated_grams = EXCLUDED.calculated_grams,
    updated_at = NOW();

COMMIT;
