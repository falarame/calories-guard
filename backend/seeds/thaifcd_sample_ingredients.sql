-- ThaiFCD sample ingredients imported from user-provided files.
--
-- Sources:
--   * ThaiFCD-Food-search-by-food-name-A6-260505083717jUvndoSkDTm87cNSl1I5.pdf
--   * ThaiFCD-food-search-by-food-name-F176_260505083935yAT61w5Dz.xls
--
-- ThaiFCD values are "Content per 100 g of food", so these rows use:
--   default_unit_id = units.g
--   nutrition_basis_unit_id = units.g
--   nutrition_basis_quantity = 100

BEGIN;

WITH unit_g AS (
    SELECT unit_id FROM cleangoal.units WHERE lower(name) = 'g' LIMIT 1
)
INSERT INTO cleangoal.ingredients (
    source_food_code,
    name,
    name_en,
    scientific_name,
    category,
    default_unit_id,
    nutrition_basis_quantity,
    nutrition_basis_unit_id,
    calories_per_100g,
    protein_per_100g,
    carbs_per_100g,
    fat_per_100g,
    fiber_g_per_100g,
    water_g_per_100g,
    sodium_mg_per_100g,
    sugar_g_per_100g,
    cholesterol_mg_per_100g,
    calcium_mg_per_100g,
    phosphorus_mg_per_100g,
    iron_mg_per_100g,
    source_reference
)
SELECT *
FROM (
    VALUES
      (
        'THAIFCD:A6',
        'ข้าวกล้องงอก ดิบ',
        'Rice, brown, germinated, raw',
        'Oryza sativa',
        'grain',
        (SELECT unit_id FROM unit_g),
        100,
        (SELECT unit_id FROM unit_g),
        365,
        7.47,
        74.77,
        3.03,
        4.50,
        8.80,
        25,
        NULL::numeric,
        0,
        14,
        274,
        1.23,
        'ThaiFCD Online version 2, September 2018; user file A6 PDF'
      ),
      (
        'THAIFCD:F176',
        'หมู ขาหลัง เนื้อล้วน ดิบ',
        'Pork, ham, whole separable lean only, raw',
        'Sus scrofa domestica',
        'protein',
        (SELECT unit_id FROM unit_g),
        100,
        (SELECT unit_id FROM unit_g),
        148,
        20.40,
        0.00,
        7.40,
        0.00,
        72.60,
        119,
        NULL::numeric,
        NULL::numeric,
        5,
        NULL::numeric,
        0.70,
        'ThaiFCD Online version 2, September 2018; user file F176 XLS'
      )
) AS v(
    source_food_code,
    name,
    name_en,
    scientific_name,
    category,
    default_unit_id,
    nutrition_basis_quantity,
    nutrition_basis_unit_id,
    calories_per_100g,
    protein_per_100g,
    carbs_per_100g,
    fat_per_100g,
    fiber_g_per_100g,
    water_g_per_100g,
    sodium_mg_per_100g,
    sugar_g_per_100g,
    cholesterol_mg_per_100g,
    calcium_mg_per_100g,
    phosphorus_mg_per_100g,
    iron_mg_per_100g,
    source_reference
)
ON CONFLICT (source_food_code) WHERE source_food_code IS NOT NULL DO UPDATE SET
    name = EXCLUDED.name,
    name_en = EXCLUDED.name_en,
    scientific_name = EXCLUDED.scientific_name,
    category = EXCLUDED.category,
    default_unit_id = EXCLUDED.default_unit_id,
    nutrition_basis_quantity = EXCLUDED.nutrition_basis_quantity,
    nutrition_basis_unit_id = EXCLUDED.nutrition_basis_unit_id,
    calories_per_100g = EXCLUDED.calories_per_100g,
    protein_per_100g = EXCLUDED.protein_per_100g,
    carbs_per_100g = EXCLUDED.carbs_per_100g,
    fat_per_100g = EXCLUDED.fat_per_100g,
    fiber_g_per_100g = EXCLUDED.fiber_g_per_100g,
    water_g_per_100g = EXCLUDED.water_g_per_100g,
    sodium_mg_per_100g = EXCLUDED.sodium_mg_per_100g,
    sugar_g_per_100g = EXCLUDED.sugar_g_per_100g,
    cholesterol_mg_per_100g = EXCLUDED.cholesterol_mg_per_100g,
    calcium_mg_per_100g = EXCLUDED.calcium_mg_per_100g,
    phosphorus_mg_per_100g = EXCLUDED.phosphorus_mg_per_100g,
    iron_mg_per_100g = EXCLUDED.iron_mg_per_100g,
    source_reference = EXCLUDED.source_reference,
    updated_at = NOW();

COMMIT;
