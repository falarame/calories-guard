# Calories Guard — Schema Diagram (Mermaid)

**Schema:** `cleangoal` บน Supabase Postgres 17
**Generated:** 2026-04-26 (หลัง v24)
**ภาษา:** ไทย

เอกสารนี้แบ่ง schema ออกเป็น 6 diagram ตาม **domain** เพื่อให้อ่านง่าย (ตารางทั้งหมด 30+ ตัว ถ้าวาดในรูปเดียวจะอ่านไม่ออก) แต่ละ diagram มีคำอธิบายลึกของความสัมพันธ์.

หมายเหตุการอ่าน Mermaid ER:
- `||--o{` = 1 → many (mandatory parent, optional children)
- `||--||` = 1 → 1
- `}o--||` = many → 1
- ลูกศรในตารางคือ FK column

## สารบัญ
1. [Identity & Authentication](#1-identity--authentication)
2. [Food Catalog & Taxonomy](#2-food-catalog--taxonomy)
3. [Regional Names (v20)](#3-regional-names-v20)
4. [Recipes & Social](#4-recipes--social)
5. [Meal Logging & Daily Tracking](#5-meal-logging--daily-tracking)
6. [Goals, Activity, Health, Notifications](#6-goals-activity-health-notifications)
7. [Master Diagram (overview)](#7-master-diagram-overview)

---

## 1. Identity & Authentication

```mermaid
erDiagram
    roles ||--o{ users : "role_id"
    users ||--o{ password_reset_codes : "user_id (CASCADE)"
    users ||--o{ email_verification_codes : "user_id (CASCADE)"

    roles {
        SERIAL role_id PK
        VARCHAR role_name UK "admin / user"
    }
    users {
        BIGSERIAL user_id PK
        VARCHAR email UK
        VARCHAR password_hash
        gender_type gender
        DATE birth_date
        DECIMAL height_cm
        DECIMAL current_weight_kg
        goal_type_enum goal_type
        DECIMAL target_weight_kg
        INT target_calories
        INT target_protein
        INT target_carbs
        INT target_fat
        activity_level activity_level
        INT role_id FK
        BOOLEAN is_email_verified
        TIMESTAMPTZ consent_accepted_at
        thai_region region "v20"
        VARCHAR region_source "v20: unset/manual/auto_ip"
        TIMESTAMPTZ created_at
        TIMESTAMPTZ updated_at
        TIMESTAMPTZ deleted_at "soft delete"
    }
    password_reset_codes {
        BIGSERIAL id PK
        BIGINT user_id FK
        VARCHAR code
        TIMESTAMPTZ expires_at
        BOOLEAN used
        TIMESTAMPTZ created_at
    }
    email_verification_codes {
        BIGSERIAL id PK
        BIGINT user_id FK
        VARCHAR code
        TIMESTAMPTZ expires_at
        BOOLEAN used
        TIMESTAMPTZ created_at
    }
```

**คำอธิบาย:**
- `users.role_id` default = 2 (= "user"); admin role_id = 1 ตอน seed
- `users` ใช้ Supabase Auth ผ่าน trigger `public.handle_new_user()` ที่สร้าง row ใน `cleangoal.users` อัตโนมัติเมื่อมีคน sign up ผ่าน auth.users
- `users.deleted_at` = soft delete (PDPA: เก็บ 30 วันก่อนลบจริง). มี partial index `users_deleted_at_idx` กรอง row ที่ marked deleted ได้เร็ว
- `users.region` (v20) เป็น ENUM 4 ภาค ใช้เลือกชื่อท้องถิ่น (ดู §3)
- `users.region_source` ติดตามว่าค่ามาจากไหน — manual = ผู้ใช้เลือกเอง / auto_ip = derive จาก IP / unset = ยังไม่ได้ตั้ง
- `password_reset_codes` และ `email_verification_codes` ทั้งคู่ CASCADE เมื่อ user ถูกลบ

---

## 2. Food Catalog & Taxonomy

```mermaid
erDiagram
    dish_categories ||--o{ dishes : "dish_category_id"
    dishes ||--o{ foods : "dish_id (SET NULL)"
    units ||--o{ foods : "serving_unit_id (SET NULL)"
    units ||--o{ unit_conversions : "from_unit_id (CASCADE)"
    units ||--o{ unit_conversions : "to_unit_id (CASCADE)"
    foods ||--o| beverages : "food_id (UNIQUE, CASCADE)"
    foods ||--o| snacks : "food_id (UNIQUE, CASCADE)"
    foods ||--o{ food_allergy_flags : "food_id (CASCADE)"
    allergy_flags ||--o{ food_allergy_flags : "flag_id (CASCADE)"
    users ||--o{ user_allergy_preferences : "user_id (CASCADE)"
    allergy_flags ||--o{ user_allergy_preferences : "flag_id (CASCADE)"

    dish_categories {
        BIGSERIAL dish_category_id PK
        VARCHAR category_name
        food_type canonical_food_type
        INT display_order
    }
    dishes {
        BIGSERIAL dish_id PK
        VARCHAR dish_name
        BIGINT dish_category_id FK
        food_type canonical_food_type
        VARCHAR cuisine
        TIMESTAMPTZ deleted_at
    }
    units {
        SERIAL unit_id PK
        VARCHAR name UK "lower(name)"
        DECIMAL quantity
    }
    unit_conversions {
        SERIAL conversion_id PK
        INT from_unit_id FK
        INT to_unit_id FK
        DECIMAL factor
    }
    foods {
        BIGSERIAL food_id PK
        VARCHAR food_name "canonical TH"
        food_type food_type
        DECIMAL calories
        DECIMAL protein
        DECIMAL carbs
        DECIMAL fat
        DECIMAL serving_quantity
        INT serving_unit_id FK "v18"
        BIGINT dish_id FK "v18"
        TIMESTAMPTZ deleted_at
    }
    beverages {
        BIGSERIAL beverage_id PK
        BIGINT food_id FK,UK
        DECIMAL volume_ml
        BOOLEAN is_alcoholic
        DECIMAL caffeine_mg
    }
    snacks {
        BIGSERIAL snack_id PK
        BIGINT food_id FK,UK
        BOOLEAN is_sweet
        DECIMAL trans_fat
    }
    allergy_flags {
        SERIAL flag_id PK
        VARCHAR name
        TEXT description
    }
    food_allergy_flags {
        BIGINT food_id PK,FK
        INT flag_id PK,FK
    }
    user_allergy_preferences {
        BIGINT user_id PK,FK
        INT flag_id PK,FK
        VARCHAR preference_type "avoid/warn/prefer"
    }
```

**คำอธิบาย:**
- ลำดับชั้น taxonomy: `dish_categories` (อาหารไทย/ตะวันตก) → `dishes` (เมนู เช่น "ผัดกะเพรา") → `foods` (รายการอาหารจริง). foods 1 row อาจ map กับ dish หรือไม่ก็ได้ (raw_ingredient ไม่ต้องมี dish)
- v18 เพิ่ม `foods.dish_id` และ `foods.serving_unit_id` (FK) แล้ว v21 drop คอลัมน์เก่า `food_category` (VARCHAR) และ `serving_unit` (VARCHAR) — ดู [DB_MIGRATIONS_V20_V24_SUMMARY.md](DB_MIGRATIONS_V20_V24_SUMMARY.md)
- `beverages` และ `snacks` เป็น **subtype** ของ foods แบบ 1:1 (UNIQUE on food_id) — ใช้เก็บข้อมูลเฉพาะของชนิด เช่น `caffeine_mg` มีในเครื่องดื่มเท่านั้น
- `food_allergy_flags` = many-to-many ระหว่าง foods กับ allergy_flags
- `user_allergy_preferences` = many-to-many ระหว่าง users กับ allergy_flags + เก็บ "preference_type" (จะเลี่ยง / ระวัง / ชอบ)
- `unit_conversions` self-reference 2 ครั้ง (from + to) ทำให้แปลงข้ามหน่วยได้ เช่น kg→g (factor=1000)

---

## 3. Regional Names (v20)

```mermaid
erDiagram
    foods ||--o{ food_regional_names : "food_id (CASCADE)"
    foods ||--o{ food_regional_popularity : "food_id (CASCADE)"
    foods ||--o{ food_regional_name_submissions : "food_id (CASCADE)"
    users ||--o{ food_regional_names : "created_by (SET NULL)"
    users ||--o{ food_regional_names : "approved_by (SET NULL)"
    users ||--o{ food_regional_name_submissions : "user_id (CASCADE)"
    users ||--o{ food_regional_name_submissions : "reviewed_by (SET NULL)"

    foods {
        BIGSERIAL food_id PK
        VARCHAR food_name "canonical (Central)"
    }
    food_regional_names {
        BIGSERIAL variant_id PK
        BIGINT food_id FK
        thai_region region "central/northern/northeastern/southern"
        VARCHAR name_th "ชื่อท้องถิ่น"
        BOOLEAN is_primary "1 ต่อ region (partial UQ)"
        BIGINT created_by FK
        BIGINT approved_by FK
        TIMESTAMPTZ deleted_at
    }
    food_regional_popularity {
        BIGINT food_id PK,FK
        thai_region region PK
        SMALLINT popularity "1-5"
        VARCHAR note
    }
    food_regional_name_submissions {
        BIGSERIAL submission_id PK
        BIGINT food_id FK
        thai_region region
        VARCHAR name_th
        SMALLINT popularity
        BIGINT user_id FK "submitter"
        request_status status "pending/approved/rejected"
        BIGINT reviewed_by FK
        TIMESTAMPTZ reviewed_at
    }
```

**คำอธิบาย:**
- `food_regional_names` มี partial UNIQUE index `(food_id, region) WHERE is_primary AND deleted_at IS NULL` — บังคับว่า primary name ต่อ region มีได้แค่ 1 ชื่อ. แต่ alt-name ไม่ใช่ primary มีได้หลายชื่อ
- ค้น index `(region, lower(name_th))` ใช้สำหรับ search "ผู้ใช้พิมพ์ ข้าวปุ้น แล้วต้องเจอ ขนมจีน"
- Flow contribute: user ส่งผ่าน `food_regional_name_submissions` → admin review → ถ้า approve copy ลง `food_regional_names` (mirror pattern เดียวกับ `temp_food` → `verified_food`)
- `food_regional_popularity` แยกออกมาเพราะเป็น single value per (food, region) — ไม่ได้เป็น list เหมือน names
- เมื่อ user ถูกลบ: `created_by`/`approved_by`/`reviewed_by` SET NULL, แต่ `submissions.user_id` CASCADE (data ไม่มีค่าถ้าไม่มีคนเสนอ)

---

## 4. Recipes & Social

```mermaid
erDiagram
    foods ||--|| recipes : "food_id (UNIQUE, CASCADE)"
    recipes ||--o{ recipe_ingredients : "recipe_id (CASCADE)"
    recipes ||--o{ recipe_steps : "recipe_id (CASCADE)"
    recipes ||--o{ recipe_tips : "recipe_id (CASCADE)"
    recipes ||--o{ recipe_tools : "recipe_id (CASCADE)"
    recipes ||--o{ recipe_reviews : "recipe_id (CASCADE)"
    recipes ||--o{ recipe_favorites : "recipe_id (CASCADE)"
    units ||--o{ recipe_ingredients : "unit_id (SET NULL)"
    users ||--o{ recipe_reviews : "user_id (CASCADE)"
    users ||--o{ recipe_favorites : "user_id (CASCADE)"
    users ||--o{ user_favorites : "user_id (CASCADE)"
    foods ||--o{ user_favorites : "food_id (CASCADE)"

    recipes {
        BIGSERIAL recipe_id PK
        BIGINT food_id FK,UK
        TEXT instructions
        INT prep_time_minutes
        INT cooking_time_minutes
        DECIMAL serving_people
        JSONB ingredients_json "v16_a AI"
        JSONB tools_json "v16_a AI"
        JSONB tips_json "v16_a AI"
        VARCHAR generated_by "seed/gpt-4/..."
        INT favorite_count "denorm"
        TIMESTAMPTZ deleted_at
    }
    recipe_ingredients {
        BIGSERIAL ing_id PK
        BIGINT recipe_id FK
        VARCHAR ingredient_name
        DECIMAL amount
        INT unit_id FK
    }
    recipe_steps {
        BIGSERIAL step_id PK
        BIGINT recipe_id FK
        INT step_number
        TEXT instruction
    }
    recipe_tips {
        BIGSERIAL tip_id PK
        BIGINT recipe_id FK
        TEXT tip_text
    }
    recipe_tools {
        BIGSERIAL tool_id PK
        BIGINT recipe_id FK
        VARCHAR tool_name
    }
    recipe_reviews {
        BIGSERIAL review_id PK
        BIGINT recipe_id FK
        BIGINT user_id FK
        SMALLINT rating "1-5"
        TEXT comment
    }
    recipe_favorites {
        BIGSERIAL fav_id PK
        BIGINT recipe_id FK
        BIGINT user_id FK
    }
    user_favorites {
        BIGSERIAL favorite_id PK
        BIGINT user_id FK
        BIGINT food_id FK
    }
```

**คำอธิบาย:**
- `recipes` 1:1 กับ `foods` — สูตรหนึ่งสูตรผูกกับอาหาร 1 รายการเสมอ. ถ้าอยากเก็บ "ส้มตำไก่ทอด" เป็นสูตรใหม่ต้องสร้าง food row ใหม่ก่อน
- 4 ตารางย่อย (`recipe_ingredients/steps/tips/tools`) เก็บ structured detail. นอกจากนี้ `recipes` ก็เก็บ `*_json` ที่ AI generate ออกมาด้วย (v16_a) — สำหรับสูตรที่ admin ยังไม่ได้ migrate ลงตารางย่อย
- มี **2 ตาราง favorite ที่ทับซ้อนกัน**: `recipe_favorites` (legacy) และ `user_favorites` (active mobile API). v17 comment ระบุว่ามือถือใช้ `user_favorites(food_id)` แทน
- `recipes.favorite_count` denormalize — sync ด้วย trigger `update_recipe_favorite_count()` เมื่อ `recipe_favorites` insert/delete
- `recipe_reviews` มี trigger `update_recipe_rating()` aggregate rating หลัง insert/update/delete

---

## 5. Meal Logging & Daily Tracking

```mermaid
erDiagram
    users ||--o{ meals : "user_id (CASCADE)"
    users ||--o{ daily_summaries : "user_id (CASCADE)"
    users ||--o{ user_meal_plans : "user_id (SET NULL)"
    meals ||--o{ detail_items : "meal_id (CASCADE)"
    daily_summaries ||--o{ detail_items : "summary_id (CASCADE)"
    user_meal_plans ||--o{ detail_items : "plan_id (CASCADE)"
    foods ||--o{ detail_items : "food_id (SET NULL)"
    units ||--o{ detail_items : "unit_id (SET NULL)"

    meals {
        BIGSERIAL meal_id PK
        BIGINT user_id FK
        meal_type meal_type "breakfast/lunch/dinner/snack"
        TIMESTAMPTZ meal_time
        TIMESTAMPTZ created_at
        TIMESTAMPTZ updated_at "v24"
    }
    detail_items {
        BIGSERIAL item_id PK
        BIGINT meal_id FK "EXCLUSIVE"
        BIGINT plan_id FK "EXCLUSIVE"
        BIGINT summary_id FK "EXCLUSIVE"
        BIGINT food_id FK
        VARCHAR food_name "snapshot"
        DECIMAL amount
        INT unit_id FK "v19"
        DECIMAL cal_per_unit "snapshot"
        DECIMAL protein_per_unit
        DECIMAL carbs_per_unit
        DECIMAL fat_per_unit
        TIMESTAMPTZ updated_at "v24"
    }
    daily_summaries {
        BIGSERIAL summary_id PK
        BIGINT user_id FK
        DATE date_record UK
        DECIMAL total_calories_intake
        INT goal_calories
        BOOLEAN is_goal_met
        NUMERIC total_protein
        NUMERIC total_carbs
        NUMERIC total_fat
        INTEGER water_glasses
        TIMESTAMPTZ updated_at "v24"
    }
    user_meal_plans {
        BIGSERIAL plan_id PK
        BIGINT user_id FK
        VARCHAR name
        VARCHAR source_type "SYSTEM/USER_CREATED/AI_GENERATED"
        BOOLEAN is_premium
    }
```

**คำอธิบาย:**
- ⚠ `detail_items` เป็น **polymorphic** — มี FK 3 ตัว (`meal_id`, `plan_id`, `summary_id`) ที่ exclusive (CHECK บังคับให้ไม่ NULL แค่ 1 ตัว) → 2NF violation. **Phase 4** จะแยกเป็น 3 ตาราง (deferred)
- `daily_summaries` มี UNIQUE `(user_id, date_record)` — 1 row ต่อ (user, day)
- ⛓ Trigger chain ที่ sync `daily_summaries`:
  1. user log อาหาร → row ใน `meals` + `detail_items(meal_id=...)`
  2. `trg_sync_daily_summary` (AFTER INSERT/UPDATE/DELETE บน detail_items) เรียก `fn_sync_daily_summary()` → recompute `total_calories_intake/protein/carbs/fat`
  3. `trg_sync_water_to_daily` (บน water_logs) sync `water_glasses` ใน `daily_summaries`
  4. v24 trigger `trg_foods_sync_detail_items` (บน foods AFTER UPDATE) → ถ้าค่า nutrition ใน foods เปลี่ยน push ลง `detail_items.cal_per_unit` ทุกแถวที่ food_id ตรงกัน
- `detail_items.food_name`/`cal_per_unit`/etc. เป็น **snapshot/cache** — เก็บค่าตอน log เผื่อ admin แก้ foods ภายหลัง (พร้อม trigger sync)

---

## 6. Goals, Activity, Health, Notifications

```mermaid
erDiagram
    users ||--o{ water_logs : "user_id (CASCADE)"
    users ||--o{ weight_logs : "user_id (CASCADE)"
    users ||--o{ exercise_logs : "user_id (CASCADE)"
    users ||--o{ notifications : "user_id (CASCADE)"
    users ||--o{ temp_food : "user_id (CASCADE)"
    users ||--o{ verified_food : "verified_by (SET NULL)"
    temp_food ||--|| verified_food : "tf_id (UNIQUE, CASCADE)"

    water_logs {
        BIGSERIAL log_id PK
        BIGINT user_id FK
        DATE date_record UK
        INTEGER glasses "0-30"
        TIMESTAMPTZ updated_at
    }
    weight_logs {
        BIGSERIAL log_id PK
        BIGINT user_id FK
        DECIMAL weight_kg "20-300"
        DATE recorded_date UK
    }
    exercise_logs {
        BIGSERIAL log_id PK
        BIGINT user_id FK
        DATE date_record
        VARCHAR activity_name
        INT duration_minutes "0-1440"
        DECIMAL calories_burned
        VARCHAR intensity "low/moderate/high"
        TIMESTAMPTZ updated_at "v24"
    }
    notifications {
        BIGSERIAL notification_id PK
        BIGINT user_id FK
        VARCHAR title
        TEXT message
        notification_type type
        BOOLEAN is_read
    }
    health_contents {
        BIGSERIAL content_id PK
        VARCHAR title
        content_type type "article/video"
        VARCHAR thumbnail_url
        VARCHAR resource_url
        VARCHAR category_tag
        BOOLEAN is_published
    }
    temp_food {
        BIGSERIAL tf_id PK
        VARCHAR food_name
        DECIMAL protein
        DECIMAL fat
        DECIMAL carbs
        DECIMAL calories
        BIGINT user_id FK
    }
    verified_food {
        BIGSERIAL vf_id PK
        BIGINT tf_id FK,UK
        BOOLEAN is_verify
        BIGINT verified_by FK
        TIMESTAMPTZ verified_at
    }
```

**คำอธิบาย:**
- `water_logs` UNIQUE `(user_id, date_record)` → 1 row ต่อวัน, `glasses` cap ที่ 30 (≈7.5 ลิตร)
- `weight_logs` UNIQUE ต่อวัน → ถ้าชั่งซ้ำต้อง UPDATE row เดิม
- `exercise_logs` ไม่ unique ต่อวัน — log ได้หลายครั้งต่อวัน (เช้า + เย็น)
- `temp_food` + `verified_food` เป็นคู่กัน 1:1: user เพิ่มอาหารใหม่ → trigger `trg_create_verified_food` (AFTER INSERT) สร้าง verified_food row อัตโนมัติด้วย `is_verify=false` → admin verify → trigger `trg_verified_food_touch_updated_at` ตั้ง `verified_at`
- `notifications.type` มี 4 ชนิด — system_alert / achievement / content_update / system_announcement
- `health_contents` ไม่ผูกกับ user — เป็น public content

---

## 7. Master Diagram (overview)

```mermaid
erDiagram
    users ||--o{ meals : ""
    users ||--o{ daily_summaries : ""
    users ||--o{ water_logs : ""
    users ||--o{ weight_logs : ""
    users ||--o{ exercise_logs : ""
    users ||--o{ notifications : ""
    users ||--o{ user_allergy_preferences : ""
    users ||--o{ user_favorites : ""
    users ||--o{ recipe_reviews : ""
    users ||--o{ temp_food : ""
    users ||--o{ user_meal_plans : ""
    users ||--o{ food_regional_name_submissions : ""
    roles ||--o{ users : ""

    dish_categories ||--o{ dishes : ""
    dishes ||--o{ foods : ""
    units ||--o{ foods : ""
    foods ||--|| recipes : ""
    foods ||--o| beverages : ""
    foods ||--o| snacks : ""
    foods ||--o{ food_allergy_flags : ""
    foods ||--o{ food_regional_names : ""
    foods ||--o{ food_regional_popularity : ""
    foods ||--o{ user_favorites : ""
    foods ||--o{ detail_items : ""
    allergy_flags ||--o{ food_allergy_flags : ""
    allergy_flags ||--o{ user_allergy_preferences : ""

    recipes ||--o{ recipe_ingredients : ""
    recipes ||--o{ recipe_steps : ""
    recipes ||--o{ recipe_tips : ""
    recipes ||--o{ recipe_tools : ""
    recipes ||--o{ recipe_reviews : ""
    recipes ||--o{ recipe_favorites : ""

    meals ||--o{ detail_items : ""
    daily_summaries ||--o{ detail_items : ""
    user_meal_plans ||--o{ detail_items : ""

    temp_food ||--|| verified_food : ""
```

**ภาพรวม:**
- `users` เป็น hub กลาง — ทุก user-owned table CASCADE จาก users
- `foods` เป็น hub ของฝั่งโภชนาการ — recipes, beverages, snacks, regional names, allergens, favorites, detail_items ทุกอันชี้กลับมา
- 3 polymorphic links จาก `detail_items` → meals/plans/summaries (Phase 4 จะแยก)

---

## หมายเหตุเรื่อง Soft Delete

ตารางที่มี `deleted_at`:
- `users` — PDPA 30-day retention
- `foods` — เก็บประวัติ (detail_items ที่อ้างอยู่ก็ยังเห็นชื่อ)
- `dishes` — โต๊ะ admin
- `recipes` — เก็บประวัติ
- `food_regional_names` — undo การ approve

ตารางที่ **ไม่มี** `deleted_at` (hard delete หรือไม่จำเป็น): `meals`, `detail_items`, `daily_summaries`, `water/weight/exercise_logs`, `notifications`, ฯลฯ — ลบจริงเมื่อไม่ต้องการแล้ว

---

## หมายเหตุเรื่อง Audit Columns

หลัง v24 ทุกตารางที่ผู้ใช้แก้ไขบ่อยมี `created_at` + `updated_at` ครบ:

| Table | created_at | updated_at | trigger |
|---|---|---|---|
| users | ✓ | ✓ | (manual update) |
| meals | ✓ | ✓ (v24) | trg_meals_updated_at |
| detail_items | ✓ | ✓ (v24) | trg_detail_items_updated_at |
| daily_summaries | ✓ | ✓ (v24) | trg_daily_summaries_updated_at |
| exercise_logs | ✓ | ✓ (v24) | trg_exercise_logs_updated_at |
| foods | ✓ | ✓ | (manual + trg_foods_sync_detail_items) |
| dishes | ✓ | ✓ | — |

---

**END OF SCHEMA DIAGRAM**
