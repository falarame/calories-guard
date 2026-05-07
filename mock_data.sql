-- ============================================================
--  CalGuard Mock Data — 20 rows per table
--  Schema: cleangoal
--  Date: 2026-03-29
-- ============================================================

BEGIN;

-- ============================================================
-- 1. allergy_flags  (IDs 61-80 via sequence)
-- ============================================================
INSERT INTO cleangoal.allergy_flags (name, description) VALUES
('ถั่วลิสง',       'แพ้ถั่วลิสงและผลิตภัณฑ์จากถั่วลิสง'),
('กลูเตน',        'แพ้กลูเตนในข้าวสาลี ข้าวบาร์เลย์ ข้าวไรน์'),
('นมวัว',         'แพ้โปรตีนในนมวัวและผลิตภัณฑ์นม'),
('ไข่',           'แพ้ไข่ไก่และไข่นก'),
('อาหารทะเล',     'แพ้หอย กุ้ง ปู ปลาหมึก'),
('ถั่วเหลือง',    'แพ้ถั่วเหลืองและผลิตภัณฑ์จากถั่วเหลือง'),
('ถั่วต้นไม้',    'แพ้ถั่วอัลมอนด์ วอลนัต มะม่วงหิมพานต์'),
('ข้าวสาลี',      'แพ้แป้งข้าวสาลีทุกชนิด'),
('ปลา',           'แพ้เนื้อปลาทุกชนิด'),
('กุ้ง',          'แพ้กุ้งและสัตว์จำพวกกุ้ง'),
('เนื้อหมู',      'ไม่รับประทานเนื้อหมู'),
('เนื้อวัว',      'ไม่รับประทานเนื้อวัว'),
('ไก่',           'ไม่รับประทานเนื้อไก่'),
('แลคโตส',        'แพ้น้ำตาลแลคโตสในนม'),
('ผงชูรส',        'แพ้ผงชูรส (MSG)'),
('สารกันบูด',     'แพ้สารกันบูดและสารปรุงแต่ง'),
('สีผสมอาหาร',   'แพ้สีผสมอาหารสังเคราะห์'),
('แป้งมัน',       'แพ้แป้งมันสำปะหลัง'),
('น้ำมันปาล์ม',   'หลีกเลี่ยงน้ำมันปาล์ม'),
('กะทิ',          'แพ้กะทิและมะพร้าว');


-- ============================================================
-- 2. ingredients  (IDs 104+ via sequence; 101-103 already exist)
-- ============================================================
INSERT INTO cleangoal.ingredients (name, category, default_unit_id, calories_per_unit) VALUES
('ข้าวสวย',        'ธัญพืช',      1, 1.30),
('เนื้อไก่',       'โปรตีน',      1, 1.65),
('เนื้อหมู',       'โปรตีน',      1, 2.42),
('ไข่เป็ด',        'โปรตีน',      2, 88.00),
('น้ำมันพืช',      'ไขมัน',       3, 120.00),
('กระเทียม',      'เครื่องเทศ',   1, 1.49),
('พริก',           'เครื่องเทศ',   1, 0.40),
('ซีอิ๊วขาว',      'เครื่องปรุง',  3, 10.00),
('น้ำตาลทราย',    'เครื่องปรุง',  3, 48.00),
('แป้งสาลี',       'แป้ง',         1, 3.64),
('มะเขือเทศ',     'ผัก',          1, 0.18),
('หอมใหญ่',       'ผัก',          1, 0.40),
('แครอท',         'ผัก',          1, 0.41),
('บร็อคโคลี',     'ผัก',          1, 0.34),
('กะทิ',           'ของเหลว',     3, 55.00),
('น้ำปลา',         'เครื่องปรุง',  3, 10.00),
('พริกแกง',       'เครื่องปรุง',  3, 25.00),
('เส้นก๋วยเตี๋ยว', 'แป้ง',         1, 3.50),
('ถั่วฝักยาว',    'ผัก',          1, 0.31),
('ต้นหอม',        'ผัก',          1, 0.30);


-- ============================================================
-- 3. new foods for beverages (10 rows, food_type='beverage')
-- ============================================================
INSERT INTO cleangoal.foods
    (food_name, food_type, calories, protein, carbs, fat, serving_quantity, serving_unit, food_category)
VALUES
('ชาไทยนม',        'beverage', 180, 3.0,  30.0,  5.0, 250, 'ml', 'เครื่องดื่ม'),
('น้ำส้มคั้น',      'beverage',  90, 1.5,  21.0,  0.2, 250, 'ml', 'เครื่องดื่ม'),
('กาแฟเย็น',       'beverage', 120, 2.0,  22.0,  3.0, 250, 'ml', 'เครื่องดื่ม'),
('น้ำมะพร้าว',      'beverage',  60, 0.7,  14.0,  0.2, 330, 'ml', 'เครื่องดื่ม'),
('นมสด',           'beverage', 150, 8.0,  11.0,  8.0, 250, 'ml', 'เครื่องดื่ม'),
('น้ำผลไม้รวม',    'beverage', 110, 0.5,  26.0,  0.1, 250, 'ml', 'เครื่องดื่ม'),
('ชาเขียวนม',      'beverage', 160, 2.5,  28.0,  4.0, 250, 'ml', 'เครื่องดื่ม'),
('โกโก้ร้อน',      'beverage', 200, 5.0,  35.0,  5.0, 250, 'ml', 'เครื่องดื่ม'),
('สมูทตี้กล้วย',   'beverage', 220, 4.0,  45.0,  2.0, 300, 'ml', 'เครื่องดื่ม'),
('น้ำเต้าหู้',      'beverage',  80, 5.0,  10.0,  2.0, 250, 'ml', 'เครื่องดื่ม');


-- ============================================================
-- 4. new foods for snacks (10 rows, food_type='snack')
-- ============================================================
INSERT INTO cleangoal.foods
    (food_name, food_type, calories, protein, carbs, fat, serving_quantity, serving_unit, food_category)
VALUES
('ขนมปังปิ้งเนย',   'snack', 210,  4.0,  32.0,  8.0, 100, 'g', 'ขนม'),
('โดนัทสอดไส้',    'snack', 280,  4.5,  38.0, 13.0, 100, 'g', 'ขนม'),
('คุกกี้ช็อกโกแลต', 'snack', 320,  4.0,  42.0, 16.0, 100, 'g', 'ขนม'),
('ข้าวโพดคั่ว',     'snack', 120,  3.5,  22.0,  2.0, 100, 'g', 'ขนม'),
('มันฝรั่งทอด',     'snack', 350,  4.0,  38.0, 20.0, 100, 'g', 'ขนม'),
('ถั่วอบเกลือ',     'snack', 580, 25.0,  21.0, 49.0, 100, 'g', 'ขนม'),
('บิสกิตครีม',      'snack', 260,  3.0,  38.0, 11.0, 100, 'g', 'ขนม'),
('แครกเกอร์งา',    'snack', 230,  5.0,  34.0,  9.0, 100, 'g', 'ขนม'),
('เยลลี่ผลไม้',    'snack',  80,  1.5,  18.0,  0.0, 100, 'g', 'ขนม'),
('ลูกอมแคนดี้',    'snack', 360,  0.0,  90.0,  0.0, 100, 'g', 'ขนม');


-- ============================================================
-- 5. beverages  (link to newly inserted beverage foods)
-- ============================================================
INSERT INTO cleangoal.beverages
    (food_id, volume_ml, is_alcoholic, caffeine_mg, sugar_level_label, container_type)
SELECT
    food_id,
    CASE food_name
        WHEN 'ชาไทยนม'       THEN 250
        WHEN 'น้ำส้มคั้น'     THEN 250
        WHEN 'กาแฟเย็น'      THEN 250
        WHEN 'น้ำมะพร้าว'    THEN 330
        WHEN 'นมสด'          THEN 250
        WHEN 'น้ำผลไม้รวม'   THEN 250
        WHEN 'ชาเขียวนม'     THEN 250
        WHEN 'โกโก้ร้อน'     THEN 250
        WHEN 'สมูทตี้กล้วย'  THEN 300
        ELSE 250
    END,
    false,
    CASE food_name
        WHEN 'กาแฟเย็น'   THEN 80
        WHEN 'ชาเขียวนม'  THEN 30
        WHEN 'ชาไทยนม'    THEN 20
        ELSE 0
    END,
    CASE food_name
        WHEN 'ชาไทยนม'    THEN 'หวาน'
        WHEN 'กาแฟเย็น'   THEN 'หวานน้อย'
        WHEN 'นมสด'       THEN 'ไม่หวาน'
        ELSE 'ปานกลาง'
    END,
    'แก้ว'
FROM cleangoal.foods
WHERE food_type = 'beverage'
  AND food_name IN (
      'ชาไทยนม','น้ำส้มคั้น','กาแฟเย็น','น้ำมะพร้าว','นมสด',
      'น้ำผลไม้รวม','ชาเขียวนม','โกโก้ร้อน','สมูทตี้กล้วย','น้ำเต้าหู้'
  );


-- ============================================================
-- 6. snacks  (link to newly inserted snack foods)
-- ============================================================
INSERT INTO cleangoal.snacks (food_id, is_sweet, packaging_type, trans_fat)
SELECT
    food_id,
    CASE food_name
        WHEN 'โดนัทสอดไส้'      THEN true
        WHEN 'คุกกี้ช็อกโกแลต'  THEN true
        WHEN 'ข้าวโพดคั่ว'       THEN false
        WHEN 'มันฝรั่งทอด'       THEN false
        WHEN 'ถั่วอบเกลือ'       THEN false
        WHEN 'บิสกิตครีม'         THEN true
        WHEN 'แครกเกอร์งา'      THEN false
        WHEN 'เยลลี่ผลไม้'       THEN true
        WHEN 'ลูกอมแคนดี้'      THEN true
        ELSE true
    END,
    CASE food_name
        WHEN 'มันฝรั่งทอด'       THEN 'ถุงพลาสติก'
        WHEN 'คุกกี้ช็อกโกแลต'  THEN 'กล่อง'
        WHEN 'โดนัทสอดไส้'      THEN 'ถุงกระดาษ'
        ELSE 'ถุงพลาสติก'
    END,
    0.0
FROM cleangoal.foods
WHERE food_type = 'snack'
  AND food_name IN (
      'ขนมปังปิ้งเนย','โดนัทสอดไส้','คุกกี้ช็อกโกแลต','ข้าวโพดคั่ว',
      'มันฝรั่งทอด','ถั่วอบเกลือ','บิสกิตครีม','แครกเกอร์งา',
      'เยลลี่ผลไม้','ลูกอมแคนดี้'
  );


-- ============================================================
-- 7. food_ingredients (20 rows) — name-based ingredient lookup
-- ============================================================
INSERT INTO cleangoal.food_ingredients (food_id, ingredient_id, amount, unit_id, calculated_grams)
SELECT v.food_id, i.ingredient_id, v.amount, v.unit_id, v.calculated_grams
FROM (VALUES
    ( 3, 'ข้าวสวย',       150, 1, 150),
    ( 3, 'เนื้อหมู',       100, 1, 100),
    ( 4, 'ข้าวสวย',       150, 1, 150),
    ( 4, 'เนื้อหมู',        80, 1,  80),
    ( 5, 'ข้าวสวย',       150, 1, 150),
    ( 5, 'เนื้อหมู',        70, 1,  70),
    ( 6, 'เส้นก๋วยเตี๋ยว',  80, 1,  80),
    ( 6, 'เนื้อไก่',        80, 1,  80),
    ( 7, 'ข้าวสวย',       150, 1, 150),
    ( 7, 'เนื้อหมู',        90, 1,  90),
    ( 8, 'เส้นก๋วยเตี๋ยว',  80, 1,  80),
    ( 8, 'เนื้อหมู',        90, 1,  90),
    ( 9, 'เนื้อไก่',        80, 1,  80),
    ( 9, 'เนื้อหมู',        80, 1,  80),
    (10, 'เนื้อไก่',        80, 1,  80),
    (10, 'เส้นก๋วยเตี๋ยว',  80, 1,  80),
    (11, 'ข้าวสวย',       150, 1, 150),
    (11, 'ซีอิ๊วขาว',       10, 3,  50),
    (12, 'ข้าวสวย',       150, 1, 150),
    (12, 'กะทิ',            50, 1,  50)
) AS v(food_id, ingredient_name, amount, unit_id, calculated_grams)
JOIN cleangoal.ingredients i ON i.name = v.ingredient_name;


-- ============================================================
-- 8. food_allergy_flags (20 rows) — name-based flag lookup
-- ============================================================
INSERT INTO cleangoal.food_allergy_flags (food_id, flag_id)
SELECT v.food_id, af.flag_id
FROM (VALUES
    ( 3, 'เนื้อหมู'),
    ( 4, 'เนื้อหมู'),
    ( 5, 'เนื้อหมู'),
    ( 6, 'อาหารทะเล'),
    ( 6, 'ปลา'),
    ( 6, 'กุ้ง'),
    ( 7, 'เนื้อหมู'),
    ( 8, 'ข้าวสาลี'),
    ( 9, 'อาหารทะเล'),
    ( 9, 'กุ้ง'),
    (10, 'อาหารทะเล'),
    (10, 'กุ้ง'),
    (11, 'ถั่วลิสง'),
    (12, 'ไข่'),
    (13, 'เนื้อหมู'),
    (14, 'ข้าวสาลี'),
    (15, 'อาหารทะเล'),
    (16, 'เนื้อหมู'),
    (17, 'ไข่'),
    (18, 'ข้าวสาลี')
) AS v(food_id, flag_name)
JOIN cleangoal.allergy_flags af ON af.name = v.flag_name;


-- ============================================================
-- 9. food_requests (20 rows)
-- ============================================================
INSERT INTO cleangoal.food_requests
    (user_id, food_name, status, ingredients_json, reviewed_by, calories, protein, carbs, fat)
VALUES
( 1, 'ข้าวผัดกุ้ง',       'approved', '{"items":["ข้าว","กุ้ง","ไข่"]}',          5, 520, 20, 65, 18),
( 2, 'ส้มตำไทย',          'approved', '{"items":["มะละกอ","มะเขือเทศ"]}',         5, 150,  5, 28,  3),
( 3, 'ลาบหมู',            'pending',  '{"items":["หมูสับ","ข้าวคั่ว"]}',          NULL, 310, 22, 15, 18),
( 4, 'ต้มยำกุ้ง',          'approved', '{"items":["กุ้ง","เห็ด","ตะไคร้"]}',       5, 200, 18, 12,  8),
( 6, 'ผัดกะเพราไก่',       'approved', '{"items":["ไก่","กะเพรา","พริก"]}',        5, 400, 25, 35, 15),
( 7, 'แกงมัสมั่น',         'pending',  '{"items":["เนื้อ","มันฝรั่ง"]}',          NULL, 550, 28, 45, 22),
( 8, 'ยำวุ้นเส้น',         'pending',  '{"items":["วุ้นเส้น","กุ้ง"]}',           NULL, 280, 15, 35,  8),
( 9, 'ขนมจีนน้ำยา',       'rejected', '{"items":["ขนมจีน","น้ำยา"]}',             5, 380, 16, 55, 12),
(10, 'ข้าวหน้าเป็ด',        'approved', '{"items":["ข้าว","เป็ด"]}',                5, 600, 30, 65, 22),
(11, 'ต้มข่าไก่',           'approved', '{"items":["ไก่","ข่า","กะทิ"]}',           5, 350, 22, 12, 25),
(12, 'ผัดถั่วงอก',          'pending',  '{"items":["ถั่วงอก","ไข่"]}',             NULL, 180, 10, 18,  8),
(13, 'ข้าวหน้าไก่ทอด',      'approved', '{"items":["ข้าว","ไก่ทอด"]}',              5, 650, 28, 75, 25),
(14, 'สลัดผัก',            'approved', '{"items":["ผักสลัด","ผักต่างๆ"]}',         5, 120,  4, 18,  4),
(15, 'ซุปผัก',             'pending',  '{"items":["ผักรวม","น้ำซุป"]}',           NULL, 100,  4, 15,  2),
(16, 'ข้าวต้มปลา',          'approved', '{"items":["ข้าว","ปลา"]}',                 5, 280, 18, 38,  5),
(18, 'เมนูเจ ผัดผักรวม',   'pending',  '{"items":["ผักรวม","เต้าหู้"]}',          NULL, 200,  8, 25,  8),
(19, 'ไข่เจียวหมูสับ',      'approved', '{"items":["ไข่","หมูสับ"]}',               5, 380, 22,  5, 28),
(20, 'บะหมี่น้ำ',           'rejected', '{"items":["บะหมี่","หมูแดง"]}',            5, 420, 18, 55, 14),
(23, 'ข้าวกล้องผัดผัก',     'approved', '{"items":["ข้าวกล้อง","ผัก"]}',            5, 380, 10, 68,  8),
(24, 'กระเพาะปลา',         'pending',  '{"items":["กระเพาะปลา","ผัก"]}',          NULL, 250, 20, 15, 10);


-- ============================================================
-- 10. user_activities (20 rows)
-- ============================================================
INSERT INTO cleangoal.user_activities (user_id, activity_level, is_current, date_record)
VALUES
( 1, 'sedentary',         true, CURRENT_DATE),
( 2, 'lightly_active',    true, CURRENT_DATE),
( 3, 'moderately_active', true, CURRENT_DATE),
( 4, 'very_active',       true, CURRENT_DATE),
( 6, 'sedentary',         true, CURRENT_DATE),
( 7, 'lightly_active',    true, CURRENT_DATE),
( 8, 'moderately_active', true, CURRENT_DATE),
( 9, 'very_active',       true, CURRENT_DATE),
(10, 'sedentary',         true, CURRENT_DATE),
(11, 'lightly_active',    true, CURRENT_DATE),
(12, 'moderately_active', true, CURRENT_DATE),
(13, 'sedentary',         true, CURRENT_DATE),
(14, 'very_active',       true, CURRENT_DATE),
(15, 'moderately_active', true, CURRENT_DATE),
(16, 'lightly_active',    true, CURRENT_DATE),
(18, 'lightly_active',    true, CURRENT_DATE),
(19, 'sedentary',         true, CURRENT_DATE),
(20, 'moderately_active', true, CURRENT_DATE),
(23, 'lightly_active',    true, CURRENT_DATE),
(24, 'very_active',       true, CURRENT_DATE);


-- ============================================================
-- 11. user_allergy_preferences (20 rows) — PK(user_id, flag_id)
--     flag lookup by name
-- ============================================================
INSERT INTO cleangoal.user_allergy_preferences (user_id, flag_id, preference_type)
SELECT v.user_id, af.flag_id, v.preference_type
FROM (VALUES
    ( 1, 'ถั่วลิสง',     'allergy'),
    ( 2, 'นมวัว',        'allergy'),
    ( 3, 'ไข่',          'avoid'),
    ( 4, 'อาหารทะเล',   'allergy'),
    ( 6, 'กลูเตน',       'avoid'),
    ( 7, 'เนื้อหมู',     'avoid'),
    ( 8, 'ปลา',          'allergy'),
    ( 9, 'กุ้ง',          'allergy'),
    (10, 'ถั่วเหลือง',   'avoid'),
    (11, 'ถั่วต้นไม้',    'allergy'),
    (12, 'ข้าวสาลี',     'avoid'),
    (13, 'แลคโตส',      'avoid'),
    (14, 'เนื้อวัว',      'avoid'),
    (15, 'ไก่',           'avoid'),
    (16, 'ถั่วลิสง',     'allergy'),
    (18, 'กะทิ',          'avoid'),
    (19, 'ผงชูรส',       'avoid'),
    (20, 'สีผสมอาหาร',  'avoid'),
    (23, 'นมวัว',        'allergy'),
    (24, 'ไข่',          'avoid')
) AS v(user_id, flag_name, preference_type)
JOIN cleangoal.allergy_flags af ON af.name = v.flag_name;


-- ============================================================
-- 12. user_goals (20 rows)
-- ============================================================
INSERT INTO cleangoal.user_goals
    (user_id, goal_name, goal_type, target_weight_kg, is_current, goal_start_at, goal_target_date)
VALUES
( 1, 'ลดน้ำหนัก 5 กิโล',       'lose_weight',     65.00, true, CURRENT_DATE - 30, CURRENT_DATE + 60),
( 2, 'ลดน้ำหนัก 8 กิโล',       'lose_weight',     72.00, true, CURRENT_DATE - 14, CURRENT_DATE + 90),
( 3, 'รักษาน้ำหนัก',            'maintain_weight', 80.00, true, CURRENT_DATE -  7, CURRENT_DATE + 180),
( 4, 'เพิ่มกล้ามเนื้อ',          'gain_muscle',     85.00, true, CURRENT_DATE - 21, CURRENT_DATE + 90),
( 6, 'ลดน้ำหนัก 10 กิโล',      'lose_weight',     70.00, true, CURRENT_DATE - 45, CURRENT_DATE + 120),
( 7, 'เพิ่มกล้ามเนื้อ',          'gain_muscle',     75.00, true, CURRENT_DATE - 10, CURRENT_DATE + 90),
( 8, 'รักษาน้ำหนัก',            'maintain_weight', 80.00, true, CURRENT_DATE - 60, CURRENT_DATE + 120),
( 9, 'ลดน้ำหนัก 3 กิโล',       'lose_weight',     55.00, true, CURRENT_DATE - 20, CURRENT_DATE + 60),
(10, 'ลดน้ำหนัก 12 กิโล',      'lose_weight',     68.00, true, CURRENT_DATE -  5, CURRENT_DATE + 180),
(11, 'เพิ่มกล้ามเนื้อ',          'gain_muscle',     82.00, true, CURRENT_DATE - 30, CURRENT_DATE + 90),
(12, 'รักษาน้ำหนัก',            'maintain_weight', 80.00, true, CURRENT_DATE - 15, CURRENT_DATE + 90),
(13, 'ลดน้ำหนัก 10 กิโล',      'lose_weight',     60.00, true, CURRENT_DATE - 30, CURRENT_DATE + 90),
(14, 'เพิ่มกล้ามเนื้อ 5 กิโล',  'gain_muscle',     55.00, true, CURRENT_DATE - 14, CURRENT_DATE + 120),
(15, 'เพิ่มน้ำหนัก 5 กิโล',     'gain_muscle',     30.00, true, CURRENT_DATE -  7, CURRENT_DATE + 60),
(16, 'ลดน้ำหนัก',               'lose_weight',     72.00, true, CURRENT_DATE - 21, CURRENT_DATE + 90),
(18, 'ลดน้ำหนัก',               'lose_weight',     60.50, true, CURRENT_DATE - 10, CURRENT_DATE + 60),
(19, 'ลดน้ำหนัก',               'lose_weight',     72.00, true, CURRENT_DATE - 20, CURRENT_DATE + 90),
(20, 'ลดน้ำหนัก',               'lose_weight',     72.00, true, CURRENT_DATE - 15, CURRENT_DATE + 75),
(23, 'ลดน้ำหนัก',               'lose_weight',     63.00, true, CURRENT_DATE -  5, CURRENT_DATE + 90),
(24, 'เพิ่มกล้ามเนื้อ',          'gain_muscle',     70.00, true, CURRENT_DATE - 10, CURRENT_DATE + 120);


-- ============================================================
-- 13. weight_logs (20 rows) — UNIQUE(user_id, recorded_date)
-- ============================================================
INSERT INTO cleangoal.weight_logs (user_id, weight_kg, recorded_date) VALUES
( 1, 70.00, CURRENT_DATE - 19),
( 2, 80.50, CURRENT_DATE - 18),
( 3, 80.00, CURRENT_DATE - 17),
( 4, 79.50, CURRENT_DATE - 16),
( 6, 80.00, CURRENT_DATE - 15),
( 7, 76.00, CURRENT_DATE - 14),
( 8, 79.00, CURRENT_DATE - 13),
( 9, 58.00, CURRENT_DATE - 12),
(10, 80.00, CURRENT_DATE - 11),
(11, 79.50, CURRENT_DATE - 10),
(12, 80.00, CURRENT_DATE -  9),
(13, 70.00, CURRENT_DATE -  8),
(14, 51.00, CURRENT_DATE -  7),
(15, 25.50, CURRENT_DATE -  6),
(16, 79.50, CURRENT_DATE -  5),
(18, 65.00, CURRENT_DATE -  4),
(19, 79.50, CURRENT_DATE -  3),
(20, 79.80, CURRENT_DATE -  2),
(23, 69.80, CURRENT_DATE -  1),
(24, 69.50, CURRENT_DATE);


-- ============================================================
-- 14. recipes — UPDATE existing rows (one per food, food_ids 3-22)
-- ============================================================
UPDATE cleangoal.recipes SET
    recipe_name = 'ข้าวขาหมูต้มพะโล้',
    description = 'ข้าวหน้าขาหมูต้มซีอิ๊วกับพะโล้หอมหวาน',
    category    = 'อาหารจานหลัก', cuisine = 'ไทย', difficulty = 'Easy',
    prep_time_minutes = 15, cooking_time_minutes = 120, serving_people = 2.0, is_published = true
WHERE food_id = 3;

UPDATE cleangoal.recipes SET
    recipe_name = 'ข้าวหมูแดงราดซอส',
    description = 'ข้าวราดหมูแดงชิ้นใหญ่พร้อมน้ำซอสหอมหวาน',
    category    = 'อาหารจานหลัก', cuisine = 'ไทย', difficulty = 'Easy',
    prep_time_minutes = 10, cooking_time_minutes = 30, serving_people = 1.0, is_published = true
WHERE food_id = 4;

UPDATE cleangoal.recipes SET
    recipe_name = 'ข้าวหมูกรอบน้ำพริก',
    description = 'ข้าวหน้าหมูกรอบกับน้ำพริกเผา',
    category    = 'อาหารจานหลัก', cuisine = 'ไทย', difficulty = 'Medium',
    prep_time_minutes = 15, cooking_time_minutes = 45, serving_people = 1.0, is_published = true
WHERE food_id = 5;

UPDATE cleangoal.recipes SET
    recipe_name = 'ผัดไทยกุ้งสดคลาสสิก',
    description = 'ผัดไทยกุ้งสดสูตรดั้งเดิม ใส่ถั่วงอกและไข่',
    category    = 'อาหารจานหลัก', cuisine = 'ไทย', difficulty = 'Medium',
    prep_time_minutes = 15, cooking_time_minutes = 20, serving_people = 2.0, is_published = true
WHERE food_id = 6;

UPDATE cleangoal.recipes SET
    recipe_name = 'ราดหน้าหมูหมักซีอิ๊ว',
    description = 'ราดหน้าเส้นใหญ่ หมูหมักซีอิ๊วนุ่มหอม',
    category    = 'อาหารจานหลัก', cuisine = 'ไทย', difficulty = 'Easy',
    prep_time_minutes = 20, cooking_time_minutes = 15, serving_people = 1.0, is_published = true
WHERE food_id = 7;

UPDATE cleangoal.recipes SET
    recipe_name = 'ผัดซีอิ๊วหมูสูตรเด็ด',
    description = 'ผัดซีอิ๊วเส้นใหญ่หมูสามชั้นไฟแรง',
    category    = 'อาหารจานหลัก', cuisine = 'ไทย', difficulty = 'Easy',
    prep_time_minutes = 10, cooking_time_minutes = 10, serving_people = 1.0, is_published = true
WHERE food_id = 8;

UPDATE cleangoal.recipes SET
    recipe_name = 'สุกี้น้ำรวมมิตร',
    description = 'สุกี้น้ำใสรวมซีฟู้ดและผัก',
    category    = 'อาหารจานหลัก', cuisine = 'ไทย', difficulty = 'Easy',
    prep_time_minutes = 20, cooking_time_minutes = 20, serving_people = 2.0, is_published = true
WHERE food_id = 9;

UPDATE cleangoal.recipes SET
    recipe_name = 'สุกี้แห้งรวมมิตร',
    description = 'สุกี้แห้งรวมซีฟู้ดผัดซอสสุกี้',
    category    = 'อาหารจานหลัก', cuisine = 'ไทย', difficulty = 'Medium',
    prep_time_minutes = 20, cooking_time_minutes = 15, serving_people = 2.0, is_published = true
WHERE food_id = 10;

UPDATE cleangoal.recipes SET
    recipe_name = 'ข้าวคลุกกะปิสูตรโบราณ',
    description = 'ข้าวคลุกกะปิใส่ไข่เค็มและหมูหยอง',
    category    = 'อาหารจานหลัก', cuisine = 'ไทย', difficulty = 'Easy',
    prep_time_minutes = 15, cooking_time_minutes = 10, serving_people = 1.0, is_published = true
WHERE food_id = 11;

UPDATE cleangoal.recipes SET
    recipe_name = 'แกงเขียวหวานไก่',
    description = 'แกงเขียวหวานไก่กะทิสดใบมะกรูดหอม',
    category    = 'อาหารจานหลัก', cuisine = 'ไทย', difficulty = 'Medium',
    prep_time_minutes = 20, cooking_time_minutes = 30, serving_people = 3.0, is_published = true
WHERE food_id = 12;

UPDATE cleangoal.recipes SET
    recipe_name = 'ต้มยำกุ้งน้ำข้น',
    description = 'ต้มยำกุ้งน้ำข้นรสจัดเด็ด',
    category    = 'ซุปและต้ม', cuisine = 'ไทย', difficulty = 'Medium',
    prep_time_minutes = 15, cooking_time_minutes = 20, serving_people = 2.0, is_published = true
WHERE food_id = 13;

UPDATE cleangoal.recipes SET
    recipe_name = 'ผัดกะเพราไก่ไข่ดาว',
    description = 'ผัดกะเพราไก่สับกรอบพร้อมไข่ดาว',
    category    = 'อาหารจานหลัก', cuisine = 'ไทย', difficulty = 'Easy',
    prep_time_minutes = 10, cooking_time_minutes = 10, serving_people = 1.0, is_published = true
WHERE food_id = 14;

UPDATE cleangoal.recipes SET
    recipe_name = 'ผัดไทยเส้นจันท์',
    description = 'ผัดไทยเส้นจันทบุรีหมูสับหอมกรุ่น',
    category    = 'อาหารจานหลัก', cuisine = 'ไทย', difficulty = 'Medium',
    prep_time_minutes = 15, cooking_time_minutes = 15, serving_people = 1.0, is_published = true
WHERE food_id = 15;

UPDATE cleangoal.recipes SET
    recipe_name = 'ข้าวผัดกุ้งไข่ฟู',
    description = 'ข้าวผัดกุ้งไข่ฟูหอมซีอิ๊ว',
    category    = 'อาหารจานหลัก', cuisine = 'ไทย', difficulty = 'Easy',
    prep_time_minutes = 10, cooking_time_minutes = 10, serving_people = 1.0, is_published = true
WHERE food_id = 16;

UPDATE cleangoal.recipes SET
    recipe_name = 'ส้มตำไทยสูตรต้นตำรับ',
    description = 'ส้มตำไทยใส่กุ้งแห้งถั่วลิสง',
    category    = 'อาหารเรียกน้ำย่อย', cuisine = 'ไทย', difficulty = 'Easy',
    prep_time_minutes = 15, cooking_time_minutes = 5, serving_people = 1.0, is_published = true
WHERE food_id = 17;

UPDATE cleangoal.recipes SET
    recipe_name = 'ลาบหมูสูตรอีสาน',
    description = 'ลาบหมูสดสูตรอีสานแท้',
    category    = 'อาหารจานหลัก', cuisine = 'อีสาน', difficulty = 'Medium',
    prep_time_minutes = 15, cooking_time_minutes = 10, serving_people = 2.0, is_published = true
WHERE food_id = 18;

UPDATE cleangoal.recipes SET
    recipe_name = 'ต้มข่าไก่กะทิสด',
    description = 'ต้มข่าไก่กะทิสดรสกลมกล่อม',
    category    = 'ซุปและต้ม', cuisine = 'ไทย', difficulty = 'Easy',
    prep_time_minutes = 15, cooking_time_minutes = 25, serving_people = 2.0, is_published = true
WHERE food_id = 19;

UPDATE cleangoal.recipes SET
    recipe_name = 'แกงเผ็ดเป็ดย่าง',
    description = 'แกงเผ็ดเป็ดย่างใบมะกรูดกะทิสด',
    category    = 'อาหารจานหลัก', cuisine = 'ไทย', difficulty = 'Hard',
    prep_time_minutes = 20, cooking_time_minutes = 40, serving_people = 3.0, is_published = true
WHERE food_id = 20;

UPDATE cleangoal.recipes SET
    recipe_name = 'มะระผัดไข่',
    description = 'มะระผัดไข่สูตรง่ายๆ รสชาติดี',
    category    = 'อาหารจานหลัก', cuisine = 'ไทย', difficulty = 'Easy',
    prep_time_minutes = 10, cooking_time_minutes = 10, serving_people = 1.0, is_published = true
WHERE food_id = 21;

UPDATE cleangoal.recipes SET
    recipe_name = 'กระเพราเนื้อสับ',
    description = 'กระเพราเนื้อสับไฟแรงใบกระเพราสด',
    category    = 'อาหารจานหลัก', cuisine = 'ไทย', difficulty = 'Easy',
    prep_time_minutes = 10, cooking_time_minutes = 10, serving_people = 1.0, is_published = true
WHERE food_id = 22;


-- ============================================================
-- 15. recipe_ingredients (20 rows) — join recipes ON food_id
-- ============================================================
INSERT INTO cleangoal.recipe_ingredients
    (recipe_id, ingredient_name, quantity, unit, is_optional, sort_order)
SELECT r.recipe_id, v.ingredient_name, v.quantity, v.unit, v.is_optional, v.sort_order
FROM cleangoal.recipes r
JOIN (VALUES
    ( 3, 'เนื้อขาหมู',    500.0, 'กรัม', false, 1),
    ( 4, 'หมูแดง',        200.0, 'กรัม', false, 1),
    ( 5, 'หมูสามชั้น',    200.0, 'กรัม', false, 1),
    ( 6, 'กุ้งสด',        150.0, 'กรัม', false, 1),
    ( 7, 'เส้นใหญ่',      150.0, 'กรัม', false, 1),
    ( 8, 'เส้นใหญ่',      150.0, 'กรัม', false, 1),
    ( 9, 'กุ้ง',          100.0, 'กรัม', false, 1),
    (10, 'กุ้ง',          100.0, 'กรัม', false, 1),
    (11, 'ข้าวสวย',       200.0, 'กรัม', false, 1),
    (12, 'เนื้อไก่',      200.0, 'กรัม', false, 1),
    (13, 'กุ้งสด',        150.0, 'กรัม', false, 1),
    (14, 'เนื้อไก่สับ',   150.0, 'กรัม', false, 1),
    (15, 'เส้นจันทน์',    100.0, 'กรัม', false, 1),
    (16, 'ข้าวสวย',       200.0, 'กรัม', false, 1),
    (17, 'มะละกอดิบ',     200.0, 'กรัม', false, 1),
    (18, 'หมูสับ',        200.0, 'กรัม', false, 1),
    (19, 'เนื้อไก่',      200.0, 'กรัม', false, 1),
    (20, 'เนื้อเป็ดย่าง', 150.0, 'กรัม', false, 1),
    (21, 'มะระ',          150.0, 'กรัม', false, 1),
    (22, 'เนื้อวัวสับ',   150.0, 'กรัม', false, 1)
) AS v(food_id, ingredient_name, quantity, unit, is_optional, sort_order)
    ON r.food_id = v.food_id;


-- ============================================================
-- 16. recipe_steps (20 rows)
-- ============================================================
INSERT INTO cleangoal.recipe_steps
    (recipe_id, step_number, title, instruction, time_minutes)
SELECT r.recipe_id, v.step_number, v.title, v.instruction, v.time_minutes
FROM cleangoal.recipes r
JOIN (VALUES
    ( 3, 1, 'ต้มขาหมู',     'ต้มขาหมูกับน้ำซีอิ๊วและพะโล้จนนุ่ม',             90),
    ( 4, 1, 'หั่นหมูแดง',    'หั่นหมูแดงเป็นชิ้นพอดีคำ',                        5),
    ( 5, 1, 'ทอดหมู',        'ทอดหมูสามชั้นจนกรอบ',                            15),
    ( 6, 1, 'แช่เส้น',       'แช่เส้นก๋วยเตี๋ยวในน้ำอุ่น 15 นาที',             15),
    ( 7, 1, 'หมักหมู',       'หมักหมูด้วยซีอิ๊วขาว น้ำตาล และกระเทียม',         10),
    ( 8, 1, 'ผัดซีอิ๊ว',     'ผัดเส้นใหญ่กับซีอิ๊วดำบนไฟแรง',                  10),
    ( 9, 1, 'เตรียมน้ำซุป',  'ต้มน้ำซุปกระดูกหมู เพิ่มซอสสุกี้',               15),
    (10, 1, 'ผัดสุกี้',      'ผัดซีฟู้ดกับซอสสุกี้บนไฟแรง',                    10),
    (11, 1, 'คลุกข้าว',      'คลุกข้าวสวยกับกะปิและน้ำมัน',                     5),
    (12, 1, 'เตรียมแกง',     'ผัดพริกแกงกับกะทิจนหอม',                         10),
    (13, 1, 'ต้มน้ำซุป',     'ต้มน้ำซุปด้วยตะไคร้ ใบมะกรูด ข่า',              10),
    (14, 1, 'ผัดกระเพรา',    'ผัดไก่สับกับพริกขี้หนูและใบกระเพรา',               8),
    (15, 1, 'แช่เส้นจันทน์', 'แช่เส้นจันทน์ในน้ำเย็น 20 นาที',                 20),
    (16, 1, 'ผัดข้าว',       'ผัดข้าวสวยกับไข่และกุ้งบนไฟแรง',                  8),
    (17, 1, 'ขูดมะละกอ',     'ขูดมะละกอดิบเป็นเส้น',                             5),
    (18, 1, 'สับหมู',        'สับเนื้อหมูและคลุกกับเครื่องปรุง',                10),
    (19, 1, 'เตรียมซุป',     'ต้มกะทิกับข่าตะไคร้จนเดือด',                      10),
    (20, 1, 'เตรียมแกง',     'ผัดพริกแกงเผ็ดกับกะทิจนหอม',                     10),
    (21, 1, 'ผัดมะระ',       'ผัดมะระกับไข่และซีอิ๊วขาว',                        8),
    (22, 1, 'ผัดกระเพรา',    'ผัดเนื้อวัวสับกับพริกและใบกระเพรา',                8)
) AS v(food_id, step_number, title, instruction, time_minutes)
    ON r.food_id = v.food_id;


-- ============================================================
-- 17. recipe_tips (20 rows)
-- ============================================================
INSERT INTO cleangoal.recipe_tips (recipe_id, tip_text, sort_order)
SELECT r.recipe_id, v.tip_text, 1
FROM cleangoal.recipes r
JOIN (VALUES
    ( 3, 'ต้มนานๆ ยิ่งนุ่ม เคล็ดลับคือใส่น้ำตาลกรวดเพื่อให้สีสวย'),
    ( 4, 'น้ำซอสอุ่นก่อนราดจะทำให้ข้าวหอมกว่า'),
    ( 5, 'ทอดหมูในน้ำมันร้อนจัดจะกรอบกว่า'),
    ( 6, 'ผัดไทยต้องใช้ไฟแรงและกระทะเหล็ก'),
    ( 7, 'หมักหมูทิ้งไว้ 30 นาทีก่อนทำ'),
    ( 8, 'ซีอิ๊วดำทำให้สีสวย ใส่ไม่มากเกินไป'),
    ( 9, 'น้ำซุปสุกี้ต้องเดือดก่อนใส่วัตถุดิบ'),
    (10, 'ผัดบนไฟแรงจะทำให้ไม่อมน้ำมัน'),
    (11, 'ข้าวอุ่นๆ จะคลุกกะปิได้ง่ายกว่า'),
    (12, 'กะทิสดทำให้รสชาติดีกว่ากะทิกล่อง'),
    (13, 'ใส่น้ำพริกเผาเพิ่มเพื่อรสเข้มข้น'),
    (14, 'ใบกระเพราใส่ตอนสุดท้ายจะหอมกว่า'),
    (15, 'เส้นจันทน์ไม่ต้องต้ม แค่แช่น้ำเย็น'),
    (16, 'ข้าวเย็นผัดได้เม็ดสวยกว่าข้าวสุกใหม่'),
    (17, 'ส้มตำยิ่งตำนานยิ่งหอม'),
    (18, 'ข้าวคั่วทำเองสดจะหอมกว่าซื้อ'),
    (19, 'ใส่น้ำมะนาวหลังยกลงจากเตาจะหอมกว่า'),
    (20, 'เป็ดย่างสุกดีก่อนจะทำให้แกงอร่อยกว่า'),
    (21, 'มะระขมขาดก่อนผัดจะลดความขม'),
    (22, 'พริกขี้หนูสดทำให้รสจัดกว่าพริกชี้ฟ้า')
) AS v(food_id, tip_text)
    ON r.food_id = v.food_id;


-- ============================================================
-- 18. recipe_tools (20 rows)
-- ============================================================
INSERT INTO cleangoal.recipe_tools (recipe_id, tool_name, tool_emoji, sort_order)
SELECT r.recipe_id, v.tool_name, v.tool_emoji, 1
FROM cleangoal.recipes r
JOIN (VALUES
    ( 3, 'หม้อใบใหญ่',  NULL),
    ( 4, 'กระทะ',       NULL),
    ( 5, 'กระทะทอด',    NULL),
    ( 6, 'กระทะเหล็ก',  NULL),
    ( 7, 'กระทะเหล็ก',  NULL),
    ( 8, 'กระทะเหล็ก',  NULL),
    ( 9, 'หม้อสุกี้',    NULL),
    (10, 'กระทะเหล็ก',  NULL),
    (11, 'ชาม',         NULL),
    (12, 'หม้อแกง',     NULL),
    (13, 'หม้อ',        NULL),
    (14, 'กระทะเหล็ก',  NULL),
    (15, 'กระทะเหล็ก',  NULL),
    (16, 'กระทะเหล็ก',  NULL),
    (17, 'ครกและสาก',   NULL),
    (18, 'ครกและสาก',   NULL),
    (19, 'หม้อแกง',     NULL),
    (20, 'หม้อแกง',     NULL),
    (21, 'กระทะ',       NULL),
    (22, 'กระทะเหล็ก',  NULL)
) AS v(food_id, tool_name, tool_emoji)
    ON r.food_id = v.food_id;


-- ============================================================
-- 19. recipe_reviews (20 rows) — UNIQUE(recipe_id, user_id)
--     food_ids 3-22
-- ============================================================
INSERT INTO cleangoal.recipe_reviews (recipe_id, user_id, rating, comment)
SELECT r.recipe_id, v.user_id, v.rating, v.comment
FROM cleangoal.recipes r
JOIN (VALUES
    ( 3,  1, 5, 'อร่อยมาก ขาหมูนุ่มมาก!'),
    ( 4,  2, 4, 'รสชาติดี หมูแดงสวย'),
    ( 5,  3, 5, 'หมูกรอบมากเลย ชอบ'),
    ( 6,  4, 4, 'ผัดไทยรสจัด ชอบมาก'),
    ( 7,  6, 3, 'ใช้ได้ครับ ไม่เลวเลย'),
    ( 8,  7, 5, 'ผัดซีอิ๊วอร่อยมาก'),
    ( 9,  8, 4, 'น้ำซุปหวานอร่อย'),
    (10,  9, 5, 'สุกี้แห้งสุดยอด'),
    (11, 10, 3, 'กะปิหอมดี แต่เค็มนิดหน่อย'),
    (12, 11, 5, 'แกงเขียวหวานอร่อยมากเลย'),
    (13, 12, 4, 'ต้มยำรสจัด ชอบ'),
    (14, 13, 5, 'กะเพราอร่อยสุดๆ'),
    (15, 14, 4, 'ผัดไทยเส้นจันท์น่าลอง'),
    (16, 15, 5, 'ข้าวผัดกุ้งอร่อยมาก'),
    (17, 16, 4, 'ส้มตำรสจัดถูกใจ'),
    (18, 18, 5, 'ลาบหมูอีสานแท้ๆ เด็ดมาก'),
    (19, 19, 4, 'ต้มข่าหวานมันอร่อย'),
    (20, 20, 3, 'แกงเผ็ดจัดไปหน่อย'),
    (21, 23, 4, 'มะระผัดไข่ทานง่าย'),
    (22, 24, 5, 'กระเพราเนื้อสุดยอด')
) AS v(food_id, user_id, rating, comment)
    ON r.food_id = v.food_id;


-- ============================================================
-- 20. recipe_favorites (20 rows) — UNIQUE(recipe_id, user_id)
--     food_ids 3-22, different user per recipe
-- ============================================================
INSERT INTO cleangoal.recipe_favorites (recipe_id, user_id)
SELECT r.recipe_id, v.user_id
FROM cleangoal.recipes r
JOIN (VALUES
    ( 3,  2), ( 4,  3), ( 5,  4), ( 6,  1), ( 7,  8),
    ( 8,  9), ( 9, 10), (10, 11), (11, 12), (12, 13),
    (13, 14), (14, 15), (15, 16), (16, 18), (17, 19),
    (18, 20), (19, 23), (20, 24), (21,  1), (22,  2)
) AS v(food_id, user_id)
    ON r.food_id = v.food_id;


-- ============================================================
-- 21. meals (20 rows)
-- ============================================================
INSERT INTO cleangoal.meals (user_id, meal_type, meal_time, total_amount)
VALUES
( 1, 'breakfast', NOW() - INTERVAL '6 days' + TIME '08:00:00', 1),
( 1, 'lunch',     NOW() - INTERVAL '6 days' + TIME '12:00:00', 1),
( 2, 'breakfast', NOW() - INTERVAL '5 days' + TIME '07:30:00', 1),
( 2, 'dinner',    NOW() - INTERVAL '5 days' + TIME '19:00:00', 1),
( 3, 'lunch',     NOW() - INTERVAL '4 days' + TIME '12:30:00', 1),
( 3, 'snack',     NOW() - INTERVAL '4 days' + TIME '15:00:00', 1),
( 4, 'breakfast', NOW() - INTERVAL '3 days' + TIME '08:00:00', 1),
( 4, 'lunch',     NOW() - INTERVAL '3 days' + TIME '12:00:00', 1),
( 6, 'dinner',    NOW() - INTERVAL '2 days' + TIME '18:30:00', 1),
( 6, 'snack',     NOW() - INTERVAL '2 days' + TIME '21:00:00', 1),
( 7, 'breakfast', NOW() - INTERVAL '1 day'  + TIME '07:00:00', 1),
( 7, 'lunch',     NOW() - INTERVAL '1 day'  + TIME '12:00:00', 1),
( 8, 'breakfast', NOW() - INTERVAL '1 day'  + TIME '08:00:00', 1),
( 8, 'dinner',    NOW() - INTERVAL '1 day'  + TIME '19:00:00', 1),
( 9, 'lunch',     NOW() - INTERVAL '1 day'  + TIME '13:00:00', 1),
(10, 'breakfast', NOW() - INTERVAL '2 days' + TIME '08:00:00', 1),
(11, 'lunch',     NOW() - INTERVAL '3 days' + TIME '12:00:00', 1),
(12, 'dinner',    NOW() - INTERVAL '4 days' + TIME '18:00:00', 1),
(13, 'snack',     NOW() - INTERVAL '5 days' + TIME '15:00:00', 1),
(18, 'breakfast', NOW() - INTERVAL '1 day'  + TIME '07:30:00', 1);


-- ============================================================
-- 22. detail_items (20 rows) — link to meals via ROW_NUMBER()
-- ============================================================
INSERT INTO cleangoal.detail_items (meal_id, food_id, food_name, amount, unit_id, cal_per_unit)
SELECT m.meal_id,
       v.food_id,
       f.food_name,
       v.amount,
       1,
       f.calories
FROM (
    SELECT meal_id,
           ROW_NUMBER() OVER (ORDER BY meal_id) AS rn
    FROM cleangoal.meals
    ORDER BY meal_id
    LIMIT 20
) m
JOIN (VALUES
    ( 1,  3, 1.0), ( 2,  6, 1.0), ( 3,  4, 1.0), ( 4, 12, 1.0),
    ( 5,  7, 1.0), ( 6, 14, 0.5), ( 7,  5, 1.0), ( 8,  9, 1.0),
    ( 9, 13, 1.0), (10, 17, 0.5), (11,  4, 1.0), (12, 11, 1.0),
    (13,  3, 1.0), (14, 20, 1.0), (15,  8, 1.0), (16,  6, 1.0),
    (17,  7, 1.0), (18, 19, 1.0), (19, 14, 0.5), (20,  4, 1.0)
) AS v(rn, food_id, amount) ON m.rn = v.rn
JOIN cleangoal.foods f ON f.food_id = v.food_id;


-- ============================================================
-- 23. daily_summaries (20 rows) — UNIQUE(user_id, date_record)
-- ============================================================
INSERT INTO cleangoal.daily_summaries
    (user_id, date_record, total_calories_intake, goal_calories, is_goal_met)
VALUES
( 1, CURRENT_DATE -  6, 1230, 2000, false),
( 2, CURRENT_DATE -  5, 1890, 1800, true),
( 3, CURRENT_DATE -  4,  920, 2000, false),
( 4, CURRENT_DATE -  3, 1540, 2200, false),
( 6, CURRENT_DATE -  2, 2050, 2000, true),
( 7, CURRENT_DATE -  1, 1750, 1900, false),
( 8, CURRENT_DATE,      1600, 1800, false),
( 9, CURRENT_DATE -  6, 1320, 1500, false),
(10, CURRENT_DATE -  5, 2100, 2000, true),
(11, CURRENT_DATE -  4, 1800, 2100, false),
(12, CURRENT_DATE -  3, 1950, 1950, true),
(13, CURRENT_DATE -  2, 1430, 2000, false),
(14, CURRENT_DATE -  1, 2200, 2200, true),
(15, CURRENT_DATE,       950, 1800, false),
(16, CURRENT_DATE -  6, 1680, 2000, false),
(18, CURRENT_DATE -  5, 1760, 2096, false),
(19, CURRENT_DATE -  4, 1850, 2000, false),
(20, CURRENT_DATE -  3, 2000, 1903, true),
(23, CURRENT_DATE -  2, 1600, 1708, false),
(24, CURRENT_DATE -  1, 2100, 1708, false);


-- ============================================================
-- 24. weekly_summaries (20 rows) — UNIQUE(user_id, start_date)
-- ============================================================
INSERT INTO cleangoal.weekly_summaries
    (user_id, start_date, avg_daily_calories, days_logged_count)
VALUES
( 1, DATE_TRUNC('week', CURRENT_DATE - INTERVAL '4 weeks')::date, 1800, 5),
( 2, DATE_TRUNC('week', CURRENT_DATE - INTERVAL '4 weeks')::date, 1950, 6),
( 3, DATE_TRUNC('week', CURRENT_DATE - INTERVAL '4 weeks')::date, 1700, 4),
( 4, DATE_TRUNC('week', CURRENT_DATE - INTERVAL '4 weeks')::date, 2200, 7),
( 6, DATE_TRUNC('week', CURRENT_DATE - INTERVAL '4 weeks')::date, 2000, 5),
( 7, DATE_TRUNC('week', CURRENT_DATE - INTERVAL '4 weeks')::date, 1850, 6),
( 8, DATE_TRUNC('week', CURRENT_DATE - INTERVAL '4 weeks')::date, 1750, 5),
( 9, DATE_TRUNC('week', CURRENT_DATE - INTERVAL '4 weeks')::date, 1500, 7),
(10, DATE_TRUNC('week', CURRENT_DATE - INTERVAL '4 weeks')::date, 2100, 6),
(11, DATE_TRUNC('week', CURRENT_DATE - INTERVAL '4 weeks')::date, 2050, 5),
( 1, DATE_TRUNC('week', CURRENT_DATE - INTERVAL '3 weeks')::date, 1820, 5),
( 2, DATE_TRUNC('week', CURRENT_DATE - INTERVAL '3 weeks')::date, 1900, 6),
( 3, DATE_TRUNC('week', CURRENT_DATE - INTERVAL '3 weeks')::date, 1750, 5),
( 4, DATE_TRUNC('week', CURRENT_DATE - INTERVAL '3 weeks')::date, 2100, 7),
( 6, DATE_TRUNC('week', CURRENT_DATE - INTERVAL '3 weeks')::date, 1980, 6),
(12, DATE_TRUNC('week', CURRENT_DATE - INTERVAL '3 weeks')::date, 1950, 5),
(13, DATE_TRUNC('week', CURRENT_DATE - INTERVAL '3 weeks')::date, 1600, 4),
(18, DATE_TRUNC('week', CURRENT_DATE - INTERVAL '3 weeks')::date, 1900, 6),
(23, DATE_TRUNC('week', CURRENT_DATE - INTERVAL '3 weeks')::date, 1700, 5),
(24, DATE_TRUNC('week', CURRENT_DATE - INTERVAL '3 weeks')::date, 2000, 7);


-- ============================================================
-- 25. user_meal_plans (20 rows)
-- ============================================================
INSERT INTO cleangoal.user_meal_plans
    (user_id, name, description, source_type, is_premium)
VALUES
( 1, 'แผนลดน้ำหนัก 7 วัน',         'แผนอาหารลดน้ำหนักสำหรับ 1 สัปดาห์',     'SYSTEM', false),
( 2, 'แผนเพิ่มกล้ามเนื้อ',           'อาหารโปรตีนสูงสำหรับสร้างกล้ามเนื้อ',   'SYSTEM', false),
( 3, 'แผนอาหารเจ',                   'เมนูอาหารเจสำหรับ 7 วัน',               'USER',   false),
( 4, 'แผนคาร์บต่ำ',                  'Low carb diet plan',                    'SYSTEM', true),
( 6, 'แผน Clean Eating',             'แผนอาหารสะอาด ไม่มีแป้งขัดสี',           'SYSTEM', true),
( 7, 'แผนอาหารรักษาน้ำหนัก',         'แผนอาหารสำหรับรักษาน้ำหนักคงที่',       'SYSTEM', false),
( 8, 'แผนสำหรับผู้แพ้กลูเตน',        'เมนูปราศจากกลูเตนครบถ้วน',              'SYSTEM', true),
( 9, 'แผนอาหาร 1500 kcal',          'แผนอาหารจำกัดพลังงาน 1500 kcal/วัน',   'SYSTEM', false),
(10, 'แผน High Protein',             'อาหารโปรตีนสูงสำหรับนักออกกำลังกาย',   'SYSTEM', true),
(11, 'แผนลดน้ำตาล',                  'แผนอาหารน้ำตาลต่ำสำหรับผู้ป่วยเบาหวาน','SYSTEM', false),
(12, 'แผนอาหารไทยสุขภาพดี',          'เมนูอาหารไทยที่ดีต่อสุขภาพ 7 วัน',      'USER',   false),
(13, 'แผนอาหารมังสวิรัติ',            'แผนอาหารมังสวิรัติครบโภชนาการ',          'SYSTEM', false),
(14, 'แผนอาหารเพิ่มพลังงาน',         'เมนูให้พลังงานสูงสำหรับนักกีฬา',        'USER',   false),
(15, 'แผนอาหารสำหรับเด็ก',           'แผนโภชนาการสมวัยสำหรับเด็ก',            'SYSTEM', false),
(16, 'แผนอาหารอีสาน',                'เมนูอาหารอีสานสุขภาพดี',                'USER',   false),
(18, 'แผนอาหารทะเล',                 'เมนูอาหารทะเลสดสุขภาพดี',               'USER',   false),
(19, 'แผนอาหารสำหรับวัยทอง',         'แผนโภชนาการสำหรับวัย 40+ ปี',           'SYSTEM', false),
(20, 'แผนลดไขมัน',                   'แผนอาหารลดไขมันในเลือด',                'SYSTEM', true),
(23, 'แผนอาหารออร์แกนิค',            'เมนูอาหารออร์แกนิคทั้งหมด',             'USER',   true),
(24, 'แผนอาหารก่อน-หลังออกกำลัง',   'Pre/Post workout meal plan',             'SYSTEM', true);


-- ============================================================
-- 26. progress (20 rows)
-- ============================================================
INSERT INTO cleangoal.progress (user_id, current_streak, weekly_target)
VALUES
( 1,  5, 'ลดน้ำหนัก 0.5 กิโล/สัปดาห์'),
( 2,  3, 'ลดน้ำหนัก 0.5 กิโล/สัปดาห์'),
( 3,  7, 'รักษาน้ำหนัก'),
( 4,  2, 'เพิ่มกล้ามเนื้อ 0.5 กิโล/สัปดาห์'),
( 6, 10, 'ลดน้ำหนัก 1 กิโล/สัปดาห์'),
( 7,  4, 'เพิ่มกล้ามเนื้อ'),
( 8,  6, 'รักษาน้ำหนัก'),
( 9,  1, 'ลดน้ำหนัก 0.3 กิโล/สัปดาห์'),
(10,  8, 'ลดน้ำหนัก 1 กิโล/สัปดาห์'),
(11,  3, 'เพิ่มกล้ามเนื้อ'),
(12, 14, 'รักษาน้ำหนัก'),
(13,  5, 'ลดน้ำหนัก 0.5 กิโล/สัปดาห์'),
(14,  9, 'เพิ่มน้ำหนัก 0.5 กิโล/สัปดาห์'),
(15,  2, 'เพิ่มน้ำหนัก 0.3 กิโล/สัปดาห์'),
(16,  7, 'ลดน้ำหนัก 0.5 กิโล/สัปดาห์'),
(18, 12, 'ลดน้ำหนัก 0.3 กิโล/สัปดาห์'),
(19,  4, 'ลดน้ำหนัก 0.5 กิโล/สัปดาห์'),
(20,  6, 'ลดน้ำหนัก 0.5 กิโล/สัปดาห์'),
(23,  3, 'ลดน้ำหนัก 0.3 กิโล/สัปดาห์'),
(24,  8, 'เพิ่มกล้ามเนื้อ 0.5 กิโล/สัปดาห์');


-- ============================================================
-- 27. notifications (20 rows)
-- ============================================================
INSERT INTO cleangoal.notifications (user_id, title, message, type, is_read)
VALUES
( 1, 'ยินดีต้อนรับ!',            'ยินดีต้อนรับสู่ CalGuard! เริ่มติดตามอาหารของคุณได้เลย',           'system_announcement', true),
( 2, 'อัปเดตเป้าหมาย',           'คุณใกล้ถึงเป้าหมายน้ำหนักแล้ว! ยังอีก 2 กิโลกรัม',              'achievement',         false),
( 3, 'สถิติ 7 วัน',               'คุณบันทึกอาหารครบ 7 วันต่อเนื่อง! เยี่ยมมาก!',                  'achievement',         false),
( 4, 'เมนูใหม่',                  'มีเมนูอาหารใหม่ที่แนะนำสำหรับคุณ',                              'content_update',      false),
( 6, 'แจ้งเตือนน้ำหนัก',          'อย่าลืมบันทึกน้ำหนักประจำสัปดาห์นะคะ',                          'system_alert',        false),
( 7, 'ขอแสดงความยินดี!',          'คุณทำตามแผนอาหารครบ 1 เดือนแล้ว!',                             'achievement',         true),
( 8, 'เนื้อหาสุขภาพใหม่',         'บทความ: "วิธีคำนวณแคลอรี่ที่ถูกต้อง" พร้อมให้อ่านแล้ว',          'content_update',      false),
( 9, 'อัปเดตแอป',                'CalGuard อัปเดตใหม่! มีฟีเจอร์แผนที่ร้านอาหาร',                'system_announcement', false),
(10, 'ถึงเวลาออกกำลังกาย',        'ตามแผนของคุณ วันนี้ควรออกกำลังกาย 30 นาที',                     'system_alert',        true),
(11, 'แคลอรี่เกินเป้าหมาย',       'วันนี้คุณรับแคลอรี่เกินเป้าหมาย 200 kcal',                      'system_alert',        false),
(12, 'สตรีคใหม่!',                'คุณบันทึกอาหารต่อเนื่อง 14 วัน! สุดยอดมาก!',                   'achievement',         false),
(13, 'เมนูแนะนำ',                'เมนูใหม่ "ข้าวกล้องผัดผัก" เหมาะกับเป้าหมายของคุณ',              'content_update',      false),
(14, 'ดื่มน้ำให้ครบ',              'วันนี้คุณดื่มน้ำแค่ 4 แก้ว ควรดื่มให้ครบ 8 แก้วนะคะ',            'system_alert',        false),
(15, 'เป้าหมายสำเร็จ!',           'ยินดีด้วย! คุณลดน้ำหนักได้ตามเป้าหมายรายสัปดาห์',               'achievement',         false),
(16, 'อาหารใหม่รอการอนุมัติ',     'คำขอเพิ่มเมนูอาหารของคุณกำลังรอการตรวจสอบ',                     'system_alert',        true),
(18, 'แผนอาหารสำเร็จ',            'แผนอาหาร "ลดน้ำหนัก 7 วัน" เสร็จสิ้นแล้ว!',                   'achievement',         false),
(19, 'เคล็ดลับสุขภาพ',            'เคล็ดลับ: ทานอาหารช้าๆ ช่วยลดการกินเกินได้',                   'content_update',      false),
(20, 'น้ำหนักลดลง!',              'น้ำหนักของคุณลดลง 0.5 กิโลจากอาทิตย์ที่แล้ว',                  'achievement',         false),
(23, 'ครบรอบ 1 เดือน',            'คุณใช้ CalGuard ครบ 1 เดือนแล้ว! ขอบคุณที่ไว้วางใจเรา',          'system_announcement', false),
(24, 'โปรตีนต่ำกว่าเป้า',          'วันนี้โปรตีนของคุณต่ำกว่าเป้าหมาย ลองเพิ่มเนื้อสัตว์ดูนะ',        'system_alert',        false);


-- ============================================================
-- 28. health_contents (20 rows)
-- ============================================================
INSERT INTO cleangoal.health_contents
    (title, type, thumbnail_url, description, category_tag, difficulty_level, is_published)
VALUES
('วิธีคำนวณแคลอรี่ที่ถูกต้อง',            'article', '/images/hc1.jpg',  'เรียนรู้วิธีนับแคลอรี่อย่างถูกต้อง',           'โภชนาการ',     'beginner',     true),
('ท่าออกกำลังกายลดพุง 10 นาที',           'video',   '/images/hc2.jpg',  'ท่าออกกำลังกายง่ายๆ ลดพุงได้ผลจริง',          'ออกกำลังกาย',  'beginner',     true),
('โปรตีนสำคัญแค่ไหนต่อร่างกาย',           'article', '/images/hc3.jpg',  'ทำความรู้จักโปรตีนและประโยชน์ต่อร่างกาย',      'โภชนาการ',     'intermediate', true),
('อาหารไทยสุขภาพดี 10 เมนู',              'article', '/images/hc4.jpg',  'เมนูอาหารไทยที่ดีต่อสุขภาพและคุมน้ำหนัก',     'อาหาร',        'beginner',     true),
('การนอนหลับกับการลดน้ำหนัก',             'article', '/images/hc5.jpg',  'การนอนหลับที่ดีช่วยลดน้ำหนักได้อย่างไร',      'สุขภาพ',       'beginner',     true),
('โยคะสำหรับผู้เริ่มต้น',                  'video',   '/images/hc6.jpg',  'ท่าโยคะง่ายๆ สำหรับผู้เริ่มต้นออกกำลังกาย',  'ออกกำลังกาย',  'beginner',     true),
('ดื่มน้ำให้ถูกวิธีเพื่อสุขภาพดี',          'article', '/images/hc7.jpg',  'ปริมาณน้ำที่เหมาะสมและวิธีดื่มน้ำที่ถูกต้อง',  'สุขภาพ',       'beginner',     true),
('คาร์โบไฮเดรตดีกับคาร์โบไฮเดรตไม่ดี',   'article', '/images/hc8.jpg',  'ความแตกต่างของคาร์บดีและไม่ดี',              'โภชนาการ',     'intermediate', true),
('การออกกำลังกาย HIIT 20 นาที',           'video',   '/images/hc9.jpg',  'HIIT เผาผลาญแคลอรี่สูงใน 20 นาที',           'ออกกำลังกาย',  'intermediate', true),
('อ่านฉลากอาหารอย่างไรให้ได้ประโยชน์',    'article', '/images/hc10.jpg', 'วิธีอ่านฉลากโภชนาการบนบรรจุภัณฑ์อาหาร',       'โภชนาการ',     'beginner',     true),
('สูตรน้ำดีท็อกซ์สำหรับเช้า',             'video',   '/images/hc11.jpg', 'น้ำดีท็อกซ์สูตรง่ายช่วยกระตุ้นระบบเผาผลาญ',   'อาหาร',        'beginner',     true),
('ไขมันดี vs ไขมันไม่ดี',                 'article', '/images/hc12.jpg', 'รู้จักไขมัน HDL และ LDL และผลต่อสุขภาพ',      'โภชนาการ',     'intermediate', true),
('การวางแผนมื้ออาหารรายสัปดาห์',          'article', '/images/hc13.jpg', 'วิธี Meal Prep สำหรับคนทำงาน',               'อาหาร',        'intermediate', true),
('เดินวันละ 10,000 ก้าว ดีอย่างไร',       'article', '/images/hc14.jpg', 'ประโยชน์ของการเดินออกกำลังกาย',              'ออกกำลังกาย',  'beginner',     true),
('อาหารเจสำหรับนักกีฬา',                  'article', '/images/hc15.jpg', 'แนวทางโภชนาการสำหรับนักกีฬาที่ทานมังสวิรัติ', 'อาหาร',        'advanced',     true),
('การลดน้ำตาลในชีวิตประจำวัน',            'article', '/images/hc16.jpg', 'วิธีลดการบริโภคน้ำตาลทีละน้อย',              'สุขภาพ',       'beginner',     true),
('วิ่งเพื่อสุขภาพหัวใจ',                   'video',   '/images/hc17.jpg', 'โปรแกรมวิ่งสำหรับผู้เริ่มต้น 8 สัปดาห์',     'ออกกำลังกาย',  'intermediate', true),
('อาหารเช้าสำคัญที่สุด จริงไหม?',         'article', '/images/hc18.jpg', 'ข้อเท็จจริงเกี่ยวกับมื้อเช้าและการลดน้ำหนัก', 'โภชนาการ',     'beginner',     true),
('Mindful Eating กินอย่างมีสติ',          'article', '/images/hc19.jpg', 'เทคนิคการกินอย่างมีสติเพื่อควบคุมน้ำหนัก',   'สุขภาพ',       'intermediate', true),
('วิตามินและแร่ธาตุจำเป็น',                'article', '/images/hc20.jpg', 'วิตามินและแร่ธาตุที่ร่างกายต้องการในแต่ละวัน', 'โภชนาการ',     'advanced',     true);


-- ============================================================
-- 29. water_logs (20 rows) — UNIQUE(user_id, date_record)
-- ============================================================
INSERT INTO cleangoal.water_logs (user_id, glasses, date_record)
VALUES
( 1, 8, CURRENT_DATE), ( 2, 6, CURRENT_DATE),
( 3, 8, CURRENT_DATE), ( 4, 7, CURRENT_DATE),
( 6, 5, CURRENT_DATE), ( 7, 8, CURRENT_DATE),
( 8, 4, CURRENT_DATE), ( 9, 8, CURRENT_DATE),
(10, 3, CURRENT_DATE), (11, 7, CURRENT_DATE),
(12, 8, CURRENT_DATE), (13, 6, CURRENT_DATE),
(14, 8, CURRENT_DATE), (15, 5, CURRENT_DATE),
(16, 7, CURRENT_DATE), (18, 8, CURRENT_DATE),
(19, 6, CURRENT_DATE), (20, 7, CURRENT_DATE),
(23, 8, CURRENT_DATE), (24, 5, CURRENT_DATE);


-- ============================================================
-- 30. chat_messages (20 rows)
-- ============================================================
INSERT INTO cleangoal.chat_messages (user_id, role, content)
VALUES
( 1, 'user',      'วันนี้ควรทานอะไรเพื่อลดน้ำหนักครับ?'),
( 1, 'assistant', 'แนะนำให้ทานอาหารโปรตีนสูง เช่น ไก่อบ ปลานึ่ง ควบคู่กับผักและข้าวกล้องครับ'),
( 2, 'user',      'ออกกำลังกายวันนี้เผาผลาญไปกี่แคลอรี่?'),
( 2, 'assistant', 'ขึ้นอยู่กับประเภทและเวลาออกกำลังกายครับ เดิน 30 นาทีเผาผลาญประมาณ 150 kcal'),
( 3, 'user',      'โปรตีนควรกินเท่าไหร่ต่อวัน?'),
( 3, 'assistant', 'สำหรับคนทั่วไปแนะนำ 0.8-1.0 กรัมต่อน้ำหนักตัว 1 กิโลกรัมครับ'),
( 4, 'user',      'แผนอาหาร Keto เหมาะกับผมไหม?'),
( 4, 'assistant', 'Keto เหมาะกับคนที่ต้องการลดน้ำหนักเร็ว แต่ควรปรึกษาแพทย์ก่อนนะครับ'),
( 6, 'user',      'ทานก่อนออกกำลังกายควรกินอะไร?'),
( 6, 'assistant', 'ควรทานคาร์โบไฮเดรตซับซ้อน เช่น ข้าวกล้อง หรือกล้วย ก่อนออกกำลังกาย 1-2 ชั่วโมงครับ'),
( 7, 'user',      'น้ำหนักไม่ลดแม้ออกกำลังกายทุกวัน เพราะอะไร?'),
( 7, 'assistant', 'อาจเกิดจากการกินมากเกินไป หรือร่างกายปรับตัวแล้ว ลองเปลี่ยนรูปแบบการออกกำลังกายครับ'),
( 8, 'user',      'อาหารอะไรช่วยเพิ่มกล้ามเนื้อได้ดีที่สุด?'),
( 8, 'assistant', 'ไข่ขาว อกไก่ ปลาทูน่า กรีกโยเกิร์ต และถั่วต่างๆ ล้วนเป็นแหล่งโปรตีนชั้นดีครับ'),
( 9, 'user',      'แคลอรี่วันนี้กินเกินไปหน่อย ทำไงดี?'),
( 9, 'assistant', 'ไม่ต้องกังวลครับ พรุ่งนี้ลดแคลอรี่ลงนิดหน่อยและเพิ่มการออกกำลังกายก็พอ'),
(18, 'user',      'อยากทราบ BMI ของตัวเองอยู่ในเกณฑ์ไหน?'),
(18, 'assistant', 'จากข้อมูลของคุณ BMI อยู่ที่ประมาณ 23.8 ซึ่งอยู่ในเกณฑ์ปกติครับ ดีมากเลย!');


-- ============================================================
-- 31. user_health_content_views (20 rows) — PK(user_id, content_id)
--     join health_contents by row order to get content_id
-- ============================================================
INSERT INTO cleangoal.user_health_content_views (user_id, content_id, is_bookmarked)
SELECT v.user_id, hc.content_id, v.bookmarked
FROM (VALUES
    ( 1,  1, true),  ( 2,  2, false), ( 3,  3, true),  ( 4,  4, false),
    ( 6,  5, true),  ( 7,  6, false), ( 8,  7, true),  ( 9,  8, false),
    (10,  9, true),  (11, 10, false), (12, 11, true),  (13, 12, false),
    (14, 13, true),  (15, 14, false), (16, 15, true),  (18, 16, true),
    (19, 17, false), (20, 18, true),  (23, 19, false), (24, 20, true)
) AS v(user_id, hc_row, bookmarked)
JOIN (
    SELECT content_id,
           ROW_NUMBER() OVER (ORDER BY content_id) AS rn
    FROM cleangoal.health_contents
) hc ON hc.rn = v.hc_row;

-- ============================================================
-- NEW: foods with varied serving units (oz, L, ทัพพี, จาน)
-- ============================================================

-- หน่วย: ออนซ์ (oz) — อาหารสไตล์ตะวันตก / โปรตีน
INSERT INTO cleangoal.foods
    (food_name, food_type, calories, protein, carbs, fat, serving_quantity, serving_unit, food_category)
VALUES
('สเต็กเนื้อวัว',       'meal',    540, 48.0,  0.0, 38.0, 8,   'oz', 'เนื้อสัตว์'),
('อกไก่ย่าง',           'meal',    165, 31.0,  0.0,  3.6, 6,   'oz', 'เนื้อสัตว์'),
('แซลมอนย่าง',          'meal',    310, 34.0,  0.0, 18.0, 6,   'oz', 'เนื้อสัตว์'),
('ชีสเชดดาร์',          'snack',   113,  7.0,  0.4,  9.3, 1,   'oz', 'นมและไข่'),
('เนื้อไก่งวงรมควัน',    'meal',    100, 18.0,  1.0,  2.5, 3,   'oz', 'เนื้อสัตว์'),
('ทูน่ากระป๋อง',        'meal',     90, 20.0,  0.0,  0.5, 3,   'oz', 'เนื้อสัตว์');

-- หน่วย: ลิตร (L) — เครื่องดื่มและน้ำซุป
INSERT INTO cleangoal.foods
    (food_name, food_type, calories, protein, carbs, fat, serving_quantity, serving_unit, food_category)
VALUES
('น้ำเปล่า',             'beverage',  0,  0.0,  0.0,  0.0, 1,   'L',  'เครื่องดื่ม'),
('น้ำซุปไก่ใส',          'meal',     30,  4.0,  1.5,  0.5, 1,   'L',  'ซุปและแกง'),
('น้ำซุปกระดูกหมู',     'meal',     50,  6.0,  1.0,  2.0, 1,   'L',  'ซุปและแกง'),
('ชาเขียวไม่หวาน',      'beverage',  2,  0.0,  0.5,  0.0, 1,   'L',  'เครื่องดื่ม'),
('น้ำมะนาวโซดา',        'beverage', 40,  0.0, 10.0,  0.0, 1,   'L',  'เครื่องดื่ม'),
('น้ำแอปเปิ้ล 100%',    'beverage',470,  0.5,115.0,  0.5, 1,   'L',  'เครื่องดื่ม');

-- หน่วย: ทัพพี — ข้าว แกง และอาหารตักเป็นทัพพี (~150 g ต่อทัพพี)
INSERT INTO cleangoal.foods
    (food_name, food_type, calories, protein, carbs, fat, serving_quantity, serving_unit, food_category)
VALUES
('ข้าวสวย',              'meal',    195,  4.0, 43.0,  0.3, 1,   'ทัพพี', 'ข้าวและแป้ง'),
('แกงเขียวหวานไก่',      'meal',    230, 15.0,  8.0, 15.0, 1,   'ทัพพี', 'ซุปและแกง'),
('แกงมัสมั่นเนื้อ',      'meal',    310, 18.0, 14.0, 20.0, 1,   'ทัพพี', 'ซุปและแกง'),
('แกงส้มกุ้ง',           'meal',    140, 12.0,  9.0,  5.0, 1,   'ทัพพี', 'ซุปและแกง'),
('ต้มยำกุ้ง',            'meal',    120, 10.0,  6.0,  6.0, 1,   'ทัพพี', 'ซุปและแกง'),
('ข้าวเหนียว',           'meal',    170,  3.5, 37.0,  0.5, 1,   'ทัพพี', 'ข้าวและแป้ง');

-- ============================================================
-- เครื่องดื่มไทยที่ขาดจากชุดข้อมูลเดิม (เพิ่มเติม)
-- หน่วย ml, serving_quantity = ปริมาณต่อ 1 แก้ว/กล่อง/ขวด
-- ค่าโภชนาการอ้างอิง: USDA FoodData Central + INMU Thailand Food Composition
-- ============================================================
INSERT INTO cleangoal.foods
    (food_name, food_type, calories, protein, carbs, fat, serving_quantity, serving_unit, food_category)
VALUES
-- ผลไม้ไทย
('น้ำลำใย',           'beverage',  65, 0.2, 16.0, 0.0, 250, 'ml', 'เครื่องดื่ม'),
('น้ำกระเจี๊ยบ',      'beverage',  45, 0.5, 11.0, 0.0, 250, 'ml', 'เครื่องดื่ม'),
('น้ำมังคุด',         'beverage',  70, 0.3, 17.5, 0.1, 250, 'ml', 'เครื่องดื่ม'),
('น้ำองุ่น 100%',     'beverage', 130, 0.7, 32.0, 0.0, 250, 'ml', 'เครื่องดื่ม'),
-- สมุนไพรไทย
('น้ำขิง',            'beverage',  55, 0.5, 13.0, 0.0, 250, 'ml', 'เครื่องดื่ม'),
('น้ำมะตูม',          'beverage',  50, 0.3, 12.0, 0.0, 250, 'ml', 'เครื่องดื่ม'),
('น้ำตะไคร้',         'beverage',  35, 0.2,  9.0, 0.0, 250, 'ml', 'เครื่องดื่ม'),
('น้ำสมุนไพรรวม',    'beverage',  40, 0.2, 10.0, 0.0, 250, 'ml', 'เครื่องดื่ม'),
-- นมทางเลือก
('นมข้าวโอ๊ต',        'beverage', 120, 3.0, 16.0, 5.0, 250, 'ml', 'เครื่องดื่ม'),
('นมอัลมอนด์',        'beverage',  39, 1.5,  3.5, 2.5, 250, 'ml', 'เครื่องดื่ม'),
-- เครื่องดื่มยอดนิยม
('ชานมไข่มุก',        'beverage', 280, 3.0, 52.0, 7.0, 500, 'ml', 'เครื่องดื่ม'),
('เครื่องดื่มชูกำลัง','beverage', 115, 0.0, 28.0, 0.0, 150, 'ml', 'เครื่องดื่ม'),
('น้ำมะพร้าวอ่อน',   'beverage',  46, 0.5, 11.0, 0.2, 350, 'ml', 'เครื่องดื่ม');

-- เชื่อม beverages table สำหรับรายการที่เพิ่มใหม่
INSERT INTO cleangoal.beverages
    (food_id, volume_ml, is_alcoholic, caffeine_mg, sugar_level_label, container_type)
SELECT
    f.food_id,
    f.serving_quantity AS volume_ml,
    false              AS is_alcoholic,
    CASE f.food_name
        WHEN 'เครื่องดื่มชูกำลัง' THEN 50
        ELSE 0
    END AS caffeine_mg,
    CASE f.food_name
        WHEN 'ชานมไข่มุก'       THEN 'หวาน'
        WHEN 'เครื่องดื่มชูกำลัง' THEN 'หวานมาก'
        WHEN 'น้ำองุ่น 100%'    THEN 'หวานปานกลาง'
        WHEN 'นมข้าวโอ๊ต'       THEN 'ไม่หวาน'
        WHEN 'นมอัลมอนด์'       THEN 'ไม่หวาน'
        ELSE 'หวานน้อย'
    END AS sugar_level_label,
    CASE f.food_name
        WHEN 'ชานมไข่มุก'       THEN 'แก้วพลาสติก'
        WHEN 'เครื่องดื่มชูกำลัง' THEN 'ขวดแก้ว'
        WHEN 'น้ำมะพร้าวอ่อน'  THEN 'ลูกมะพร้าว'
        ELSE 'แก้ว'
    END AS container_type
FROM cleangoal.foods f
WHERE f.food_type = 'beverage'
  AND f.food_name IN (
      'น้ำลำใย','น้ำกระเจี๊ยบ','น้ำมังคุด','น้ำองุ่น 100%',
      'น้ำขิง','น้ำมะตูม','น้ำตะไคร้','น้ำสมุนไพรรวม',
      'นมข้าวโอ๊ต','นมอัลมอนด์','ชานมไข่มุก',
      'เครื่องดื่มชูกำลัง','น้ำมะพร้าวอ่อน'
  );

-- หน่วย: จาน — อาหารจานเดียว (~300-400 g ต่อจาน)
INSERT INTO cleangoal.foods
    (food_name, food_type, calories, protein, carbs, fat, serving_quantity, serving_unit, food_category)
VALUES
('ผัดไทยกุ้ง',           'meal',    490, 22.0, 68.0, 14.0, 1,   'จาน', 'อาหารจานเดียว'),
('ข้าวมันไก่',            'meal',    520, 28.0, 65.0, 14.0, 1,   'จาน', 'อาหารจานเดียว'),
('ข้าวหมูแดง',            'meal',    560, 26.0, 70.0, 16.0, 1,   'จาน', 'อาหารจานเดียว'),
('ส้มตำไทย',              'meal',    150,  5.0, 28.0,  3.0, 1,   'จาน', 'อาหารจานเดียว'),
('ราดหน้าหมู',            'meal',    510, 22.0, 72.0, 14.0, 1,   'จาน', 'อาหารจานเดียว'),
('ข้าวผัดกุ้ง',           'meal',    480, 18.0, 66.0, 15.0, 1,   'จาน', 'อาหารจานเดียว'),
('บะหมี่เกี๊ยวหมูแดง',   'meal',    430, 20.0, 62.0, 10.0, 1,   'จาน', 'อาหารจานเดียว'),
('ยำวุ้นเส้น',            'meal',    220,  9.0, 38.0,  4.0, 1,   'จาน', 'อาหารจานเดียว');

COMMIT;
