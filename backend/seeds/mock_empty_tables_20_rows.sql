-- Demo/mock data for user-facing tables that are intentionally sparse in a
-- fresh Supabase project. This file is idempotent and safe to run multiple
-- times.
--
-- Scope:
--   - Adds demo users under @caloriesguard.local.
--   - Adds 10 extra mock beverage foods so beverages can reach 20 rows.
--   - Seeds 20+ rows into empty/sparse UX tables without touching auth secrets.
--
-- Marker used for easy audit/removal: mock_seed_20_rows

BEGIN;

SET search_path TO cleangoal, public;

-- 1) Dedicated demo users. They keep mock logs/favorites away from real users.
INSERT INTO users (
  email,
  password_hash,
  username,
  role_id,
  is_email_verified,
  gender,
  birth_date,
  height_cm,
  current_weight_kg,
  goal_type,
  target_weight_kg,
  target_calories,
  target_protein,
  target_carbs,
  target_fat,
  activity_level,
  consent_accepted_at,
  region,
  region_source,
  updated_at
)
VALUES
  ('demo.user01@caloriesguard.local', '$2b$12$H6SPSDLBoNnPdf3CWnC3LO1M0yKH4KqVXTmtHXuBGP7eLz1dwyav6', 'Demo User 01', 2, TRUE, 'female', '1996-02-14', 162, 58, 'maintain_weight', 58, 1850, 95, 230, 55, 'lightly_active', NOW(), 'central', 'manual', NOW()),
  ('demo.user02@caloriesguard.local', '$2b$12$H6SPSDLBoNnPdf3CWnC3LO1M0yKH4KqVXTmtHXuBGP7eLz1dwyav6', 'Demo User 02', 2, TRUE, 'male', '1992-08-09', 174, 76, 'lose_weight', 70, 2100, 130, 230, 65, 'moderately_active', NOW(), 'northeastern', 'manual', NOW()),
  ('demo.user03@caloriesguard.local', '$2b$12$H6SPSDLBoNnPdf3CWnC3LO1M0yKH4KqVXTmtHXuBGP7eLz1dwyav6', 'Demo User 03', 2, TRUE, 'female', '1989-11-21', 158, 64, 'lose_weight', 58, 1700, 100, 190, 50, 'sedentary', NOW(), 'northern', 'manual', NOW()),
  ('demo.user04@caloriesguard.local', '$2b$12$H6SPSDLBoNnPdf3CWnC3LO1M0yKH4KqVXTmtHXuBGP7eLz1dwyav6', 'Demo User 04', 2, TRUE, 'male', '1998-05-30', 181, 82, 'gain_muscle', 86, 2600, 160, 300, 75, 'very_active', NOW(), 'southern', 'manual', NOW())
ON CONFLICT (email) DO UPDATE SET
  username = EXCLUDED.username,
  role_id = EXCLUDED.role_id,
  is_email_verified = EXCLUDED.is_email_verified,
  updated_at = NOW();

-- 2) Extra mock beverages. Existing seed has 10 beverage foods; these bring the
-- beverage dimension to 20 rows for admin/web UI testing.
WITH beverage_dishes(dish_name, description) AS (
  VALUES
    ('อเมริกาโน่เย็น (mock)', 'mock_seed_20_rows beverage'),
    ('ลาเต้เย็น (mock)', 'mock_seed_20_rows beverage'),
    ('ชานมไข่มุก (mock)', 'mock_seed_20_rows beverage'),
    ('น้ำมะพร้าว (mock)', 'mock_seed_20_rows beverage'),
    ('น้ำแตงโมปั่น (mock)', 'mock_seed_20_rows beverage'),
    ('น้ำลำไย (mock)', 'mock_seed_20_rows beverage'),
    ('น้ำเก๊กฮวย (mock)', 'mock_seed_20_rows beverage'),
    ('สมูทตี้โยเกิร์ตเบอร์รี่ (mock)', 'mock_seed_20_rows beverage'),
    ('น้ำผึ้งมะนาว (mock)', 'mock_seed_20_rows beverage'),
    ('นมสดเย็น (mock)', 'mock_seed_20_rows beverage')
)
INSERT INTO dishes (dish_name, dish_category_id, canonical_food_type, cuisine, description)
SELECT dish_name, 4, 'beverage', 'Thai', description
FROM beverage_dishes
ON CONFLICT (dish_name, dish_category_id) DO UPDATE SET
  description = EXCLUDED.description,
  updated_at = NOW();

WITH beverage_foods(food_name, calories, protein, carbs, fat, sodium, sugar, serving_quantity, dish_name) AS (
  VALUES
    ('อเมริกาโน่เย็น (mock)', 15, 0, 2, 0, 10, 0, 350, 'อเมริกาโน่เย็น (mock)'),
    ('ลาเต้เย็น (mock)', 180, 7, 24, 6, 90, 18, 350, 'ลาเต้เย็น (mock)'),
    ('ชานมไข่มุก (mock)', 320, 4, 58, 8, 120, 42, 500, 'ชานมไข่มุก (mock)'),
    ('น้ำมะพร้าว (mock)', 90, 1, 22, 0, 35, 18, 350, 'น้ำมะพร้าว (mock)'),
    ('น้ำแตงโมปั่น (mock)', 140, 1, 34, 0, 15, 30, 400, 'น้ำแตงโมปั่น (mock)'),
    ('น้ำลำไย (mock)', 170, 0, 42, 0, 20, 38, 350, 'น้ำลำไย (mock)'),
    ('น้ำเก๊กฮวย (mock)', 110, 0, 28, 0, 10, 25, 350, 'น้ำเก๊กฮวย (mock)'),
    ('สมูทตี้โยเกิร์ตเบอร์รี่ (mock)', 260, 8, 45, 5, 95, 34, 400, 'สมูทตี้โยเกิร์ตเบอร์รี่ (mock)'),
    ('น้ำผึ้งมะนาว (mock)', 130, 0, 33, 0, 10, 30, 350, 'น้ำผึ้งมะนาว (mock)'),
    ('นมสดเย็น (mock)', 210, 9, 24, 8, 115, 22, 350, 'นมสดเย็น (mock)')
)
INSERT INTO foods (
  food_name,
  food_type,
  calories,
  protein,
  carbs,
  fat,
  sodium,
  sugar,
  serving_quantity,
  serving_unit_id,
  dish_id,
  created_at,
  updated_at,
  deleted_at
)
SELECT
  bf.food_name,
  'beverage',
  bf.calories,
  bf.protein,
  bf.carbs,
  bf.fat,
  bf.sodium,
  bf.sugar,
  bf.serving_quantity,
  19,
  d.dish_id,
  NOW(),
  NOW(),
  NULL
FROM beverage_foods bf
JOIN dishes d ON d.dish_name = bf.dish_name AND d.dish_category_id = 4
ON CONFLICT (food_name) DO UPDATE SET
  food_type = EXCLUDED.food_type,
  calories = EXCLUDED.calories,
  protein = EXCLUDED.protein,
  carbs = EXCLUDED.carbs,
  fat = EXCLUDED.fat,
  sodium = EXCLUDED.sodium,
  sugar = EXCLUDED.sugar,
  serving_quantity = EXCLUDED.serving_quantity,
  serving_unit_id = EXCLUDED.serving_unit_id,
  dish_id = EXCLUDED.dish_id,
  deleted_at = NULL,
  updated_at = NOW();

-- 3) Beverage dimension rows.
WITH ranked AS (
  SELECT
    f.food_id,
    ROW_NUMBER() OVER (ORDER BY f.food_id) AS rn
  FROM foods f
  JOIN dishes d ON d.dish_id = f.dish_id
  WHERE d.dish_category_id = 4
    AND f.deleted_at IS NULL
  ORDER BY f.food_id
  LIMIT 20
)
INSERT INTO beverages (
  food_id,
  volume_ml,
  is_alcoholic,
  caffeine_mg,
  sugar_level_label,
  container_type
)
SELECT
  food_id,
  CASE WHEN rn IN (3, 8) THEN 500 ELSE 350 END,
  rn = 8,
  CASE
    WHEN rn IN (1, 2, 4, 5, 11, 12) THEN 80
    WHEN rn IN (6, 13, 19) THEN 25
    ELSE 0
  END,
  CASE
    WHEN rn IN (7, 10, 11, 14) THEN 'low'
    WHEN rn IN (1, 3, 5, 9, 12, 18, 20) THEN 'medium'
    ELSE 'high'
  END,
  CASE WHEN rn IN (8, 15, 16) THEN 'bottle' ELSE 'cup' END
FROM ranked
ON CONFLICT (food_id) DO UPDATE SET
  volume_ml = EXCLUDED.volume_ml,
  is_alcoholic = EXCLUDED.is_alcoholic,
  caffeine_mg = EXCLUDED.caffeine_mg,
  sugar_level_label = EXCLUDED.sugar_level_label,
  container_type = EXCLUDED.container_type;

-- 4) Snack dimension rows.
WITH ranked AS (
  SELECT
    f.food_id,
    ROW_NUMBER() OVER (ORDER BY f.food_id) AS rn
  FROM foods f
  JOIN dishes d ON d.dish_id = f.dish_id
  WHERE d.dish_category_id = 6
    AND f.deleted_at IS NULL
  ORDER BY f.food_id
  LIMIT 20
)
INSERT INTO snacks (food_id, is_sweet, packaging_type, trans_fat)
SELECT
  food_id,
  TRUE,
  CASE
    WHEN rn <= 5 THEN 'fresh'
    WHEN rn <= 12 THEN 'whole_fruit'
    ELSE 'ready_to_eat'
  END,
  CASE WHEN rn <= 3 THEN 0.10 ELSE 0 END
FROM ranked
ON CONFLICT (food_id) DO UPDATE SET
  is_sweet = EXCLUDED.is_sweet,
  packaging_type = EXCLUDED.packaging_type,
  trans_fat = EXCLUDED.trans_fat;

-- 5) Plausible food-allergy flags for testing allergy filters.
WITH pairs(food_name, allergy_name) AS (
  VALUES
    ('ข้าวมันไก่ต้ม', 'ไก่'),
    ('ข้าวมันไก่ทอด', 'ไก่'),
    ('ข้าวขาหมู', 'เนื้อหมู'),
    ('ข้าวหมูแดง', 'เนื้อหมู'),
    ('ข้าวหมูกรอบ', 'เนื้อหมู'),
    ('ผัดไทยกุ้งสด', 'กุ้ง'),
    ('แกงส้มชะอมกุ้ง (ถ้วย)', 'กุ้ง'),
    ('ข้าวผัดผงกระหรี่ทะเล', 'อาหารทะเล'),
    ('ต้มข่าไก่ (ถ้วย)', 'ไก่'),
    ('ต้มข่าไก่ (ถ้วย)', 'กะทิ'),
    ('แกงเขียวหวานไก่ (ราดข้าว)', 'ไก่'),
    ('แกงเขียวหวานไก่ (ราดข้าว)', 'กะทิ'),
    ('ไข่เจียวหมูสับ (ราดข้าว)', 'ไข่'),
    ('ไข่เจียวหมูสับ (ราดข้าว)', 'เนื้อหมู'),
    ('บัวลอยไข่หวาน', 'ไข่'),
    ('บัวลอยไข่หวาน', 'กะทิ'),
    ('ลอดช่องน้ำกะทิ', 'กะทิ'),
    ('ชาไทยเย็น', 'นมวัว'),
    ('โกโก้เย็น', 'นมวัว'),
    ('นมอัลมอนด์', 'ถั่วต้นไม้')
)
INSERT INTO food_allergy_flags (food_id, flag_id)
SELECT f.food_id, af.flag_id
FROM pairs p
JOIN foods f ON f.food_name = p.food_name
JOIN allergy_flags af ON af.name = p.allergy_name
ON CONFLICT (food_id, flag_id) DO NOTHING;

-- 6) User favorites for demo users.
WITH demo_users AS (
  SELECT user_id, ROW_NUMBER() OVER (ORDER BY email) AS user_rn
  FROM users
  WHERE email LIKE 'demo.user%@caloriesguard.local'
),
demo_foods AS (
  SELECT food_id, ROW_NUMBER() OVER (ORDER BY food_id) AS food_rn
  FROM foods
  WHERE deleted_at IS NULL
  ORDER BY food_id
  LIMIT 5
)
INSERT INTO user_favorites (user_id, food_id, created_at)
SELECT du.user_id, df.food_id, NOW() - ((du.user_rn + df.food_rn) || ' hours')::interval
FROM demo_users du
CROSS JOIN demo_foods df
ON CONFLICT (user_id, food_id) DO NOTHING;

-- 7) Recipe favorites. fav_id is GENERATED ALWAYS in Supabase, so let the
-- database allocate it and keep idempotence on (recipe_id, user_id).
WITH rows AS (
  SELECT
    r.recipe_id,
    u.user_id,
    ROW_NUMBER() OVER (ORDER BY u.user_id, r.recipe_id) AS rn
  FROM (
    SELECT recipe_id
    FROM recipes
    WHERE deleted_at IS NULL
    ORDER BY recipe_id
    LIMIT 5
  ) r
  CROSS JOIN (
    SELECT user_id
    FROM users
    WHERE email LIKE 'demo.user%@caloriesguard.local'
    ORDER BY email
  ) u
)
INSERT INTO recipe_favorites (recipe_id, user_id, created_at)
SELECT rows.recipe_id, rows.user_id, NOW() - (rows.rn || ' hours')::interval
FROM rows
ON CONFLICT (recipe_id, user_id) DO NOTHING;

-- 8) Exercise logs for demo timeline charts.
WITH activities(activity_name, duration_minutes, calories_burned, intensity, note, day_offset) AS (
  VALUES
    ('เดินเร็ว', 30, 130, 'low', 'mock_seed_20_rows', 0),
    ('วิ่งเบา', 25, 220, 'moderate', 'mock_seed_20_rows', 1),
    ('ปั่นจักรยาน', 40, 260, 'moderate', 'mock_seed_20_rows', 2),
    ('เวทเทรนนิ่ง', 45, 210, 'moderate', 'mock_seed_20_rows', 3),
    ('โยคะ', 35, 110, 'low', 'mock_seed_20_rows', 4)
),
demo_users AS (
  SELECT user_id, ROW_NUMBER() OVER (ORDER BY email) AS user_rn
  FROM users
  WHERE email LIKE 'demo.user%@caloriesguard.local'
)
INSERT INTO exercise_logs (
  user_id,
  date_record,
  activity_name,
  duration_minutes,
  calories_burned,
  intensity,
  note,
  created_at,
  updated_at
)
SELECT
  du.user_id,
  CURRENT_DATE - (a.day_offset + du.user_rn::int - 1),
  a.activity_name,
  a.duration_minutes,
  a.calories_burned,
  a.intensity,
  a.note,
  NOW() - ((a.day_offset + du.user_rn) || ' days')::interval,
  NOW()
FROM demo_users du
CROSS JOIN activities a
WHERE NOT EXISTS (
  SELECT 1
  FROM exercise_logs el
  WHERE el.user_id = du.user_id
    AND el.date_record = CURRENT_DATE - (a.day_offset + du.user_rn::int - 1)
    AND el.activity_name = a.activity_name
    AND el.note = 'mock_seed_20_rows'
);

-- 9) Meal plans for demo users.
WITH plan_templates(name, description, source_type, is_premium) AS (
  VALUES
    ('แผนคุมแคล 7 วัน', 'mock_seed_20_rows: balanced Thai meals around calorie target', 'SYSTEM', FALSE),
    ('แผนโปรตีนสูง', 'mock_seed_20_rows: higher protein meals for active users', 'SYSTEM', FALSE),
    ('แผนลดน้ำตาล', 'mock_seed_20_rows: lower sugar choices and beverage swaps', 'SYSTEM', FALSE),
    ('แผนอาหารอีสานเบาแคล', 'mock_seed_20_rows: regional Thai food names and lighter choices', 'SYSTEM', TRUE),
    ('แผนกินนอกบ้าน', 'mock_seed_20_rows: street food friendly substitutions', 'SYSTEM', FALSE)
),
demo_users AS (
  SELECT user_id
  FROM users
  WHERE email LIKE 'demo.user%@caloriesguard.local'
  ORDER BY email
)
INSERT INTO user_meal_plans (user_id, name, description, source_type, is_premium, created_at)
SELECT du.user_id, pt.name, pt.description, pt.source_type, pt.is_premium, NOW()
FROM demo_users du
CROSS JOIN plan_templates pt
WHERE NOT EXISTS (
  SELECT 1
  FROM user_meal_plans ump
  WHERE ump.user_id = du.user_id
    AND ump.name = pt.name
    AND ump.description LIKE 'mock_seed_20_rows:%'
);

COMMIT;
