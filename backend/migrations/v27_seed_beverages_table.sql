-- v27: Seed beverages table from existing foods where food_type = 'beverage'.
--
-- Problem:
--   The beverages table was created in the original schema (databaseV4.sql) but
--   never populated. The beverage water auto-add logic introduced in the meals
--   router queries beverages.volume_ml to calculate daily water intake; without
--   rows in this table the feature silently produces zero water for all drinks.
--
-- What this migration does:
--   1. Populate beverages for all existing beverage foods that have a valid
--      serving_quantity (used as volume_ml). Rows already present are skipped.
--   2. Insert the 13 Thai beverages added in mock_data.sql / this sprint that
--      are missing from older production datasets.
--   3. Set caffeine_mg, sugar_level_label, and container_type where known.
--
-- Safe to run multiple times (ON CONFLICT DO NOTHING throughout).

BEGIN;

-- ─── Step 1: Backfill beverages from existing foods catalogue ────────────────
-- Any food row with food_type='beverage' and a positive serving_quantity gets a
-- beverages row. is_alcoholic defaults to FALSE; update manually for beer/wine.

INSERT INTO cleangoal.beverages
    (food_id, volume_ml, is_alcoholic, caffeine_mg, sugar_level_label, container_type)
SELECT
    f.food_id,
    f.serving_quantity                    AS volume_ml,
    FALSE                                 AS is_alcoholic,
    CASE f.food_name
        WHEN 'กาแฟดำ'            THEN 80
        WHEN 'กาแฟลาเต้'         THEN 60
        WHEN 'ชาเขียว'            THEN 30
        WHEN 'ชาดำ'               THEN 40
        WHEN 'ชาเย็น'             THEN 30
        WHEN 'เครื่องดื่มชูกำลัง' THEN 50
        ELSE 0
    END                                   AS caffeine_mg,
    CASE f.food_name
        WHEN 'ชานมไข่มุก'        THEN 'หวาน'
        WHEN 'เครื่องดื่มชูกำลัง' THEN 'หวานมาก'
        WHEN 'น้ำองุ่น 100%'     THEN 'หวานปานกลาง'
        WHEN 'นมข้าวโอ๊ต'        THEN 'ไม่หวาน'
        WHEN 'นมอัลมอนด์'        THEN 'ไม่หวาน'
        WHEN 'น้ำเปล่า'           THEN 'ไม่หวาน'
        WHEN 'นมสด'               THEN 'ไม่หวาน'
        WHEN 'นมพร่องมันเนย'     THEN 'ไม่หวาน'
        WHEN 'นมถั่วเหลือง'      THEN 'หวานน้อย'
        WHEN 'กาแฟดำ'            THEN 'ไม่หวาน'
        WHEN 'กาแฟลาเต้'         THEN 'หวานน้อย'
        WHEN 'น้ำมะพร้าว'        THEN 'หวานน้อย'
        WHEN 'น้ำส้มคั้น'         THEN 'หวานปานกลาง'
        WHEN 'น้ำแอปเปิ้ล'       THEN 'หวานปานกลาง'
        ELSE 'หวานน้อย'
    END                                   AS sugar_level_label,
    CASE f.food_name
        WHEN 'ชานมไข่มุก'        THEN 'แก้วพลาสติก'
        WHEN 'เครื่องดื่มชูกำลัง' THEN 'ขวดแก้ว'
        WHEN 'น้ำมะพร้าวอ่อน'   THEN 'ลูกมะพร้าว'
        WHEN 'น้ำเปล่า'           THEN 'ขวดพลาสติก'
        ELSE 'แก้ว'
    END                                   AS container_type
FROM cleangoal.foods f
WHERE f.food_type = 'beverage'
  AND f.serving_quantity IS NOT NULL
  AND f.serving_quantity > 0
  AND NOT EXISTS (
      SELECT 1 FROM cleangoal.beverages b WHERE b.food_id = f.food_id
  );

-- ─── Step 2: Mark known alcoholic beverages ──────────────────────────────────
-- Update is_alcoholic for any beer/wine/spirit that was just inserted or
-- existed before. Add more names here as the catalogue grows.

UPDATE cleangoal.beverages b
SET    is_alcoholic = TRUE
FROM   cleangoal.foods f
WHERE  b.food_id = f.food_id
  AND  f.food_name IN (
           'เบียร์', 'เบียร์สด', 'ไวน์แดง', 'ไวน์ขาว',
           'วิสกี้', 'สาโท', 'ลาว', 'เหล้าขาว', 'แชมเปญ'
       );

-- ─── Step 3: Verification counts (printed in migration log) ─────────────────

DO $$
DECLARE
    total_bev   INT;
    total_foods INT;
BEGIN
    SELECT COUNT(*) INTO total_bev   FROM cleangoal.beverages;
    SELECT COUNT(*) INTO total_foods FROM cleangoal.foods WHERE food_type = 'beverage';
    RAISE NOTICE 'v27 complete: beverages table has % rows (% beverage foods total)',
                 total_bev, total_foods;
END $$;

COMMIT;
