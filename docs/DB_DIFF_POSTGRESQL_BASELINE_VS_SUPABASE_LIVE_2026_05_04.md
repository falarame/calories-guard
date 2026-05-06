# ตรวจสอบความต่างฐานข้อมูล: PostgreSQL baseline vs Supabase live

**วันที่ตรวจ:** 2026-05-04  
**ฐาน live ที่ตรวจ:** Supabase Database schema `cleangoal`  
**ฐานเปรียบเทียบ:** `databaseV4.sql` ใน repo ซึ่งเป็น PostgreSQL baseline/dump เดิม  
**ผลตรวจ connection:** `.env` ปัจจุบันตั้ง `DB_MODE=supabase` และไม่มีชุด local `DB_HOST/DB_NAME/DB_USER/DB_PASSWORD` แยกต่างหาก  
**หมายเหตุ:** `DATABASE_URL` และ `DIRECT_DATABASE_URL` ตรวจแล้วมี schema objects เหมือนกัน จึงถือว่าเป็น Supabase ชุดเดียวกัน

---

## 1. สรุปภาพรวมแบบอ่านง่าย

### 1.1 จำนวน object ในฐานข้อมูล

| สิ่งที่ตรวจ | ฐานเดิม `databaseV4.sql` | Supabase ปัจจุบัน | สรุป |
|---|---:|---:|---|
| ตารางหลัก | 31 | 44 | ตารางเพิ่มขึ้นสุทธิ 13 ตาราง |
| View | 0 | 1 | เพิ่ม view สำหรับหน้า admin |
| Enum | 8 | 9 | เพิ่ม enum สำหรับภาคของไทย |

### 1.2 สิ่งที่เปลี่ยนจริง

| ประเภทการเปลี่ยน | จำนวน | หมายความว่าอะไร |
|---|---:|---|
| ตารางที่เพิ่มเข้ามาใหม่ | 20 | เพิ่มฟีเจอร์ใหม่ เช่น gamification, water log, exercise log, regional food names, admin food review |
| ตารางเดิมที่ถูกตัดออก | 7 | ลบตาราง legacy ที่ไม่ได้ใช้แล้ว หรือย้ายข้อมูลไปอยู่ในตารางใหม่ |
| ตารางเดิมที่เปลี่ยน column | 8 | ตารางยังอยู่ แต่มีการเพิ่ม/ลบ field บางตัว |

### 1.3 แปลเป็นภาษาคน

| เรื่อง | ก่อน | ตอนนี้ |
|---|---|---|
| เป้าหมายผู้ใช้ | แยกบางข้อมูลไว้ใน `user_goals` / `user_activities` | ย้ายมาเก็บใน `users` โดยตรง |
| คำขอเพิ่มอาหาร | ใช้ `food_requests` | ใช้ `temp_food` + `verified_food` และมี view ให้ admin ตรวจ |
| หมวดอาหาร/หน่วยอาหาร | เก็บเป็นข้อความใน `foods` | แยกเป็น `dishes`, `dish_categories`, `units` |
| บันทึกน้ำดื่ม | ไม่มีตาราง live ใน baseline | เพิ่ม `water_logs` |
| บันทึกออกกำลังกาย | ไม่มีตาราง live ใน baseline | เพิ่ม `exercise_logs` |
| ชื่ออาหารตามภาค | ไม่มี | เพิ่ม `food_regional_names` และตาราง review |
| Gamification | ไม่มี | เพิ่ม `user_gamification` |
| ตารางเก่า | ยังมีหลายตาราง legacy | ตัดออกและบางส่วน archive ไว้ |

---

## 2. ตารางที่เพิ่มใน Supabase live

| ตาราง | เหตุผล/ใช้ทำอะไร |
|---|---|
| `dish_categories` | แยกหมวดหมู่อาหารออกจาก string เดิมใน `foods.food_category` เพื่อ normalize taxonomy |
| `dishes` | เก็บตัวเมนู/จานอาหารแบบ normalized แล้วให้ `foods.dish_id` อ้างถึง |
| `exercise_logs` | บันทึกการออกกำลังกายรายวัน |
| `food_allergy_flags` | ตาราง bridge ระหว่างอาหารกับ allergy flags |
| `food_ingredients_archive` | archive ก่อนลบตาราง legacy `food_ingredients` |
| `food_regional_name_submissions` | queue สำหรับผู้ใช้เสนอชื่ออาหารท้องถิ่น รอ admin ตรวจ |
| `food_regional_names` | ชื่ออาหารท้องถิ่นตามภาค เช่น เหนือ/อีสาน/ใต้ |
| `food_regional_popularity` | คะแนนความนิยมของอาหารต่อภาค |
| `food_requests_archive` | archive ก่อนลบตาราง legacy `food_requests` |
| `ingredients_archive` | archive ก่อนลบตาราง legacy `ingredients` |
| `recipe_relation_orphan_archive` | archive row recipe-related ที่ relation พังตอน normalize |
| `recipe_reviews_orphan_archive` | archive review ที่หา recipe matching ไม่เจอ |
| `schema_migrations` | track migration ที่ apply แล้ว |
| `temp_food` | อาหารที่ user/AI ส่งเข้ามา รอ admin verify |
| `unit_conversion_orphan_archive` | archive unit conversion ที่ FK พังตอน normalize |
| `unit_conversions` | ตารางแปลงหน่วย |
| `user_favorites` | ผู้ใช้ favorite food/recipe |
| `user_gamification` | คะแนน Tamagotchi, tier, claimed badges |
| `verified_food` | สถานะการตรวจของ `temp_food` |
| `water_logs` | บันทึกน้ำดื่มรายวัน |

### สรุปกลุ่มที่เพิ่ม

- **Nutrition tracking ใหม่:** `water_logs`, `exercise_logs`
- **Admin moderation ใหม่:** `temp_food`, `verified_food`, `v_admin_temp_food_review`
- **Normalize food catalog:** `dish_categories`, `dishes`, `unit_conversions`
- **Regional food names:** `food_regional_names`, `food_regional_popularity`, `food_regional_name_submissions`
- **Gamification:** `user_gamification`
- **Archive/safety:** `*_archive`, `schema_migrations`

---

## 3. ตารางที่ถูกตัดออกจาก Supabase live

| ตารางที่ไม่มีใน Supabase live แล้ว | แทนที่ด้วย | เหตุผล |
|---|---|---|
| `food_ingredients` | `recipe_ingredients` และ archive `food_ingredients_archive` | ตารางเดิมไม่ได้ถูก router ใช้แล้ว และส่วนประกอบสูตรย้ายไปฝั่ง recipe |
| `food_requests` | `temp_food` + `verified_food` + `v_admin_temp_food_review` | flow เดิมถูกแทนด้วย moderation flow ใหม่ที่ชัดกว่า |
| `ingredients` | archive `ingredients_archive` | เป็นตารางประกอบของ `food_ingredients` เดิม เมื่อ bridge ถูกลบ ตารางนี้ก็ไม่จำเป็น |
| `progress` | `weight_logs` + `daily_summaries` + endpoint progress on-demand | ข้อมูลซ้ำกับ log/summary ที่มีอยู่ |
| `user_activities` | `users.activity_level` | ผู้ใช้มี active activity level เดียว จึง denormalize ลง users |
| `user_goals` | columns ใน `users` เช่น `goal_type`, `target_weight_kg`, `target_calories` | ผู้ใช้มี active goal เดียว ลด JOIN และลด data drift |
| `weekly_summaries` | คำนวณจาก `daily_summaries`/`insights` on-demand | ไม่ต้องเก็บสรุปรายสัปดาห์ซ้ำ |

### ข้อสังเกต

การตัดตารางส่วนใหญ่ไม่ใช่การลบข้อมูลแบบไร้ร่องรอย แต่มี 2 pattern:

1. **แทนด้วย table/flow ใหม่:** เช่น `food_requests` → `temp_food`/`verified_food`
2. **archive ก่อน drop:** เช่น `food_requests_archive`, `food_ingredients_archive`, `ingredients_archive`

---

## 4. View ที่เพิ่ม

| View | ใช้ทำอะไร |
|---|---|
| `v_admin_temp_food_review` | รวม `temp_food` + `verified_food` + `users` เพื่อให้หน้า admin เห็น queue อาหารที่รอตรวจ |

---

## 5. Enum ที่เพิ่ม

| Enum | Values | ใช้กับ |
|---|---|---|
| `thai_region` | `central`, `northern`, `northeastern`, `southern` | `users.region`, `food_regional_names.region`, `food_regional_popularity.region`, `food_regional_name_submissions.region` |

---

## 6. Column ที่เพิ่ม/ตัดในตารางเดิม

### `daily_summaries`

เพิ่ม:

- `total_protein`
- `total_carbs`
- `total_fat`
- `water_glasses`
- `updated_at`

ตัด:

- `item_id`

ความหมาย: daily summary เดิมเก็บแคลอรี่เป็นหลัก ตอนนี้เก็บ macro และน้ำดื่มด้วย ส่วน `item_id` เป็น column legacy ที่ไม่ใช่โครงสร้างที่ใช้งานจริงแล้ว

### `detail_items`

เพิ่ม:

- `protein_per_unit`
- `carbs_per_unit`
- `fat_per_unit`
- `updated_at`

ความหมาย: detail item ตอนนี้ snapshot macro ต่อหน่วยได้ครบ ไม่ใช่แค่ calories เพื่อให้รายงาน macro/insights คำนวณได้

### `foods`

เพิ่ม:

- `dish_id`
- `serving_unit_id`

ตัด:

- `food_category`
- `serving_unit`

ความหมาย: ตัด string legacy แล้วเปลี่ยนเป็น FK ไป `dishes` และ `units` ลดปัญหาชื่อหมวด/หน่วยสะกดไม่ตรงกัน

### `meals`

เพิ่ม:

- `updated_at`

ตัด:

- `item_id`

ความหมาย: เพิ่ม audit timestamp และตัด column legacy ที่ไม่ได้ใช้จริง

### `recipes`

เพิ่ม:

- `generated_by`
- `ingredients_json`
- `tools_json`
- `tips_json`

ตัด:

- `category`
- `cuisine`
- `difficulty`
- `is_published`
- `recipe_name`
- `total_time_minutes`

ความหมาย: recipe ถูกปรับให้รองรับ AI lazy generation โดยเก็บ JSON payload สำหรับ ingredient/tool/tip และใช้ข้อมูลชื่อ/หมวดจาก food/dish layer แทน

### `units`

เพิ่ม:

- `quantity`

ตัด:

- `conversion_factor`

ความหมาย: เปลี่ยนชื่อ/ความหมาย column ให้เป็น quantity ของหน่วยมาตรฐานและรองรับ `unit_conversions` แยกต่างหาก

### `user_meal_plans`

ตัด:

- `item_id`

ความหมาย: column legacy ถูกตัด เหลือ plan header; item จริงอยู่แนวคิด `detail_items.plan_id` แต่ยังเป็น technical debt

### `users`

เพิ่ม:

- `consent_accepted_at`
- `last_tdee_recalc_date`
- `region`
- `region_source`

ความหมาย:

- `consent_accepted_at` รองรับ PDPA/consent
- `last_tdee_recalc_date` ใช้ lifecycle/TDEE recalculation
- `region` และ `region_source` รองรับชื่ออาหารท้องถิ่นตามภาค

---

## 7. Trigger ที่มีใน Supabase live

| Table | Trigger | หน้าที่ |
|---|---|---|
| `daily_summaries` | `trg_daily_summaries_updated_at` | ตั้ง `updated_at` เมื่อ update |
| `detail_items` | `trg_detail_items_updated_at` | ตั้ง `updated_at` เมื่อ update |
| `detail_items` | `trg_sync_daily_summary` | sync calories/macros ไป `daily_summaries` หลัง insert/update/delete |
| `exercise_logs` | `trg_exercise_logs_updated_at` | ตั้ง `updated_at` เมื่อ update |
| `foods` | `trg_foods_sync_detail_items` | sync nutrition cache จาก `foods` ไป `detail_items` |
| `meals` | `trg_meals_updated_at` | ตั้ง `updated_at` เมื่อ update |
| `recipe_favorites` | `trg_update_recipe_favorite_count` | update favorite count ใน `recipes` |
| `recipe_reviews` | `trg_update_recipe_rating` | update rating aggregate ใน `recipes` |
| `temp_food` | `trg_create_verified_food` | สร้าง `verified_food` อัตโนมัติเมื่อมี temp food ใหม่ |
| `temp_food` | `trg_temp_food_touch_updated_at` | ตั้ง `updated_at` |
| `verified_food` | `trg_verified_food_touch_updated_at` | ตั้ง `updated_at`/`verified_at` |
| `water_logs` | `trg_sync_water_to_daily` | sync water glasses ไป `daily_summaries` |

---

## 8. ข้อสรุปชัด ๆ

Supabase live ปัจจุบัน **ไม่ใช่ schema เดียวกับ PostgreSQL baseline `databaseV4.sql` แล้ว** มีการเปลี่ยนหลัก ๆ ดังนี้:

1. **ตัดตาราง legacy ออก 7 ตาราง** โดยเฉพาะ `food_requests`, `ingredients`, `food_ingredients`, `user_goals`, `user_activities`, `progress`, `weekly_summaries`.
2. **เพิ่มตารางใหม่ 20 ตาราง** เพื่อรองรับ moderation, regional food names, gamification, water/exercise tracking, normalized taxonomy และ archive.
3. **อาหารถูก normalize มากขึ้น** จาก string columns (`food_category`, `serving_unit`) ไปเป็น FK (`dish_id`, `serving_unit_id`).
4. **profile/goal ถูก denormalize ลง `users`** แทน `user_goals`/`user_activities`.
5. **daily summary ฉลาดขึ้น** เพราะมี macro + water และมี trigger sync จาก meal/water logs.
6. **AI/Admin workflow ชัดขึ้น** ผ่าน `temp_food`/`verified_food` และ view `v_admin_temp_food_review`.
7. **ระบบชื่ออาหารท้องถิ่นเพิ่มแล้ว** ผ่าน `thai_region` และ `food_regional_*`.
8. **Gamification เพิ่มแล้ว** ผ่าน `user_gamification`.

---

## 9. ไฟล์ผลตรวจดิบ

ผล introspection แบบ JSON อยู่ที่:

`docs/DB_POSTGRESQL_BASELINE_VS_SUPABASE_LIVE_2026_05_04.json`

ไฟล์นี้เก็บเฉพาะ metadata schema ไม่มีรหัสผ่านหรือ connection string
