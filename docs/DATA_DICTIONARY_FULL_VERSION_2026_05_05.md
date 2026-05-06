# Data Dictionary Full Version - Calories Guard

- Generated at: 2026-05-05 11:34:30 +0700 (Asia/Bangkok)
- Source: live Supabase/PostgreSQL schema `cleangoal`
- Latest migration context: `backend/migrations/v26_food_versioning_and_log_snapshots.sql`
- Scope: 48 base tables, 4 views, 65 foreign keys, 9 enums

## Summary

| Metric | Value |
|---|---:|
| Base tables | 48 |
| Views | 4 |
| Columns | 478 |
| Foreign keys | 65 |
| Enums | 9 |

## Enums

| Enum | Values |
|---|---|
| `activity_level` | sedentary, lightly_active, moderately_active, very_active |
| `content_type` | article, video |
| `food_type` | raw_ingredient, recipe_dish, dish, beverage, snack |
| `gender_type` | male, female |
| `goal_type_enum` | lose_weight, maintain_weight, gain_muscle |
| `meal_type` | breakfast, lunch, dinner, snack |
| `notification_type` | system_alert, achievement, content_update, system_announcement |
| `request_status` | pending, approved, rejected |
| `thai_region` | central, northern, northeastern, southern |

## Table Index

| Domain | Table | Type | Rows now | RLS | Primary key | Description |
|---|---|---|---:|---|---|---|
| Identity & Access | `email_verification_codes` | BASE TABLE | 8 | yes | id | Email verification code/token records for user onboarding. |
| Identity & Access | `password_reset_codes` | BASE TABLE | 0 | yes | id | Password reset code/token records with expiry and usage state. |
| Identity & Access | `roles` | BASE TABLE | 2 | yes | role_id | User authorization roles such as admin and user. |
| Identity & Access | `users` | BASE TABLE | 45 | yes | user_id | User accounts, profile data, health targets, macro targets, consent, and regional preferences. |
| Food Catalog & Nutrition Master | `allergy_flags` | BASE TABLE | 20 | yes | flag_id | Master data for allergens or dietary warning flags. |
| Food Catalog & Nutrition Master | `beverages` | BASE TABLE | 20 | yes | beverage_id | Subtype details for beverage foods. |
| Food Catalog & Nutrition Master | `dish_categories` | BASE TABLE | 6 | yes | dish_category_id | Normalized dish category master data. |
| Food Catalog & Nutrition Master | `dishes` | BASE TABLE | 115 | yes | dish_id | Normalized dish entity connected to foods and recipes. |
| Food Catalog & Nutrition Master | `food_allergy_flags` | BASE TABLE | 20 | yes | food_id, flag_id | Maps which allergens are present in each food. Used to filter foods based on user allergy preferences. |
| Food Catalog & Nutrition Master | `food_ingredients` | BASE TABLE | 19 | yes | food_ing_id | Bridge table describing which normalized ingredients compose each food/menu item. |
| Food Catalog & Nutrition Master | `food_versions` | BASE TABLE | 113 | yes | food_version_id | Immutable version history for mutable food catalogue rows. User logs should point to the version used when recorded. |
| Food Catalog & Nutrition Master | `foods` | BASE TABLE | 113 | yes | food_id | Mutable food catalogue row used by the app for selectable foods and drinks. |
| Food Catalog & Nutrition Master | `ingredient_unit_conversions` | BASE TABLE | 0 | yes | ingredient_unit_conversion_id | Ingredient-specific household-unit conversions, e.g. piece to gram where generic unit conversion is not enough. |
| Food Catalog & Nutrition Master | `ingredients` | BASE TABLE | 21 | yes | ingredient_id | Strong entity for normalized ingredient/raw material catalog and nutrition reference values. |
| Food Catalog & Nutrition Master | `snacks` | BASE TABLE | 20 | yes | snack_id | Subtype details for snack foods. |
| Food Catalog & Nutrition Master | `unit_conversions` | BASE TABLE | 5 | yes | conversion_id | Generic unit conversion table between units. |
| Food Catalog & Nutrition Master | `units` | BASE TABLE | 16 | yes | unit_id | Master data for units such as gram, milliliter, serving, spoon, and piece. |
| Recipes | `recipe_favorites` | BASE TABLE | 20 | yes | fav_id | Legacy recipe-specific favorites. Active mobile API uses user_favorites(food_id). |
| Recipes | `recipe_ingredients` | BASE TABLE | 54 | yes | ing_id | Recipe ingredient rows connected to recipes, food ingredients, normalized ingredients, and units. |
| Recipes | `recipe_reviews` | BASE TABLE | 0 | yes | review_id | Recipe ratings and comments from users. |
| Recipes | `recipe_steps` | BASE TABLE | 196 | yes | step_id | Ordered preparation steps for recipes. |
| Recipes | `recipe_tips` | BASE TABLE | 10 | yes | tip_id | Recipe tips or cooking notes. |
| Recipes | `recipe_tools` | BASE TABLE | 12 | yes | tool_id | Cooking tools or equipment used by recipes. |
| Recipes | `recipes` | BASE TABLE | 66 | yes | recipe_id | Recipe header/details for a food, with AI/manual source and JSON fallback fields. |
| Logging & Summaries | `daily_summaries` | BASE TABLE | 20 | yes | summary_id | Daily user nutrition, water, and goal summary data. |
| Logging & Summaries | `detail_items` | BASE TABLE | 45 | yes | item_id | Historical meal-log item snapshots. Do not overwrite from foods after insert. |
| Logging & Summaries | `exercise_logs` | BASE TABLE | 20 | yes | log_id | บันทึกการออกกำลังกายรายวันของผู้ใช้ |
| Logging & Summaries | `meals` | BASE TABLE | 39 | yes | meal_id | User meal headers by date and meal type. |
| Logging & Summaries | `water_logs` | BASE TABLE | 10 | yes | log_id | บันทึกจำนวนแก้วน้ำที่ดื่มต่อวัน |
| Logging & Summaries | `weight_logs` | BASE TABLE | 33 | yes | log_id | User body weight and body metric logs. |
| Goals & Personalization | `user_allergy_preferences` | BASE TABLE | 28 | yes | user_id, flag_id | User-selected allergy flags used to filter or warn on foods. |
| Goals & Personalization | `user_meal_plans` | BASE TABLE | 20 | yes | plan_id | Planned meals for users. |
| Moderation & Regionalization | `food_regional_name_submissions` | BASE TABLE | 0 | yes | submission_id | User-submitted regional name suggestions awaiting admin review |
| Moderation & Regionalization | `food_regional_names` | BASE TABLE | 10 | yes | variant_id | Alternative Thai names for foods per region (dialect / regional naming) |
| Moderation & Regionalization | `food_regional_popularity` | BASE TABLE | 7 | yes | food_id, region | How common a food is in each region (1=rare, 5=ubiquitous) |
| Moderation & Regionalization | `temp_food` | BASE TABLE | 9 | yes | tf_id | เมนูอาหารที่ user บันทึกด่วน รอ admin ตรวจสอบ |
| Moderation & Regionalization | `verified_food` | BASE TABLE | 9 | yes | vf_id | สถานะการตรวจสอบเมนูที่ user เพิ่มเข้ามาใน temp_food |
| Content & Notifications | `health_contents` | BASE TABLE | 20 | yes | content_id | Health articles and videos shown in the app. |
| Content & Notifications | `notifications` | BASE TABLE | 22 | yes | notification_id | System alerts, achievements, content updates, and announcements. |
| Content & Notifications | `user_favorites` | BASE TABLE | 20 | yes | id | User favorite food mapping. |
| Gamification | `user_gamification` | BASE TABLE | 11 | yes | user_id | User gamification state such as points, levels, streaks, badges, and pet/status progression. |
| Migration / Archive / Audit Support | `food_ingredients_archive` | BASE TABLE | 0 | no |  | Archive of food ingredient data before restoration/normalization. |
| Migration / Archive / Audit Support | `food_requests_archive` | BASE TABLE | 0 | no |  | Archive of legacy food request data. |
| Migration / Archive / Audit Support | `ingredients_archive` | BASE TABLE | 0 | no |  | Archive of ingredient data before restoration/normalization. |
| Migration / Archive / Audit Support | `recipe_relation_orphan_archive` | BASE TABLE | 100 | yes | archive_id | Migration archive for orphaned recipe relation rows. |
| Migration / Archive / Audit Support | `recipe_reviews_orphan_archive` | BASE TABLE | 20 | yes | archive_id | Migration archive for orphaned recipe reviews. |
| Migration / Archive / Audit Support | `schema_migrations` | BASE TABLE | 28 | yes | version | Applied migration ledger for the cleangoal schema. |
| Migration / Archive / Audit Support | `unit_conversion_orphan_archive` | BASE TABLE | 19 | yes | archive_id | Migration archive for orphaned unit conversion rows. |
| Other / Extension | `v_admin_temp_food_review` | VIEW |  | no |  | Admin review view combining temp food and reviewer/user data. |
| Other / Extension | `v_food_ingredient_nutrition_totals` | VIEW |  | no |  | View that totals nutrition from food ingredient composition. |
| Other / Extension | `v_food_recipes` | VIEW |  | no |  | Read model exposing the logical food_recipe relationship. Current physical schema is recipes.food_id because each food has at most one active recipe. |
| Other / Extension | `v_recipe_ingredients_nutrition` | VIEW |  | no |  | View that calculates recipe ingredient nutrition from quantities and units. |

## Identity & Access

### `email_verification_codes`

- Type: BASE TABLE
- Current rows: 8
- RLS enabled: yes
- Description: Email verification code/token records for user onboarding.
- Primary key: `id`
- Foreign keys: `user_id` -> `users.user_id` (CASCADE)

| Column | Type | Nullable | Default | Key | References | Description |
|---|---|---|---|---|---|---|
| `id` | bigint | NO | nextval('email_verification_codes_id_seq'::regclass) | PK |  |  |
| `user_id` | bigint | NO |  | FK | `users.user_id` |  |
| `code` | character varying(10) | NO |  |  |  |  |
| `expires_at` | timestamp with time zone | NO |  |  |  |  |
| `used` | boolean | YES | false |  |  |  |
| `created_at` | timestamp with time zone | YES | now() |  |  |  |

Indexes:

| Index | Definition |
|---|---|
| `email_verification_codes_pkey` | `CREATE UNIQUE INDEX email_verification_codes_pkey ON cleangoal.email_verification_codes USING btree (id)` |

### `password_reset_codes`

- Type: BASE TABLE
- Current rows: 0
- RLS enabled: yes
- Description: Password reset code/token records with expiry and usage state.
- Primary key: `id`
- Foreign keys: `user_id` -> `users.user_id` (CASCADE)

| Column | Type | Nullable | Default | Key | References | Description |
|---|---|---|---|---|---|---|
| `id` | bigint | NO | nextval('password_reset_codes_id_seq'::regclass) | PK |  |  |
| `user_id` | bigint | NO |  | FK | `users.user_id` |  |
| `code` | character varying(10) | NO |  |  |  |  |
| `expires_at` | timestamp with time zone | NO |  |  |  |  |
| `used` | boolean | YES | false |  |  |  |
| `created_at` | timestamp with time zone | YES | now() |  |  |  |

Indexes:

| Index | Definition |
|---|---|
| `password_reset_codes_pkey` | `CREATE UNIQUE INDEX password_reset_codes_pkey ON cleangoal.password_reset_codes USING btree (id)` |

### `roles`

- Type: BASE TABLE
- Current rows: 2
- RLS enabled: yes
- Description: User authorization roles such as admin and user.
- Primary key: `role_id`
- Unique constraints: `roles_role_name_key` (role_name)

| Column | Type | Nullable | Default | Key | References | Description |
|---|---|---|---|---|---|---|
| `role_id` | integer | NO | nextval('roles_role_id_seq'::regclass) | PK |  |  |
| `role_name` | character varying(30) | NO |  | UK |  |  |

Indexes:

| Index | Definition |
|---|---|
| `roles_pkey` | `CREATE UNIQUE INDEX roles_pkey ON cleangoal.roles USING btree (role_id)` |
| `roles_role_name_key` | `CREATE UNIQUE INDEX roles_role_name_key ON cleangoal.roles USING btree (role_name)` |

### `users`

- Type: BASE TABLE
- Current rows: 45
- RLS enabled: yes
- Description: User accounts, profile data, health targets, macro targets, consent, and regional preferences.
- Primary key: `user_id`
- Unique constraints: `users_email_key` (email)
- Foreign keys: `role_id` -> `roles.role_id` (NO ACTION)

| Column | Type | Nullable | Default | Key | References | Description |
|---|---|---|---|---|---|---|
| `user_id` | bigint | NO | nextval('users_user_id_seq'::regclass) | PK |  |  |
| `username` | character varying(50) | YES |  |  |  |  |
| `email` | character varying(255) | NO |  | UK |  |  |
| `password_hash` | character varying(255) | NO |  |  |  |  |
| `gender` | gender_type | YES |  |  |  |  |
| `birth_date` | date | YES |  |  |  |  |
| `height_cm` | numeric(5,2) | YES |  |  |  |  |
| `current_weight_kg` | numeric(5,2) | YES |  |  |  |  |
| `goal_type` | goal_type_enum | YES |  |  |  |  |
| `target_weight_kg` | numeric(5,2) | YES |  |  |  |  |
| `target_calories` | integer | YES |  |  |  |  |
| `target_protein` | integer | YES |  |  |  | เป้าหมายโปรตีน (กรัม/วัน) |
| `target_carbs` | integer | YES |  |  |  | เป้าหมายคาร์บ (กรัม/วัน) |
| `target_fat` | integer | YES |  |  |  | เป้าหมายไขมัน (กรัม/วัน) |
| `activity_level` | activity_level | YES |  |  |  |  |
| `goal_start_date` | date | YES | CURRENT_DATE |  |  |  |
| `goal_target_date` | date | YES |  |  |  |  |
| `last_kpi_check_date` | date | YES | CURRENT_DATE |  |  |  |
| `current_streak` | integer | YES | 0 |  |  |  |
| `last_login_date` | timestamp with time zone | YES |  |  |  |  |
| `total_login_days` | integer | YES | 0 |  |  |  |
| `avatar_url` | character varying(500) | YES |  |  |  |  |
| `role_id` | integer | YES | 2 | FK | `roles.role_id` |  |
| `is_email_verified` | boolean | YES | false |  |  |  |
| `consent_accepted_at` | timestamp with time zone | YES |  |  |  | เวลาที่ user ยอมรับ data consent (NULL = ยังไม่ยอมรับ) |
| `created_at` | timestamp with time zone | YES | now() |  |  |  |
| `updated_at` | timestamp with time zone | YES |  |  |  |  |
| `deleted_at` | timestamp with time zone | YES |  |  |  |  |
| `last_tdee_recalc_date` | date | YES |  |  |  |  |
| `region` | thai_region | YES |  |  |  | Preferred Thai region for food name display (NULL = use canonical Central name) |
| `region_source` | character varying(20) | NO | 'unset'::character varying |  |  | How region was set: unset\|manual\|auto_ip |

Indexes:

| Index | Definition |
|---|---|
| `idx_users_email` | `CREATE INDEX idx_users_email ON cleangoal.users USING btree (email) WHERE (deleted_at IS NULL)` |
| `idx_users_region` | `CREATE INDEX idx_users_region ON cleangoal.users USING btree (region) WHERE ((region IS NOT NULL) AND (deleted_at IS NULL))` |
| `users_deleted_at_idx` | `CREATE INDEX users_deleted_at_idx ON cleangoal.users USING btree (deleted_at) WHERE (deleted_at IS NOT NULL)` |
| `users_email_key` | `CREATE UNIQUE INDEX users_email_key ON cleangoal.users USING btree (email)` |
| `users_pkey` | `CREATE UNIQUE INDEX users_pkey ON cleangoal.users USING btree (user_id)` |

## Food Catalog & Nutrition Master

### `allergy_flags`

- Type: BASE TABLE
- Current rows: 20
- RLS enabled: yes
- Description: Master data for allergens or dietary warning flags.
- Primary key: `flag_id`

| Column | Type | Nullable | Default | Key | References | Description |
|---|---|---|---|---|---|---|
| `flag_id` | integer | NO | nextval('allergy_flags_flag_id_seq'::regclass) | PK |  |  |
| `name` | character varying | NO |  |  |  |  |
| `description` | character varying | YES |  |  |  |  |

Indexes:

| Index | Definition |
|---|---|
| `allergy_flags_pkey` | `CREATE UNIQUE INDEX allergy_flags_pkey ON cleangoal.allergy_flags USING btree (flag_id)` |

### `beverages`

- Type: BASE TABLE
- Current rows: 20
- RLS enabled: yes
- Description: Subtype details for beverage foods.
- Primary key: `beverage_id`
- Unique constraints: `beverages_food_id_key` (food_id)
- Foreign keys: `food_id` -> `foods.food_id` (NO ACTION)

| Column | Type | Nullable | Default | Key | References | Description |
|---|---|---|---|---|---|---|
| `beverage_id` | bigint | NO | nextval('beverages_beverage_id_seq'::regclass) | PK |  |  |
| `food_id` | bigint | YES |  | FK, UK | `foods.food_id` |  |
| `volume_ml` | numeric(6,2) | YES |  |  |  |  |
| `is_alcoholic` | boolean | YES | false |  |  |  |
| `caffeine_mg` | numeric(6,2) | YES | 0 |  |  |  |
| `sugar_level_label` | character varying | YES |  |  |  |  |
| `container_type` | character varying | YES |  |  |  |  |

Indexes:

| Index | Definition |
|---|---|
| `beverages_food_id_key` | `CREATE UNIQUE INDEX beverages_food_id_key ON cleangoal.beverages USING btree (food_id)` |
| `beverages_pkey` | `CREATE UNIQUE INDEX beverages_pkey ON cleangoal.beverages USING btree (beverage_id)` |

### `dish_categories`

- Type: BASE TABLE
- Current rows: 6
- RLS enabled: yes
- Description: Normalized dish category master data.
- Primary key: `dish_category_id`
- Unique constraints: `dish_categories_category_name_canonical_food_type_key` (category_name, canonical_food_type)

| Column | Type | Nullable | Default | Key | References | Description |
|---|---|---|---|---|---|---|
| `dish_category_id` | bigint | NO | nextval('dish_categories_dish_category_id_seq'::regclass) | PK |  |  |
| `category_name` | character varying(120) | NO |  |  |  |  |
| `canonical_food_type` | food_type | YES |  |  |  |  |
| `description` | text | YES |  |  |  |  |
| `display_order` | integer | NO | 0 |  |  |  |
| `created_at` | timestamp with time zone | NO | now() |  |  |  |

Indexes:

| Index | Definition |
|---|---|
| `dish_categories_category_name_canonical_food_type_key` | `CREATE UNIQUE INDEX dish_categories_category_name_canonical_food_type_key ON cleangoal.dish_categories USING btree (category_name, canonical_food_type)` |
| `dish_categories_pkey` | `CREATE UNIQUE INDEX dish_categories_pkey ON cleangoal.dish_categories USING btree (dish_category_id)` |

### `dishes`

- Type: BASE TABLE
- Current rows: 115
- RLS enabled: yes
- Description: Normalized dish entity connected to foods and recipes.
- Primary key: `dish_id`
- Unique constraints: `dishes_dish_name_dish_category_id_key` (dish_name, dish_category_id)
- Foreign keys: `dish_category_id` -> `dish_categories.dish_category_id` (RESTRICT)

| Column | Type | Nullable | Default | Key | References | Description |
|---|---|---|---|---|---|---|
| `dish_id` | bigint | NO | nextval('dishes_dish_id_seq'::regclass) | PK |  |  |
| `dish_name` | character varying(200) | NO |  |  |  |  |
| `dish_category_id` | bigint | NO |  | FK | `dish_categories.dish_category_id` |  |
| `canonical_food_type` | food_type | YES |  |  |  |  |
| `cuisine` | character varying(80) | YES |  |  |  |  |
| `description` | text | YES |  |  |  |  |
| `image_url` | character varying(500) | YES |  |  |  |  |
| `created_at` | timestamp with time zone | NO | now() |  |  |  |
| `updated_at` | timestamp with time zone | YES |  |  |  |  |
| `deleted_at` | timestamp with time zone | YES |  |  |  |  |

Indexes:

| Index | Definition |
|---|---|
| `dishes_dish_name_dish_category_id_key` | `CREATE UNIQUE INDEX dishes_dish_name_dish_category_id_key ON cleangoal.dishes USING btree (dish_name, dish_category_id)` |
| `dishes_pkey` | `CREATE UNIQUE INDEX dishes_pkey ON cleangoal.dishes USING btree (dish_id)` |
| `idx_dishes_category` | `CREATE INDEX idx_dishes_category ON cleangoal.dishes USING btree (dish_category_id)` |
| `idx_dishes_name_lower` | `CREATE INDEX idx_dishes_name_lower ON cleangoal.dishes USING btree (lower((dish_name)::text))` |

### `food_allergy_flags`

- Type: BASE TABLE
- Current rows: 20
- RLS enabled: yes
- Description: Maps which allergens are present in each food. Used to filter foods based on user allergy preferences.
- Primary key: `food_id, flag_id`
- Foreign keys: `flag_id` -> `allergy_flags.flag_id` (CASCADE); `food_id` -> `foods.food_id` (CASCADE)

| Column | Type | Nullable | Default | Key | References | Description |
|---|---|---|---|---|---|---|
| `food_id` | bigint | NO |  | PK, FK | `foods.food_id` |  |
| `flag_id` | integer | NO |  | PK, FK | `allergy_flags.flag_id` |  |

Indexes:

| Index | Definition |
|---|---|
| `food_allergy_flags_pkey` | `CREATE UNIQUE INDEX food_allergy_flags_pkey ON cleangoal.food_allergy_flags USING btree (food_id, flag_id)` |
| `idx_food_allergy_flags_flag` | `CREATE INDEX idx_food_allergy_flags_flag ON cleangoal.food_allergy_flags USING btree (flag_id)` |

### `food_ingredients`

- Type: BASE TABLE
- Current rows: 19
- RLS enabled: yes
- Description: Bridge table describing which normalized ingredients compose each food/menu item.
- Primary key: `food_ing_id`
- Foreign keys: `food_id` -> `foods.food_id` (CASCADE); `ingredient_id` -> `ingredients.ingredient_id` (RESTRICT); `unit_id` -> `units.unit_id` (SET NULL)

| Column | Type | Nullable | Default | Key | References | Description |
|---|---|---|---|---|---|---|
| `food_ing_id` | bigint | NO | nextval('food_ingredients_food_ing_id_seq'::regclass) | PK |  |  |
| `food_id` | bigint | NO |  | FK | `foods.food_id` |  |
| `ingredient_id` | bigint | NO |  | FK | `ingredients.ingredient_id` |  |
| `amount` | numeric(10,2) | NO |  |  |  |  |
| `unit_id` | integer | YES |  | FK | `units.unit_id` |  |
| `calculated_grams` | numeric(10,2) | YES |  |  |  |  |
| `note` | character varying | YES |  |  |  |  |
| `sort_order` | integer | NO | 0 |  |  |  |
| `created_at` | timestamp with time zone | NO | now() |  |  |  |
| `updated_at` | timestamp with time zone | YES |  |  |  |  |

Indexes:

| Index | Definition |
|---|---|
| `food_ingredients_food_ingredient_uq` | `CREATE UNIQUE INDEX food_ingredients_food_ingredient_uq ON cleangoal.food_ingredients USING btree (food_id, ingredient_id)` |
| `food_ingredients_pkey` | `CREATE UNIQUE INDEX food_ingredients_pkey ON cleangoal.food_ingredients USING btree (food_ing_id)` |
| `idx_food_ingredients_food_sort` | `CREATE INDEX idx_food_ingredients_food_sort ON cleangoal.food_ingredients USING btree (food_id, sort_order, food_ing_id)` |
| `idx_food_ingredients_ingredient` | `CREATE INDEX idx_food_ingredients_ingredient ON cleangoal.food_ingredients USING btree (ingredient_id)` |

### `food_versions`

- Type: BASE TABLE
- Current rows: 113
- RLS enabled: yes
- Description: Immutable version history for mutable food catalogue rows. User logs should point to the version used when recorded.
- Primary key: `food_version_id`
- Unique constraints: `food_versions_food_id_version_number_key` (food_id, version_number)
- Foreign keys: `created_by` -> `users.user_id` (SET NULL); `dish_id` -> `dishes.dish_id` (SET NULL); `food_id` -> `foods.food_id` (CASCADE); `serving_unit_id` -> `units.unit_id` (SET NULL)

| Column | Type | Nullable | Default | Key | References | Description |
|---|---|---|---|---|---|---|
| `food_version_id` | bigint | NO | nextval('food_versions_food_version_id_seq'::regclass) | PK |  |  |
| `food_id` | bigint | NO |  | FK | `foods.food_id` |  |
| `version_number` | integer | NO |  |  |  |  |
| `food_name` | character varying(200) | NO |  |  |  |  |
| `food_type` | food_type | YES |  |  |  |  |
| `calories` | numeric | YES |  |  |  |  |
| `protein` | numeric | YES |  |  |  |  |
| `carbs` | numeric | YES |  |  |  |  |
| `fat` | numeric | YES |  |  |  |  |
| `sodium` | numeric | YES |  |  |  |  |
| `sugar` | numeric | YES |  |  |  |  |
| `cholesterol` | numeric | YES |  |  |  |  |
| `fiber_g` | numeric | YES |  |  |  |  |
| `serving_quantity` | numeric | YES |  |  |  |  |
| `serving_unit_id` | integer | YES |  | FK | `units.unit_id` |  |
| `dish_id` | bigint | YES |  | FK | `dishes.dish_id` |  |
| `image_url` | character varying(500) | YES |  |  |  |  |
| `source` | character varying(40) | NO | 'catalog'::character varying |  |  |  |
| `change_reason` | text | YES |  |  |  |  |
| `is_current` | boolean | NO | true |  |  |  |
| `effective_from` | timestamp with time zone | NO | now() |  |  |  |
| `effective_to` | timestamp with time zone | YES |  |  |  |  |
| `created_at` | timestamp with time zone | NO | now() |  |  |  |
| `created_by` | bigint | YES |  | FK | `users.user_id` |  |

Indexes:

| Index | Definition |
|---|---|
| `food_versions_food_id_version_number_key` | `CREATE UNIQUE INDEX food_versions_food_id_version_number_key ON cleangoal.food_versions USING btree (food_id, version_number)` |
| `food_versions_one_current_uq` | `CREATE UNIQUE INDEX food_versions_one_current_uq ON cleangoal.food_versions USING btree (food_id) WHERE is_current` |
| `food_versions_pkey` | `CREATE UNIQUE INDEX food_versions_pkey ON cleangoal.food_versions USING btree (food_version_id)` |
| `idx_food_versions_food_effective` | `CREATE INDEX idx_food_versions_food_effective ON cleangoal.food_versions USING btree (food_id, effective_from DESC)` |

### `foods`

- Type: BASE TABLE
- Current rows: 113
- RLS enabled: yes
- Description: Mutable food catalogue row used by the app for selectable foods and drinks.
- Primary key: `food_id`
- Unique constraints: `uq_foods_food_name` (food_name)
- Foreign keys: `current_version_id` -> `food_versions.food_version_id` (SET NULL); `dish_id` -> `dishes.dish_id` (SET NULL); `serving_unit_id` -> `units.unit_id` (SET NULL)

| Column | Type | Nullable | Default | Key | References | Description |
|---|---|---|---|---|---|---|
| `food_id` | bigint | NO | nextval('foods_food_id_seq'::regclass) | PK |  |  |
| `food_name` | character varying(200) | NO |  | UK |  |  |
| `food_type` | food_type | YES | 'raw_ingredient'::food_type |  |  |  |
| `calories` | numeric(6,2) | YES |  |  |  |  |
| `protein` | numeric(6,2) | YES |  |  |  |  |
| `carbs` | numeric(6,2) | YES |  |  |  |  |
| `fat` | numeric(6,2) | YES |  |  |  |  |
| `sodium` | numeric(6,2) | YES |  |  |  |  |
| `sugar` | numeric(6,2) | YES |  |  |  |  |
| `cholesterol` | numeric(6,2) | YES |  |  |  |  |
| `serving_quantity` | numeric(6,2) | YES | 100 |  |  |  |
| `image_url` | character varying(500) | YES |  |  |  |  |
| `created_at` | timestamp with time zone | YES | now() |  |  |  |
| `updated_at` | timestamp with time zone | YES |  |  |  |  |
| `deleted_at` | timestamp with time zone | YES |  |  |  |  |
| `fiber_g` | numeric(6,2) | YES | 0 |  |  |  |
| `serving_unit_id` | integer | YES |  | FK | `units.unit_id` |  |
| `dish_id` | bigint | YES |  | FK | `dishes.dish_id` |  |
| `current_version_id` | bigint | YES |  | FK | `food_versions.food_version_id` | Current active catalogue version. Updating food nutrition creates a new food_versions row instead of mutating user history. |

Indexes:

| Index | Definition |
|---|---|
| `foods_pkey` | `CREATE UNIQUE INDEX foods_pkey ON cleangoal.foods USING btree (food_id)` |
| `idx_foods_active` | `CREATE INDEX idx_foods_active ON cleangoal.foods USING btree (deleted_at) WHERE (deleted_at IS NULL)` |
| `idx_foods_current_version_id` | `CREATE INDEX idx_foods_current_version_id ON cleangoal.foods USING btree (current_version_id)` |
| `idx_foods_dish_id` | `CREATE INDEX idx_foods_dish_id ON cleangoal.foods USING btree (dish_id)` |
| `idx_foods_name` | `CREATE INDEX idx_foods_name ON cleangoal.foods USING btree (food_name)` |
| `idx_foods_name_lower` | `CREATE INDEX idx_foods_name_lower ON cleangoal.foods USING btree (lower((food_name)::text))` |
| `idx_foods_not_deleted` | `CREATE INDEX idx_foods_not_deleted ON cleangoal.foods USING btree (food_id) WHERE (deleted_at IS NULL)` |
| `idx_foods_serving_unit_id` | `CREATE INDEX idx_foods_serving_unit_id ON cleangoal.foods USING btree (serving_unit_id)` |
| `uq_foods_food_name` | `CREATE UNIQUE INDEX uq_foods_food_name ON cleangoal.foods USING btree (food_name)` |

### `ingredient_unit_conversions`

- Type: BASE TABLE
- Current rows: 0
- RLS enabled: yes
- Description: Ingredient-specific household-unit conversions, e.g. piece to gram where generic unit conversion is not enough.
- Primary key: `ingredient_unit_conversion_id`
- Unique constraints: `ingredient_unit_conversions_ingredient_id_from_unit_id_to_u_key` (ingredient_id, from_unit_id, to_unit_id)
- Foreign keys: `from_unit_id` -> `units.unit_id` (RESTRICT); `ingredient_id` -> `ingredients.ingredient_id` (CASCADE); `to_unit_id` -> `units.unit_id` (RESTRICT)

| Column | Type | Nullable | Default | Key | References | Description |
|---|---|---|---|---|---|---|
| `ingredient_unit_conversion_id` | bigint | NO | nextval('ingredient_unit_conversions_ingredient_unit_conversion_id_seq'::regclass) | PK |  |  |
| `ingredient_id` | bigint | NO |  | FK | `ingredients.ingredient_id` |  |
| `from_unit_id` | integer | NO |  | FK | `units.unit_id` |  |
| `to_unit_id` | integer | NO |  | FK | `units.unit_id` |  |
| `factor` | numeric(12,6) | NO |  |  |  |  |
| `note` | character varying | YES |  |  |  |  |
| `created_at` | timestamp with time zone | NO | now() |  |  |  |

Indexes:

| Index | Definition |
|---|---|
| `ingredient_unit_conversions_ingredient_id_from_unit_id_to_u_key` | `CREATE UNIQUE INDEX ingredient_unit_conversions_ingredient_id_from_unit_id_to_u_key ON cleangoal.ingredient_unit_conversions USING btree (ingredient_id, from_unit_id, to_unit_id)` |
| `ingredient_unit_conversions_pkey` | `CREATE UNIQUE INDEX ingredient_unit_conversions_pkey ON cleangoal.ingredient_unit_conversions USING btree (ingredient_unit_conversion_id)` |

### `ingredients`

- Type: BASE TABLE
- Current rows: 21
- RLS enabled: yes
- Description: Strong entity for normalized ingredient/raw material catalog and nutrition reference values.
- Primary key: `ingredient_id`
- Foreign keys: `default_unit_id` -> `units.unit_id` (SET NULL); `nutrition_basis_unit_id` -> `units.unit_id` (SET NULL)

| Column | Type | Nullable | Default | Key | References | Description |
|---|---|---|---|---|---|---|
| `ingredient_id` | bigint | NO | nextval('ingredients_ingredient_id_seq'::regclass) | PK |  |  |
| `name` | character varying(150) | NO |  |  |  |  |
| `category` | character varying(50) | YES |  |  |  |  |
| `default_unit_id` | integer | YES |  | FK | `units.unit_id` | Default practical unit for this ingredient, normally g for solid foods and ml for liquids. |
| `calories_per_unit` | numeric(8,2) | YES |  |  |  |  |
| `protein_per_unit` | numeric(8,2) | YES | 0 |  |  |  |
| `carbs_per_unit` | numeric(8,2) | YES | 0 |  |  |  |
| `fat_per_unit` | numeric(8,2) | YES | 0 |  |  |  |
| `calories_per_100g` | numeric(8,2) | YES |  |  |  |  |
| `protein_per_100g` | numeric(8,2) | YES | 0 |  |  |  |
| `carbs_per_100g` | numeric(8,2) | YES | 0 |  |  |  |
| `fat_per_100g` | numeric(8,2) | YES | 0 |  |  |  |
| `sodium_mg_per_100g` | numeric(8,2) | YES | 0 |  |  |  |
| `sugar_g_per_100g` | numeric(8,2) | YES | 0 |  |  |  |
| `cholesterol_mg_per_100g` | numeric(8,2) | YES | 0 |  |  |  |
| `density_g_per_ml` | numeric(8,4) | YES |  |  |  |  |
| `source_reference` | character varying(255) | YES |  |  |  |  |
| `created_at` | timestamp with time zone | NO | now() |  |  |  |
| `updated_at` | timestamp with time zone | YES |  |  |  |  |
| `source_food_code` | character varying(40) | YES |  |  |  |  |
| `name_en` | character varying(255) | YES |  |  |  |  |
| `scientific_name` | character varying(255) | YES |  |  |  |  |
| `nutrition_basis_quantity` | numeric(10,2) | NO | 100 |  |  | Quantity used by nutrition reference values, normally 100 for ThaiFCD per-100g data. |
| `nutrition_basis_unit_id` | integer | YES |  | FK | `units.unit_id` | Unit used by nutrition reference values. ThaiFCD rows are usually per 100 g of food. |
| `fiber_g_per_100g` | numeric(8,2) | YES | 0 |  |  |  |
| `water_g_per_100g` | numeric(8,2) | YES |  |  |  |  |
| `calcium_mg_per_100g` | numeric(8,2) | YES |  |  |  |  |
| `phosphorus_mg_per_100g` | numeric(8,2) | YES |  |  |  |  |
| `iron_mg_per_100g` | numeric(8,2) | YES |  |  |  |  |

Indexes:

| Index | Definition |
|---|---|
| `ingredients_name_lower_uq` | `CREATE UNIQUE INDEX ingredients_name_lower_uq ON cleangoal.ingredients USING btree (lower((name)::text))` |
| `ingredients_name_uq` | `CREATE UNIQUE INDEX ingredients_name_uq ON cleangoal.ingredients USING btree (name)` |
| `ingredients_pkey` | `CREATE UNIQUE INDEX ingredients_pkey ON cleangoal.ingredients USING btree (ingredient_id)` |
| `ingredients_source_food_code_uq` | `CREATE UNIQUE INDEX ingredients_source_food_code_uq ON cleangoal.ingredients USING btree (source_food_code) WHERE (source_food_code IS NOT NULL)` |

### `snacks`

- Type: BASE TABLE
- Current rows: 20
- RLS enabled: yes
- Description: Subtype details for snack foods.
- Primary key: `snack_id`
- Unique constraints: `snacks_food_id_key` (food_id)
- Foreign keys: `food_id` -> `foods.food_id` (NO ACTION)

| Column | Type | Nullable | Default | Key | References | Description |
|---|---|---|---|---|---|---|
| `snack_id` | bigint | NO | nextval('snacks_snack_id_seq'::regclass) | PK |  |  |
| `food_id` | bigint | YES |  | FK, UK | `foods.food_id` |  |
| `is_sweet` | boolean | YES | true |  |  |  |
| `packaging_type` | character varying | YES |  |  |  |  |
| `trans_fat` | numeric(6,2) | YES |  |  |  |  |

Indexes:

| Index | Definition |
|---|---|
| `snacks_food_id_key` | `CREATE UNIQUE INDEX snacks_food_id_key ON cleangoal.snacks USING btree (food_id)` |
| `snacks_pkey` | `CREATE UNIQUE INDEX snacks_pkey ON cleangoal.snacks USING btree (snack_id)` |

### `unit_conversions`

- Type: BASE TABLE
- Current rows: 5
- RLS enabled: yes
- Description: Generic unit conversion table between units.
- Primary key: `conversion_id`
- Unique constraints: `unit_conversions_from_unit_id_to_unit_id_key` (from_unit_id, to_unit_id)
- Foreign keys: `from_unit_id` -> `units.unit_id` (CASCADE); `to_unit_id` -> `units.unit_id` (CASCADE)

| Column | Type | Nullable | Default | Key | References | Description |
|---|---|---|---|---|---|---|
| `conversion_id` | integer | NO | nextval('unit_conversions_conversion_id_seq'::regclass) | PK |  |  |
| `from_unit_id` | integer | NO |  | FK | `units.unit_id` |  |
| `to_unit_id` | integer | NO |  | FK | `units.unit_id` |  |
| `factor` | numeric(12,6) | NO |  |  |  |  |
| `note` | character varying | YES |  |  |  |  |
| `created_at` | timestamp with time zone | YES | now() |  |  |  |

Indexes:

| Index | Definition |
|---|---|
| `idx_unit_conversions_from_unit` | `CREATE INDEX idx_unit_conversions_from_unit ON cleangoal.unit_conversions USING btree (from_unit_id)` |
| `idx_unit_conversions_to_unit` | `CREATE INDEX idx_unit_conversions_to_unit ON cleangoal.unit_conversions USING btree (to_unit_id)` |
| `unit_conversions_from_unit_id_to_unit_id_key` | `CREATE UNIQUE INDEX unit_conversions_from_unit_id_to_unit_id_key ON cleangoal.unit_conversions USING btree (from_unit_id, to_unit_id)` |
| `unit_conversions_pkey` | `CREATE UNIQUE INDEX unit_conversions_pkey ON cleangoal.unit_conversions USING btree (conversion_id)` |

### `units`

- Type: BASE TABLE
- Current rows: 16
- RLS enabled: yes
- Description: Master data for units such as gram, milliliter, serving, spoon, and piece.
- Primary key: `unit_id`

| Column | Type | Nullable | Default | Key | References | Description |
|---|---|---|---|---|---|---|
| `unit_id` | integer | NO | nextval('units_unit_id_seq'::regclass) | PK |  |  |
| `name` | character varying(30) | NO |  |  |  |  |
| `quantity` | numeric(10,4) | YES |  |  |  |  |

Indexes:

| Index | Definition |
|---|---|
| `units_name_lower_uq` | `CREATE UNIQUE INDEX units_name_lower_uq ON cleangoal.units USING btree (lower((name)::text))` |
| `units_pkey` | `CREATE UNIQUE INDEX units_pkey ON cleangoal.units USING btree (unit_id)` |

## Recipes

### `recipe_favorites`

- Type: BASE TABLE
- Current rows: 20
- RLS enabled: yes
- Description: Legacy recipe-specific favorites. Active mobile API uses user_favorites(food_id).
- Primary key: `fav_id`
- Unique constraints: `recipe_favorites_recipe_id_user_id_key` (recipe_id, user_id)
- Foreign keys: `recipe_id` -> `recipes.recipe_id` (CASCADE); `user_id` -> `users.user_id` (CASCADE)

| Column | Type | Nullable | Default | Key | References | Description |
|---|---|---|---|---|---|---|
| `fav_id` | bigint | NO |  | PK |  |  |
| `recipe_id` | bigint | NO |  | FK | `recipes.recipe_id` |  |
| `user_id` | bigint | NO |  | FK | `users.user_id` |  |
| `created_at` | timestamp with time zone | YES | now() |  |  |  |

Indexes:

| Index | Definition |
|---|---|
| `idx_recipe_favorites_user` | `CREATE INDEX idx_recipe_favorites_user ON cleangoal.recipe_favorites USING btree (user_id)` |
| `recipe_favorites_pkey` | `CREATE UNIQUE INDEX recipe_favorites_pkey ON cleangoal.recipe_favorites USING btree (fav_id)` |
| `recipe_favorites_recipe_id_user_id_key` | `CREATE UNIQUE INDEX recipe_favorites_recipe_id_user_id_key ON cleangoal.recipe_favorites USING btree (recipe_id, user_id)` |

### `recipe_ingredients`

- Type: BASE TABLE
- Current rows: 54
- RLS enabled: yes
- Description: Recipe ingredient rows connected to recipes, food ingredients, normalized ingredients, and units.
- Primary key: `ing_id`
- Foreign keys: `food_ing_id` -> `food_ingredients.food_ing_id` (SET NULL); `ingredient_id` -> `ingredients.ingredient_id` (SET NULL); `recipe_id` -> `recipes.recipe_id` (CASCADE); `unit_id` -> `units.unit_id` (SET NULL)

| Column | Type | Nullable | Default | Key | References | Description |
|---|---|---|---|---|---|---|
| `ing_id` | bigint | NO |  | PK |  |  |
| `recipe_id` | bigint | NO |  | FK | `recipes.recipe_id` |  |
| `ingredient_name` | character varying | NO |  |  |  |  |
| `quantity` | numeric(8,2) | YES |  |  |  |  |
| `unit` | character varying | YES |  |  |  |  |
| `is_optional` | boolean | YES | false |  |  |  |
| `note` | character varying | YES |  |  |  |  |
| `sort_order` | integer | YES | 0 |  |  |  |
| `created_at` | timestamp with time zone | YES | now() |  |  |  |
| `food_ing_id` | bigint | YES |  | FK | `food_ingredients.food_ing_id` | Optional FK to the food_ingredients row used to display this recipe ingredient with normalized nutrition. |
| `ingredient_id` | bigint | YES |  | FK | `ingredients.ingredient_id` | Optional direct FK to ingredients for recipe rows that are not yet tied to a food_ingredients composition row. |
| `unit_id` | integer | YES |  | FK | `units.unit_id` |  |
| `calculated_grams` | numeric(10,2) | YES |  |  |  |  |
| `calculated_calories` | numeric(10,2) | YES |  |  |  |  |
| `calculated_protein` | numeric(10,2) | YES |  |  |  |  |
| `calculated_carbs` | numeric(10,2) | YES |  |  |  |  |
| `calculated_fat` | numeric(10,2) | YES |  |  |  |  |
| `updated_at` | timestamp with time zone | YES |  |  |  |  |

Indexes:

| Index | Definition |
|---|---|
| `idx_recipe_ingredients_food_ing` | `CREATE INDEX idx_recipe_ingredients_food_ing ON cleangoal.recipe_ingredients USING btree (food_ing_id)` |
| `idx_recipe_ingredients_ingredient` | `CREATE INDEX idx_recipe_ingredients_ingredient ON cleangoal.recipe_ingredients USING btree (ingredient_id)` |
| `idx_recipe_ingredients_recipe` | `CREATE INDEX idx_recipe_ingredients_recipe ON cleangoal.recipe_ingredients USING btree (recipe_id)` |
| `recipe_ingredients_pkey` | `CREATE UNIQUE INDEX recipe_ingredients_pkey ON cleangoal.recipe_ingredients USING btree (ing_id)` |
| `recipe_ingredients_recipe_food_ing_uq` | `CREATE UNIQUE INDEX recipe_ingredients_recipe_food_ing_uq ON cleangoal.recipe_ingredients USING btree (recipe_id, food_ing_id) WHERE (food_ing_id IS NOT NULL)` |

### `recipe_reviews`

- Type: BASE TABLE
- Current rows: 0
- RLS enabled: yes
- Description: Recipe ratings and comments from users.
- Primary key: `review_id`
- Unique constraints: `recipe_reviews_recipe_id_user_id_key` (recipe_id, user_id)
- Foreign keys: `recipe_id` -> `recipes.recipe_id` (CASCADE); `user_id` -> `users.user_id` (CASCADE)

| Column | Type | Nullable | Default | Key | References | Description |
|---|---|---|---|---|---|---|
| `review_id` | bigint | NO |  | PK |  |  |
| `recipe_id` | bigint | NO |  | FK | `recipes.recipe_id` |  |
| `user_id` | bigint | NO |  | FK | `users.user_id` |  |
| `rating` | smallint | YES |  |  |  |  |
| `comment` | text | YES |  |  |  |  |
| `created_at` | timestamp with time zone | YES | now() |  |  |  |

Indexes:

| Index | Definition |
|---|---|
| `idx_recipe_reviews_recipe` | `CREATE INDEX idx_recipe_reviews_recipe ON cleangoal.recipe_reviews USING btree (recipe_id)` |
| `recipe_reviews_pkey` | `CREATE UNIQUE INDEX recipe_reviews_pkey ON cleangoal.recipe_reviews USING btree (review_id)` |
| `recipe_reviews_recipe_created_idx` | `CREATE INDEX recipe_reviews_recipe_created_idx ON cleangoal.recipe_reviews USING btree (recipe_id, created_at DESC)` |
| `recipe_reviews_recipe_id_user_id_key` | `CREATE UNIQUE INDEX recipe_reviews_recipe_id_user_id_key ON cleangoal.recipe_reviews USING btree (recipe_id, user_id)` |

### `recipe_steps`

- Type: BASE TABLE
- Current rows: 196
- RLS enabled: yes
- Description: Ordered preparation steps for recipes.
- Primary key: `step_id`
- Foreign keys: `recipe_id` -> `recipes.recipe_id` (CASCADE)

| Column | Type | Nullable | Default | Key | References | Description |
|---|---|---|---|---|---|---|
| `step_id` | bigint | NO |  | PK |  |  |
| `recipe_id` | bigint | NO |  | FK | `recipes.recipe_id` |  |
| `step_number` | integer | NO |  |  |  |  |
| `title` | character varying | YES |  |  |  |  |
| `instruction` | text | NO |  |  |  |  |
| `time_minutes` | integer | YES | 0 |  |  |  |
| `image_url` | character varying | YES |  |  |  |  |
| `tips` | text | YES |  |  |  |  |
| `created_at` | timestamp with time zone | YES | now() |  |  |  |

Indexes:

| Index | Definition |
|---|---|
| `idx_recipe_steps_recipe` | `CREATE INDEX idx_recipe_steps_recipe ON cleangoal.recipe_steps USING btree (recipe_id, step_number)` |
| `recipe_steps_pkey` | `CREATE UNIQUE INDEX recipe_steps_pkey ON cleangoal.recipe_steps USING btree (step_id)` |

### `recipe_tips`

- Type: BASE TABLE
- Current rows: 10
- RLS enabled: yes
- Description: Recipe tips or cooking notes.
- Primary key: `tip_id`
- Foreign keys: `recipe_id` -> `recipes.recipe_id` (CASCADE)

| Column | Type | Nullable | Default | Key | References | Description |
|---|---|---|---|---|---|---|
| `tip_id` | bigint | NO |  | PK |  |  |
| `recipe_id` | bigint | NO |  | FK | `recipes.recipe_id` |  |
| `tip_text` | text | NO |  |  |  |  |
| `sort_order` | integer | YES | 0 |  |  |  |
| `created_at` | timestamp with time zone | YES | now() |  |  |  |

Indexes:

| Index | Definition |
|---|---|
| `idx_recipe_tips_recipe` | `CREATE INDEX idx_recipe_tips_recipe ON cleangoal.recipe_tips USING btree (recipe_id)` |
| `recipe_tips_pkey` | `CREATE UNIQUE INDEX recipe_tips_pkey ON cleangoal.recipe_tips USING btree (tip_id)` |

### `recipe_tools`

- Type: BASE TABLE
- Current rows: 12
- RLS enabled: yes
- Description: Cooking tools or equipment used by recipes.
- Primary key: `tool_id`
- Foreign keys: `recipe_id` -> `recipes.recipe_id` (CASCADE)

| Column | Type | Nullable | Default | Key | References | Description |
|---|---|---|---|---|---|---|
| `tool_id` | bigint | NO |  | PK |  |  |
| `recipe_id` | bigint | NO |  | FK | `recipes.recipe_id` |  |
| `tool_name` | character varying | NO |  |  |  |  |
| `tool_emoji` | character varying | YES |  |  |  |  |
| `sort_order` | integer | YES | 0 |  |  |  |
| `created_at` | timestamp with time zone | YES | now() |  |  |  |

Indexes:

| Index | Definition |
|---|---|
| `idx_recipe_tools_recipe` | `CREATE INDEX idx_recipe_tools_recipe ON cleangoal.recipe_tools USING btree (recipe_id)` |
| `recipe_tools_pkey` | `CREATE UNIQUE INDEX recipe_tools_pkey ON cleangoal.recipe_tools USING btree (tool_id)` |

### `recipes`

- Type: BASE TABLE
- Current rows: 66
- RLS enabled: yes
- Description: Recipe header/details for a food, with AI/manual source and JSON fallback fields.
- Primary key: `recipe_id`
- Unique constraints: `recipes_food_id_key` (food_id)
- Foreign keys: `food_id` -> `foods.food_id` (NO ACTION)

| Column | Type | Nullable | Default | Key | References | Description |
|---|---|---|---|---|---|---|
| `recipe_id` | bigint | NO | nextval('recipes_recipe_id_seq'::regclass) | PK |  |  |
| `food_id` | bigint | NO |  | FK, UK | `foods.food_id` |  |
| `description` | character varying | YES |  |  |  |  |
| `instructions` | text | YES |  |  |  |  |
| `prep_time_minutes` | integer | YES | 0 |  |  |  |
| `cooking_time_minutes` | integer | YES | 0 |  |  |  |
| `serving_people` | numeric(3,1) | YES | 1.0 |  |  |  |
| `source_reference` | character varying | YES |  |  |  |  |
| `image_url` | character varying | YES |  |  |  |  |
| `created_at` | timestamp with time zone | YES | now() |  |  |  |
| `deleted_at` | timestamp with time zone | YES |  |  |  |  |
| `avg_rating` | numeric(3,2) | YES | 0 |  |  |  |
| `review_count` | integer | YES | 0 |  |  |  |
| `ingredients_json` | jsonb | YES |  |  |  |  |
| `tools_json` | jsonb | YES |  |  |  |  |
| `tips_json` | jsonb | YES |  |  |  |  |
| `generated_by` | character varying(32) | YES |  |  |  |  |
| `favorite_count` | integer | NO | 0 |  |  |  |

Indexes:

| Index | Definition |
|---|---|
| `recipes_food_id_key` | `CREATE UNIQUE INDEX recipes_food_id_key ON cleangoal.recipes USING btree (food_id)` |
| `recipes_pkey` | `CREATE UNIQUE INDEX recipes_pkey ON cleangoal.recipes USING btree (recipe_id)` |

## Logging & Summaries

### `daily_summaries`

- Type: BASE TABLE
- Current rows: 20
- RLS enabled: yes
- Description: Daily user nutrition, water, and goal summary data.
- Primary key: `summary_id`
- Unique constraints: `uq_daily_summaries_user_date` (user_id, date_record)
- Foreign keys: `user_id` -> `users.user_id` (CASCADE)

| Column | Type | Nullable | Default | Key | References | Description |
|---|---|---|---|---|---|---|
| `summary_id` | bigint | NO | nextval('daily_summaries_summary_id_seq'::regclass) | PK |  |  |
| `user_id` | bigint | NO |  | FK | `users.user_id` |  |
| `date_record` | date | NO | CURRENT_DATE |  |  |  |
| `total_calories_intake` | numeric(10,2) | YES | 0 |  |  |  |
| `total_protein` | numeric(10,2) | YES | 0 |  |  | โปรตีนรวม (กรัม) ของวันนั้น |
| `total_carbs` | numeric(10,2) | YES | 0 |  |  | คาร์บรวม (กรัม) ของวันนั้น |
| `total_fat` | numeric(10,2) | YES | 0 |  |  | ไขมันรวม (กรัม) ของวันนั้น |
| `water_glasses` | integer | YES | 0 |  |  | จำนวนแก้วน้ำที่ดื่มในวันนั้น |
| `goal_calories` | integer | YES |  |  |  |  |
| `is_goal_met` | boolean | YES | false |  |  |  |
| `updated_at` | timestamp with time zone | NO | now() |  |  |  |

Indexes:

| Index | Definition |
|---|---|
| `daily_summaries_pkey` | `CREATE UNIQUE INDEX daily_summaries_pkey ON cleangoal.daily_summaries USING btree (summary_id)` |
| `idx_daily_summaries_user_date` | `CREATE INDEX idx_daily_summaries_user_date ON cleangoal.daily_summaries USING btree (user_id, date_record DESC)` |
| `uq_daily_summaries_user_date` | `CREATE UNIQUE INDEX uq_daily_summaries_user_date ON cleangoal.daily_summaries USING btree (user_id, date_record)` |

### `detail_items`

- Type: BASE TABLE
- Current rows: 45
- RLS enabled: yes
- Description: Historical meal-log item snapshots. Do not overwrite from foods after insert.
- Primary key: `item_id`
- Foreign keys: `food_version_id` -> `food_versions.food_version_id` (SET NULL); `meal_id` -> `meals.meal_id` (CASCADE); `summary_id` -> `daily_summaries.summary_id` (CASCADE); `unit_id` -> `units.unit_id` (SET NULL); `food_id` -> `foods.food_id` (SET NULL); `plan_id` -> `user_meal_plans.plan_id` (CASCADE)

| Column | Type | Nullable | Default | Key | References | Description |
|---|---|---|---|---|---|---|
| `item_id` | bigint | NO |  | PK |  |  |
| `meal_id` | bigint | YES |  | FK | `meals.meal_id` |  |
| `plan_id` | bigint | YES |  | FK | `user_meal_plans.plan_id` |  |
| `summary_id` | bigint | YES |  | FK | `daily_summaries.summary_id` |  |
| `food_id` | bigint | YES |  | FK | `foods.food_id` |  |
| `food_name` | character varying(200) | YES |  |  |  |  |
| `day_number` | integer | YES |  |  |  |  |
| `amount` | numeric(8,2) | YES | 1 |  |  |  |
| `unit_id` | integer | YES |  | FK | `units.unit_id` |  |
| `cal_per_unit` | numeric(10,2) | YES |  |  |  |  |
| `protein_per_unit` | numeric(10,2) | YES |  |  |  | โปรตีน (กรัม) ต่อหน่วย |
| `carbs_per_unit` | numeric(10,2) | YES |  |  |  | คาร์บ (กรัม) ต่อหน่วย |
| `fat_per_unit` | numeric(10,2) | YES |  |  |  | ไขมัน (กรัม) ต่อหน่วย |
| `note` | character varying(500) | YES |  |  |  |  |
| `created_at` | timestamp with time zone | YES | now() |  |  |  |
| `updated_at` | timestamp with time zone | NO | now() |  |  |  |
| `food_version_id` | bigint | YES |  | FK | `food_versions.food_version_id` | Food catalogue version used when this historical log item was recorded. |
| `food_snapshot` | jsonb | YES |  |  |  | Immutable JSON snapshot of food/log values at insert time. Existing rows were backfilled from their current detail_items values, not from foods. |

Indexes:

| Index | Definition |
|---|---|
| `detail_items_pkey` | `CREATE UNIQUE INDEX detail_items_pkey ON cleangoal.detail_items USING btree (item_id)` |
| `idx_detail_items_food_id` | `CREATE INDEX idx_detail_items_food_id ON cleangoal.detail_items USING btree (food_id) WHERE (food_id IS NOT NULL)` |
| `idx_detail_items_food_version_id` | `CREATE INDEX idx_detail_items_food_version_id ON cleangoal.detail_items USING btree (food_version_id)` |
| `idx_detail_items_meal_id` | `CREATE INDEX idx_detail_items_meal_id ON cleangoal.detail_items USING btree (meal_id)` |
| `idx_detail_items_unit_id` | `CREATE INDEX idx_detail_items_unit_id ON cleangoal.detail_items USING btree (unit_id)` |

### `exercise_logs`

- Type: BASE TABLE
- Current rows: 20
- RLS enabled: yes
- Description: บันทึกการออกกำลังกายรายวันของผู้ใช้
- Primary key: `log_id`
- Foreign keys: `user_id` -> `users.user_id` (CASCADE)

| Column | Type | Nullable | Default | Key | References | Description |
|---|---|---|---|---|---|---|
| `log_id` | bigint | NO | nextval('exercise_logs_log_id_seq'::regclass) | PK |  |  |
| `user_id` | bigint | NO |  | FK | `users.user_id` |  |
| `date_record` | date | NO | CURRENT_DATE |  |  |  |
| `activity_name` | character varying(100) | NO |  |  |  | ชื่อกิจกรรม เช่น วิ่ง ว่ายน้ำ ยกน้ำหนัก |
| `duration_minutes` | integer | NO | 0 |  |  | ระยะเวลา (นาที) |
| `calories_burned` | numeric(8,2) | YES | 0 |  |  | แคลอรี่ที่เผาผลาญ |
| `intensity` | character varying(20) | YES | 'moderate'::character varying |  |  | ความหนัก: low / moderate / high |
| `note` | character varying(255) | YES |  |  |  |  |
| `created_at` | timestamp with time zone | YES | now() |  |  |  |
| `updated_at` | timestamp with time zone | NO | now() |  |  |  |

Indexes:

| Index | Definition |
|---|---|
| `exercise_logs_pkey` | `CREATE UNIQUE INDEX exercise_logs_pkey ON cleangoal.exercise_logs USING btree (log_id)` |
| `idx_exercise_logs_user_date` | `CREATE INDEX idx_exercise_logs_user_date ON cleangoal.exercise_logs USING btree (user_id, date_record DESC)` |

### `meals`

- Type: BASE TABLE
- Current rows: 39
- RLS enabled: yes
- Description: User meal headers by date and meal type.
- Primary key: `meal_id`
- Foreign keys: `user_id` -> `users.user_id` (CASCADE)

| Column | Type | Nullable | Default | Key | References | Description |
|---|---|---|---|---|---|---|
| `meal_id` | bigint | NO |  | PK |  |  |
| `user_id` | bigint | NO |  | FK | `users.user_id` |  |
| `meal_time` | timestamp with time zone | YES | now() |  |  |  |
| `total_amount` | numeric | YES |  |  |  |  |
| `created_at` | timestamp with time zone | YES | now() |  |  |  |
| `updated_at` | timestamp with time zone | YES |  |  |  |  |
| `meal_type` | meal_type | NO |  |  |  |  |

Indexes:

| Index | Definition |
|---|---|
| `idx_meals_user_date` | `CREATE INDEX idx_meals_user_date ON cleangoal.meals USING btree (user_id, (((meal_time AT TIME ZONE 'Asia/Bangkok'::text))::date) DESC)` |
| `idx_meals_user_date_type` | `CREATE INDEX idx_meals_user_date_type ON cleangoal.meals USING btree (user_id, (((meal_time AT TIME ZONE 'Asia/Bangkok'::text))::date), meal_type)` |
| `idx_meals_user_meal_time` | `CREATE INDEX idx_meals_user_meal_time ON cleangoal.meals USING btree (user_id, meal_time)` |
| `meals_pkey` | `CREATE UNIQUE INDEX meals_pkey ON cleangoal.meals USING btree (meal_id)` |

### `water_logs`

- Type: BASE TABLE
- Current rows: 10
- RLS enabled: yes
- Description: บันทึกจำนวนแก้วน้ำที่ดื่มต่อวัน
- Primary key: `log_id`
- Unique constraints: `uq_water_logs_user_date` (user_id, date_record)
- Foreign keys: `user_id` -> `users.user_id` (CASCADE)

| Column | Type | Nullable | Default | Key | References | Description |
|---|---|---|---|---|---|---|
| `log_id` | bigint | NO | nextval('water_logs_log_id_seq'::regclass) | PK |  |  |
| `user_id` | bigint | NO |  | FK | `users.user_id` |  |
| `date_record` | date | NO | CURRENT_DATE |  |  |  |
| `glasses` | integer | NO | 0 |  |  | จำนวนแก้วน้ำ (1 แก้ว = ~250 ml) |
| `updated_at` | timestamp with time zone | YES | now() |  |  |  |
| `amount_ml` | integer | NO | 0 |  |  |  |

Indexes:

| Index | Definition |
|---|---|
| `idx_water_logs_user_date` | `CREATE INDEX idx_water_logs_user_date ON cleangoal.water_logs USING btree (user_id, date_record DESC)` |
| `uq_water_logs_user_date` | `CREATE UNIQUE INDEX uq_water_logs_user_date ON cleangoal.water_logs USING btree (user_id, date_record)` |
| `water_logs_pkey` | `CREATE UNIQUE INDEX water_logs_pkey ON cleangoal.water_logs USING btree (log_id)` |

### `weight_logs`

- Type: BASE TABLE
- Current rows: 33
- RLS enabled: yes
- Description: User body weight and body metric logs.
- Primary key: `log_id`
- Unique constraints: `weight_logs_user_id_recorded_date_key` (user_id, recorded_date)
- Foreign keys: `user_id` -> `users.user_id` (CASCADE)

| Column | Type | Nullable | Default | Key | References | Description |
|---|---|---|---|---|---|---|
| `log_id` | bigint | NO | nextval('weight_logs_log_id_seq'::regclass) | PK |  |  |
| `user_id` | bigint | NO |  | FK | `users.user_id` |  |
| `weight_kg` | numeric(5,2) | NO |  |  |  |  |
| `recorded_date` | date | YES | CURRENT_DATE |  |  |  |
| `created_at` | timestamp with time zone | YES | now() |  |  |  |

Indexes:

| Index | Definition |
|---|---|
| `idx_weight_logs_user_date` | `CREATE INDEX idx_weight_logs_user_date ON cleangoal.weight_logs USING btree (user_id, recorded_date DESC)` |
| `weight_logs_pkey` | `CREATE UNIQUE INDEX weight_logs_pkey ON cleangoal.weight_logs USING btree (log_id)` |
| `weight_logs_user_id_recorded_date_key` | `CREATE UNIQUE INDEX weight_logs_user_id_recorded_date_key ON cleangoal.weight_logs USING btree (user_id, recorded_date)` |

## Goals & Personalization

### `user_allergy_preferences`

- Type: BASE TABLE
- Current rows: 28
- RLS enabled: yes
- Description: User-selected allergy flags used to filter or warn on foods.
- Primary key: `user_id, flag_id`
- Foreign keys: `flag_id` -> `allergy_flags.flag_id` (CASCADE); `user_id` -> `users.user_id` (CASCADE)

| Column | Type | Nullable | Default | Key | References | Description |
|---|---|---|---|---|---|---|
| `user_id` | bigint | NO |  | PK, FK | `users.user_id` |  |
| `flag_id` | integer | NO |  | PK, FK | `allergy_flags.flag_id` |  |
| `preference_type` | character varying | YES |  |  |  |  |
| `created_at` | timestamp with time zone | YES | now() |  |  |  |

Indexes:

| Index | Definition |
|---|---|
| `idx_allergy_prefs_user` | `CREATE INDEX idx_allergy_prefs_user ON cleangoal.user_allergy_preferences USING btree (user_id)` |
| `user_allergy_preferences_pkey` | `CREATE UNIQUE INDEX user_allergy_preferences_pkey ON cleangoal.user_allergy_preferences USING btree (user_id, flag_id)` |

### `user_meal_plans`

- Type: BASE TABLE
- Current rows: 20
- RLS enabled: yes
- Description: Planned meals for users.
- Primary key: `plan_id`
- Foreign keys: `user_id` -> `users.user_id` (SET NULL)

| Column | Type | Nullable | Default | Key | References | Description |
|---|---|---|---|---|---|---|
| `plan_id` | bigint | NO | nextval('user_meal_plans_plan_id_seq'::regclass) | PK |  |  |
| `user_id` | bigint | YES |  | FK | `users.user_id` |  |
| `name` | character varying | NO |  |  |  |  |
| `description` | text | YES |  |  |  |  |
| `source_type` | character varying | YES | 'SYSTEM'::character varying |  |  |  |
| `is_premium` | boolean | YES | false |  |  |  |
| `created_at` | timestamp with time zone | YES | now() |  |  |  |

Indexes:

| Index | Definition |
|---|---|
| `user_meal_plans_pkey` | `CREATE UNIQUE INDEX user_meal_plans_pkey ON cleangoal.user_meal_plans USING btree (plan_id)` |

## Moderation & Regionalization

### `food_regional_name_submissions`

- Type: BASE TABLE
- Current rows: 0
- RLS enabled: yes
- Description: User-submitted regional name suggestions awaiting admin review
- Primary key: `submission_id`
- Foreign keys: `food_id` -> `foods.food_id` (CASCADE); `reviewed_by` -> `users.user_id` (SET NULL); `user_id` -> `users.user_id` (CASCADE)

| Column | Type | Nullable | Default | Key | References | Description |
|---|---|---|---|---|---|---|
| `submission_id` | bigint | NO | nextval('food_regional_name_submissions_submission_id_seq'::regclass) | PK |  |  |
| `food_id` | bigint | NO |  | FK | `foods.food_id` |  |
| `region` | thai_region | NO |  |  |  |  |
| `name_th` | character varying(200) | NO |  |  |  |  |
| `popularity` | smallint | YES |  |  |  |  |
| `user_id` | bigint | NO |  | FK | `users.user_id` |  |
| `status` | request_status | NO | 'pending'::request_status |  |  |  |
| `reviewed_by` | bigint | YES |  | FK | `users.user_id` |  |
| `reviewed_at` | timestamp with time zone | YES |  |  |  |  |
| `created_at` | timestamp with time zone | NO | now() |  |  |  |

Indexes:

| Index | Definition |
|---|---|
| `food_regional_name_submissions_pkey` | `CREATE UNIQUE INDEX food_regional_name_submissions_pkey ON cleangoal.food_regional_name_submissions USING btree (submission_id)` |
| `idx_food_regional_subm_status` | `CREATE INDEX idx_food_regional_subm_status ON cleangoal.food_regional_name_submissions USING btree (status, created_at)` |
| `idx_food_regional_subm_user` | `CREATE INDEX idx_food_regional_subm_user ON cleangoal.food_regional_name_submissions USING btree (user_id)` |

### `food_regional_names`

- Type: BASE TABLE
- Current rows: 10
- RLS enabled: yes
- Description: Alternative Thai names for foods per region (dialect / regional naming)
- Primary key: `variant_id`
- Unique constraints: `uq_food_region_name` (food_id, region, name_th)
- Foreign keys: `approved_by` -> `users.user_id` (SET NULL); `created_by` -> `users.user_id` (SET NULL); `food_id` -> `foods.food_id` (CASCADE)

| Column | Type | Nullable | Default | Key | References | Description |
|---|---|---|---|---|---|---|
| `variant_id` | bigint | NO | nextval('food_regional_names_variant_id_seq'::regclass) | PK |  |  |
| `food_id` | bigint | NO |  | FK | `foods.food_id` |  |
| `region` | thai_region | NO |  |  |  |  |
| `name_th` | character varying(200) | NO |  |  |  |  |
| `is_primary` | boolean | NO | false |  |  |  |
| `created_by` | bigint | YES |  | FK | `users.user_id` |  |
| `approved_by` | bigint | YES |  | FK | `users.user_id` |  |
| `created_at` | timestamp with time zone | NO | now() |  |  |  |
| `updated_at` | timestamp with time zone | NO | now() |  |  |  |
| `deleted_at` | timestamp with time zone | YES |  |  |  |  |

Indexes:

| Index | Definition |
|---|---|
| `food_regional_names_pkey` | `CREATE UNIQUE INDEX food_regional_names_pkey ON cleangoal.food_regional_names USING btree (variant_id)` |
| `idx_food_regional_food` | `CREATE INDEX idx_food_regional_food ON cleangoal.food_regional_names USING btree (food_id) WHERE (deleted_at IS NULL)` |
| `idx_food_regional_lookup` | `CREATE INDEX idx_food_regional_lookup ON cleangoal.food_regional_names USING btree (region, lower((name_th)::text)) WHERE (deleted_at IS NULL)` |
| `uq_food_region_name` | `CREATE UNIQUE INDEX uq_food_region_name ON cleangoal.food_regional_names USING btree (food_id, region, name_th)` |
| `uq_food_regional_primary` | `CREATE UNIQUE INDEX uq_food_regional_primary ON cleangoal.food_regional_names USING btree (food_id, region) WHERE (is_primary AND (deleted_at IS NULL))` |

### `food_regional_popularity`

- Type: BASE TABLE
- Current rows: 7
- RLS enabled: yes
- Description: How common a food is in each region (1=rare, 5=ubiquitous)
- Primary key: `food_id, region`
- Foreign keys: `food_id` -> `foods.food_id` (CASCADE)

| Column | Type | Nullable | Default | Key | References | Description |
|---|---|---|---|---|---|---|
| `food_id` | bigint | NO |  | PK, FK | `foods.food_id` |  |
| `region` | thai_region | NO |  | PK |  |  |
| `popularity` | smallint | NO |  |  |  |  |
| `note` | character varying(200) | YES |  |  |  |  |
| `updated_at` | timestamp with time zone | NO | now() |  |  |  |

Indexes:

| Index | Definition |
|---|---|
| `food_regional_popularity_pkey` | `CREATE UNIQUE INDEX food_regional_popularity_pkey ON cleangoal.food_regional_popularity USING btree (food_id, region)` |

### `temp_food`

- Type: BASE TABLE
- Current rows: 9
- RLS enabled: yes
- Description: เมนูอาหารที่ user บันทึกด่วน รอ admin ตรวจสอบ
- Primary key: `tf_id`
- Foreign keys: `user_id` -> `users.user_id` (CASCADE)

| Column | Type | Nullable | Default | Key | References | Description |
|---|---|---|---|---|---|---|
| `tf_id` | bigint | NO | nextval('temp_food_tf_id_seq'::regclass) | PK |  | Primary key ของ temp_food |
| `food_name` | character varying(200) | NO |  |  |  | ชื่อเมนูอาหาร (บังคับกรอก) |
| `protein` | numeric(6,2) | YES | 0 |  |  | โปรตีน (กรัม) — ไม่บังคับ default 0 |
| `fat` | numeric(6,2) | YES | 0 |  |  | ไขมัน (กรัม) — ไม่บังคับ default 0 |
| `carbs` | numeric(6,2) | YES | 0 |  |  | คาร์โบไฮเดรต (กรัม) — ไม่บังคับ default 0 |
| `calories` | numeric(6,2) | YES | 0 |  |  | แคลอรี่ (kcal) — ไม่บังคับ default 0 |
| `user_id` | bigint | NO |  | FK | `users.user_id` | ผู้ใช้ที่เป็นคนเพิ่ม (track ว่าใครเพิ่ม) |
| `created_at` | timestamp with time zone | NO | now() |  |  | เวลา timestamp ที่เพิ่มเข้าระบบ |
| `updated_at` | timestamp with time zone | YES |  |  |  | เวลาที่ admin แก้ไขล่าสุด |

Indexes:

| Index | Definition |
|---|---|
| `idx_temp_food_created_at` | `CREATE INDEX idx_temp_food_created_at ON cleangoal.temp_food USING btree (created_at DESC)` |
| `idx_temp_food_user_id` | `CREATE INDEX idx_temp_food_user_id ON cleangoal.temp_food USING btree (user_id)` |
| `temp_food_pkey` | `CREATE UNIQUE INDEX temp_food_pkey ON cleangoal.temp_food USING btree (tf_id)` |

### `verified_food`

- Type: BASE TABLE
- Current rows: 9
- RLS enabled: yes
- Description: สถานะการตรวจสอบเมนูที่ user เพิ่มเข้ามาใน temp_food
- Primary key: `vf_id`
- Unique constraints: `verified_food_tf_id_key` (tf_id)
- Foreign keys: `tf_id` -> `temp_food.tf_id` (CASCADE); `verified_by` -> `users.user_id` (SET NULL)

| Column | Type | Nullable | Default | Key | References | Description |
|---|---|---|---|---|---|---|
| `vf_id` | bigint | NO | nextval('verified_food_vf_id_seq'::regclass) | PK |  | Primary key ของ verified_food |
| `tf_id` | bigint | NO |  | FK, UK | `temp_food.tf_id` | FK → temp_food.tf_id (1:1) |
| `is_verify` | boolean | NO | false |  |  | FALSE = unverified, TRUE = verified โดย admin |
| `verified_by` | bigint | YES |  | FK | `users.user_id` | admin user_id ที่เป็นคน verify (role_id = 1) |
| `verified_at` | timestamp with time zone | YES |  |  |  | เวลาที่ admin ยืนยัน (NULL ถ้ายังไม่ verify) |
| `created_at` | timestamp with time zone | NO | now() |  |  | เวลาที่ record ถูกสร้าง (ตอน user เพิ่มอาหารด่วน) |
| `updated_at` | timestamp with time zone | YES |  |  |  | เวลาที่ status ถูกแก้ไขล่าสุด |

Indexes:

| Index | Definition |
|---|---|
| `idx_verified_food_is_verify` | `CREATE INDEX idx_verified_food_is_verify ON cleangoal.verified_food USING btree (is_verify)` |
| `idx_verified_food_tf_id` | `CREATE INDEX idx_verified_food_tf_id ON cleangoal.verified_food USING btree (tf_id)` |
| `verified_food_pkey` | `CREATE UNIQUE INDEX verified_food_pkey ON cleangoal.verified_food USING btree (vf_id)` |
| `verified_food_tf_id_key` | `CREATE UNIQUE INDEX verified_food_tf_id_key ON cleangoal.verified_food USING btree (tf_id)` |

## Content & Notifications

### `health_contents`

- Type: BASE TABLE
- Current rows: 20
- RLS enabled: yes
- Description: Health articles and videos shown in the app.
- Primary key: `content_id`

| Column | Type | Nullable | Default | Key | References | Description |
|---|---|---|---|---|---|---|
| `content_id` | bigint | NO | nextval('health_contents_content_id_seq'::regclass) | PK |  |  |
| `title` | character varying | NO |  |  |  |  |
| `type` | content_type | YES |  |  |  |  |
| `thumbnail_url` | character varying | YES |  |  |  |  |
| `resource_url` | character varying | YES |  |  |  |  |
| `description` | text | YES |  |  |  |  |
| `category_tag` | character varying | YES |  |  |  |  |
| `difficulty_level` | character varying | YES |  |  |  |  |
| `is_published` | boolean | YES | true |  |  |  |
| `created_at` | timestamp with time zone | YES | now() |  |  |  |

Indexes:

| Index | Definition |
|---|---|
| `health_contents_pkey` | `CREATE UNIQUE INDEX health_contents_pkey ON cleangoal.health_contents USING btree (content_id)` |

### `notifications`

- Type: BASE TABLE
- Current rows: 22
- RLS enabled: yes
- Description: System alerts, achievements, content updates, and announcements.
- Primary key: `notification_id`
- Foreign keys: `user_id` -> `users.user_id` (CASCADE)

| Column | Type | Nullable | Default | Key | References | Description |
|---|---|---|---|---|---|---|
| `notification_id` | bigint | NO | nextval('notifications_notification_id_seq'::regclass) | PK |  |  |
| `user_id` | bigint | YES |  | FK | `users.user_id` |  |
| `title` | character varying(200) | NO |  |  |  |  |
| `message` | text | YES |  |  |  |  |
| `type` | notification_type | YES |  |  |  |  |
| `is_read` | boolean | YES | false |  |  |  |
| `created_at` | timestamp with time zone | YES | now() |  |  |  |

Indexes:

| Index | Definition |
|---|---|
| `idx_notifications_user_id` | `CREATE INDEX idx_notifications_user_id ON cleangoal.notifications USING btree (user_id, created_at DESC)` |
| `idx_notifications_user_unread` | `CREATE INDEX idx_notifications_user_unread ON cleangoal.notifications USING btree (user_id, is_read) WHERE (is_read = false)` |
| `notifications_pkey` | `CREATE UNIQUE INDEX notifications_pkey ON cleangoal.notifications USING btree (notification_id)` |

### `user_favorites`

- Type: BASE TABLE
- Current rows: 20
- RLS enabled: yes
- Description: User favorite food mapping.
- Primary key: `id`
- Unique constraints: `user_favorites_user_id_food_id_key` (user_id, food_id)
- Foreign keys: `food_id` -> `foods.food_id` (CASCADE); `user_id` -> `users.user_id` (CASCADE)

| Column | Type | Nullable | Default | Key | References | Description |
|---|---|---|---|---|---|---|
| `id` | bigint | NO | nextval('user_favorites_id_seq'::regclass) | PK |  |  |
| `user_id` | bigint | NO |  | FK | `users.user_id` |  |
| `food_id` | bigint | NO |  | FK | `foods.food_id` |  |
| `created_at` | timestamp with time zone | YES | now() |  |  |  |

Indexes:

| Index | Definition |
|---|---|
| `user_favorites_pkey` | `CREATE UNIQUE INDEX user_favorites_pkey ON cleangoal.user_favorites USING btree (id)` |
| `user_favorites_user_id_food_id_key` | `CREATE UNIQUE INDEX user_favorites_user_id_food_id_key ON cleangoal.user_favorites USING btree (user_id, food_id)` |

## Gamification

### `user_gamification`

- Type: BASE TABLE
- Current rows: 11
- RLS enabled: yes
- Description: User gamification state such as points, levels, streaks, badges, and pet/status progression.
- Primary key: `user_id`
- Foreign keys: `user_id` -> `users.user_id` (CASCADE)

| Column | Type | Nullable | Default | Key | References | Description |
|---|---|---|---|---|---|---|
| `user_id` | integer | NO |  | PK, FK | `users.user_id` |  |
| `tama_points` | integer | NO | 0 |  |  |  |
| `tier_level` | smallint | NO | 0 |  |  |  |
| `updated_at` | timestamp with time zone | NO | now() |  |  |  |
| `claimed_badges` | ARRAY | YES | '{}'::text[] |  |  |  |

Indexes:

| Index | Definition |
|---|---|
| `user_gamification_pkey` | `CREATE UNIQUE INDEX user_gamification_pkey ON cleangoal.user_gamification USING btree (user_id)` |

## Migration / Archive / Audit Support

### `food_ingredients_archive`

- Type: BASE TABLE
- Current rows: 0
- RLS enabled: no
- Description: Archive of food ingredient data before restoration/normalization.

| Column | Type | Nullable | Default | Key | References | Description |
|---|---|---|---|---|---|---|
| `food_ing_id` | bigint | YES |  |  |  |  |
| `food_id` | bigint | YES |  |  |  |  |
| `ingredient_id` | bigint | YES |  |  |  |  |
| `amount` | numeric(6,2) | YES |  |  |  |  |
| `unit_id` | integer | YES |  |  |  |  |
| `calculated_grams` | numeric(6,2) | YES |  |  |  |  |
| `note` | character varying | YES |  |  |  |  |

### `food_requests_archive`

- Type: BASE TABLE
- Current rows: 0
- RLS enabled: no
- Description: Archive of legacy food request data.

| Column | Type | Nullable | Default | Key | References | Description |
|---|---|---|---|---|---|---|
| `request_id` | bigint | YES |  |  |  |  |
| `user_id` | bigint | YES |  |  |  |  |
| `food_name` | character varying(200) | YES |  |  |  |  |
| `status` | request_status | YES |  |  |  |  |
| `ingredients_json` | jsonb | YES |  |  |  |  |
| `reviewed_by` | bigint | YES |  |  |  |  |
| `created_at` | timestamp with time zone | YES |  |  |  |  |

### `ingredients_archive`

- Type: BASE TABLE
- Current rows: 0
- RLS enabled: no
- Description: Archive of ingredient data before restoration/normalization.

| Column | Type | Nullable | Default | Key | References | Description |
|---|---|---|---|---|---|---|
| `ingredient_id` | bigint | YES |  |  |  |  |
| `name` | character varying(150) | YES |  |  |  |  |
| `category` | character varying(50) | YES |  |  |  |  |
| `default_unit_id` | integer | YES |  |  |  |  |
| `calories_per_unit` | numeric(6,2) | YES |  |  |  |  |
| `created_at` | timestamp with time zone | YES |  |  |  |  |

### `recipe_relation_orphan_archive`

- Type: BASE TABLE
- Current rows: 100
- RLS enabled: yes
- Description: Migration archive for orphaned recipe relation rows.
- Primary key: `archive_id`

| Column | Type | Nullable | Default | Key | References | Description |
|---|---|---|---|---|---|---|
| `archive_id` | bigint | NO | nextval('recipe_relation_orphan_archive_archive_id_seq'::regclass) | PK |  |  |
| `source_table` | character varying(80) | NO |  |  |  |  |
| `source_pk` | bigint | YES |  |  |  |  |
| `legacy_recipe_id` | bigint | YES |  |  |  |  |
| `legacy_user_id` | bigint | YES |  |  |  |  |
| `row_data` | jsonb | NO |  |  |  |  |
| `archive_reason` | text | NO |  |  |  |  |
| `archived_at` | timestamp with time zone | NO | now() |  |  |  |

Indexes:

| Index | Definition |
|---|---|
| `recipe_relation_orphan_archive_pkey` | `CREATE UNIQUE INDEX recipe_relation_orphan_archive_pkey ON cleangoal.recipe_relation_orphan_archive USING btree (archive_id)` |

### `recipe_reviews_orphan_archive`

- Type: BASE TABLE
- Current rows: 20
- RLS enabled: yes
- Description: Migration archive for orphaned recipe reviews.
- Primary key: `archive_id`

| Column | Type | Nullable | Default | Key | References | Description |
|---|---|---|---|---|---|---|
| `archive_id` | bigint | NO | nextval('recipe_reviews_orphan_archive_archive_id_seq'::regclass) | PK |  |  |
| `review_id` | bigint | YES |  |  |  |  |
| `legacy_recipe_id` | bigint | YES |  |  |  |  |
| `legacy_food_id` | bigint | YES |  |  |  |  |
| `user_id` | bigint | YES |  |  |  |  |
| `rating` | smallint | YES |  |  |  |  |
| `comment` | text | YES |  |  |  |  |
| `created_at` | timestamp with time zone | YES |  |  |  |  |
| `archived_at` | timestamp with time zone | NO | now() |  |  |  |
| `archive_reason` | text | NO |  |  |  |  |

Indexes:

| Index | Definition |
|---|---|
| `recipe_reviews_orphan_archive_pkey` | `CREATE UNIQUE INDEX recipe_reviews_orphan_archive_pkey ON cleangoal.recipe_reviews_orphan_archive USING btree (archive_id)` |

### `schema_migrations`

- Type: BASE TABLE
- Current rows: 28
- RLS enabled: yes
- Description: Applied migration ledger for the cleangoal schema.
- Primary key: `version`

| Column | Type | Nullable | Default | Key | References | Description |
|---|---|---|---|---|---|---|
| `version` | character varying(255) | NO |  | PK |  |  |
| `applied_at` | timestamp with time zone | YES | CURRENT_TIMESTAMP |  |  |  |

Indexes:

| Index | Definition |
|---|---|
| `schema_migrations_pkey` | `CREATE UNIQUE INDEX schema_migrations_pkey ON cleangoal.schema_migrations USING btree (version)` |

### `unit_conversion_orphan_archive`

- Type: BASE TABLE
- Current rows: 19
- RLS enabled: yes
- Description: Migration archive for orphaned unit conversion rows.
- Primary key: `archive_id`

| Column | Type | Nullable | Default | Key | References | Description |
|---|---|---|---|---|---|---|
| `archive_id` | bigint | NO | nextval('unit_conversion_orphan_archive_archive_id_seq'::regclass) | PK |  |  |
| `conversion_id` | integer | YES |  |  |  |  |
| `from_unit_id` | integer | YES |  |  |  |  |
| `to_unit_id` | integer | YES |  |  |  |  |
| `row_data` | jsonb | NO |  |  |  |  |
| `archive_reason` | text | NO |  |  |  |  |
| `archived_at` | timestamp with time zone | NO | now() |  |  |  |

Indexes:

| Index | Definition |
|---|---|
| `unit_conversion_orphan_archive_pkey` | `CREATE UNIQUE INDEX unit_conversion_orphan_archive_pkey ON cleangoal.unit_conversion_orphan_archive USING btree (archive_id)` |

## Other / Extension

### `v_admin_temp_food_review`

- Type: VIEW
- RLS enabled: no
- Description: Admin review view combining temp food and reviewer/user data.

| Column | Type | Nullable | Default | Key | References | Description |
|---|---|---|---|---|---|---|
| `tf_id` | bigint | YES |  |  |  |  |
| `food_name` | character varying(200) | YES |  |  |  |  |
| `protein` | numeric(6,2) | YES |  |  |  |  |
| `fat` | numeric(6,2) | YES |  |  |  |  |
| `carbs` | numeric(6,2) | YES |  |  |  |  |
| `calories` | numeric(6,2) | YES |  |  |  |  |
| `submitted_by` | bigint | YES |  |  |  |  |
| `submitted_by_username` | character varying(50) | YES |  |  |  |  |
| `submitted_at` | timestamp with time zone | YES |  |  |  |  |
| `last_edited_at` | timestamp with time zone | YES |  |  |  |  |
| `vf_id` | bigint | YES |  |  |  |  |
| `is_verify` | boolean | YES |  |  |  |  |
| `verified_by` | bigint | YES |  |  |  |  |
| `verified_at` | timestamp with time zone | YES |  |  |  |  |

### `v_food_ingredient_nutrition_totals`

- Type: VIEW
- RLS enabled: no
- Description: View that totals nutrition from food ingredient composition.

| Column | Type | Nullable | Default | Key | References | Description |
|---|---|---|---|---|---|---|
| `food_id` | bigint | YES |  |  |  |  |
| `food_name` | character varying(200) | YES |  |  |  |  |
| `ingredient_count` | integer | YES |  |  |  |  |
| `total_calories` | numeric | YES |  |  |  |  |
| `total_protein` | numeric | YES |  |  |  |  |
| `total_carbs` | numeric | YES |  |  |  |  |
| `total_fat` | numeric | YES |  |  |  |  |

### `v_food_recipes`

- Type: VIEW
- RLS enabled: no
- Description: Read model exposing the logical food_recipe relationship. Current physical schema is recipes.food_id because each food has at most one active recipe.

| Column | Type | Nullable | Default | Key | References | Description |
|---|---|---|---|---|---|---|
| `food_id` | bigint | YES |  |  |  |  |
| `food_name` | character varying(200) | YES |  |  |  |  |
| `food_type` | food_type | YES |  |  |  |  |
| `calories` | numeric(6,2) | YES |  |  |  |  |
| `protein` | numeric(6,2) | YES |  |  |  |  |
| `carbs` | numeric(6,2) | YES |  |  |  |  |
| `fat` | numeric(6,2) | YES |  |  |  |  |
| `recipe_id` | bigint | YES |  |  |  |  |
| `description` | character varying | YES |  |  |  |  |
| `instructions` | text | YES |  |  |  |  |
| `prep_time_minutes` | integer | YES |  |  |  |  |
| `cooking_time_minutes` | integer | YES |  |  |  |  |
| `serving_people` | numeric(3,1) | YES |  |  |  |  |
| `generated_by` | character varying(32) | YES |  |  |  |  |
| `recipe_created_at` | timestamp with time zone | YES |  |  |  |  |
| `recipe_deleted_at` | timestamp with time zone | YES |  |  |  |  |

### `v_recipe_ingredients_nutrition`

- Type: VIEW
- RLS enabled: no
- Description: View that calculates recipe ingredient nutrition from quantities and units.

| Column | Type | Nullable | Default | Key | References | Description |
|---|---|---|---|---|---|---|
| `recipe_id` | bigint | YES |  |  |  |  |
| `food_id` | bigint | YES |  |  |  |  |
| `food_name` | character varying(200) | YES |  |  |  |  |
| `ing_id` | bigint | YES |  |  |  |  |
| `food_ing_id` | bigint | YES |  |  |  |  |
| `ingredient_id` | bigint | YES |  |  |  |  |
| `ingredient_name` | character varying | YES |  |  |  |  |
| `quantity` | numeric | YES |  |  |  |  |
| `unit` | character varying | YES |  |  |  |  |
| `is_optional` | boolean | YES |  |  |  |  |
| `note` | character varying | YES |  |  |  |  |
| `sort_order` | integer | YES |  |  |  |  |
| `calculated_grams` | numeric(10,2) | YES |  |  |  |  |
| `calculated_calories` | numeric | YES |  |  |  |  |
| `calculated_protein` | numeric | YES |  |  |  |  |
| `calculated_carbs` | numeric | YES |  |  |  |  |
| `calculated_fat` | numeric | YES |  |  |  |  |

## Views

### `v_admin_temp_food_review`

| Column | Type | Nullable | Description |
|---|---|---|---|
| `tf_id` | bigint | YES |  |
| `food_name` | character varying | YES |  |
| `protein` | numeric | YES |  |
| `fat` | numeric | YES |  |
| `carbs` | numeric | YES |  |
| `calories` | numeric | YES |  |
| `submitted_by` | bigint | YES |  |
| `submitted_by_username` | character varying | YES |  |
| `submitted_at` | timestamp with time zone | YES |  |
| `last_edited_at` | timestamp with time zone | YES |  |
| `vf_id` | bigint | YES |  |
| `is_verify` | boolean | YES |  |
| `verified_by` | bigint | YES |  |
| `verified_at` | timestamp with time zone | YES |  |

<details>
<summary>View definition</summary>

```sql
SELECT tf.tf_id,
    tf.food_name,
    tf.protein,
    tf.fat,
    tf.carbs,
    tf.calories,
    tf.user_id AS submitted_by,
    u.username AS submitted_by_username,
    tf.created_at AS submitted_at,
    tf.updated_at AS last_edited_at,
    vf.vf_id,
    vf.is_verify,
    vf.verified_by,
    vf.verified_at
   FROM ((temp_food tf
     LEFT JOIN verified_food vf ON ((vf.tf_id = tf.tf_id)))
     LEFT JOIN users u ON ((u.user_id = tf.user_id)));
```

</details>

### `v_food_ingredient_nutrition_totals`

| Column | Type | Nullable | Description |
|---|---|---|---|
| `food_id` | bigint | YES |  |
| `food_name` | character varying | YES |  |
| `ingredient_count` | integer | YES |  |
| `total_calories` | numeric | YES |  |
| `total_protein` | numeric | YES |  |
| `total_carbs` | numeric | YES |  |
| `total_fat` | numeric | YES |  |

<details>
<summary>View definition</summary>

```sql
SELECT f.food_id,
    f.food_name,
    (count(fi.food_ing_id))::integer AS ingredient_count,
    round(sum(
        CASE
            WHEN ((i.calories_per_100g IS NOT NULL) AND (fi.calculated_grams IS NOT NULL)) THEN ((i.calories_per_100g * fi.calculated_grams) / (100)::numeric)
            WHEN (i.calories_per_unit IS NOT NULL) THEN (i.calories_per_unit * fi.amount)
            ELSE (0)::numeric
        END), 2) AS total_calories,
    round(sum(
        CASE
            WHEN ((i.protein_per_100g IS NOT NULL) AND (fi.calculated_grams IS NOT NULL)) THEN ((i.protein_per_100g * fi.calculated_grams) / (100)::numeric)
            ELSE (0)::numeric
        END), 2) AS total_protein,
    round(sum(
        CASE
            WHEN ((i.carbs_per_100g IS NOT NULL) AND (fi.calculated_grams IS NOT NULL)) THEN ((i.carbs_per_100g * fi.calculated_grams) / (100)::numeric)
            ELSE (0)::numeric
        END), 2) AS total_carbs,
    round(sum(
        CASE
            WHEN ((i.fat_per_100g IS NOT NULL) AND (fi.calculated_grams IS NOT NULL)) THEN ((i.fat_per_100g * fi.calculated_grams) / (100)::numeric)
            ELSE (0)::numeric
        END), 2) AS total_fat
   FROM (((foods f
     JOIN food_ingredients fi ON ((fi.food_id = f.food_id)))
     JOIN ingredients i ON ((i.ingredient_id = fi.ingredient_id)))
     LEFT JOIN units basis_u ON ((basis_u.unit_id = i.nutrition_basis_unit_id)))
  GROUP BY f.food_id, f.food_name;
```

</details>

### `v_food_recipes`

| Column | Type | Nullable | Description |
|---|---|---|---|
| `food_id` | bigint | YES |  |
| `food_name` | character varying | YES |  |
| `food_type` | food_type | YES |  |
| `calories` | numeric | YES |  |
| `protein` | numeric | YES |  |
| `carbs` | numeric | YES |  |
| `fat` | numeric | YES |  |
| `recipe_id` | bigint | YES |  |
| `description` | character varying | YES |  |
| `instructions` | text | YES |  |
| `prep_time_minutes` | integer | YES |  |
| `cooking_time_minutes` | integer | YES |  |
| `serving_people` | numeric | YES |  |
| `generated_by` | character varying | YES |  |
| `recipe_created_at` | timestamp with time zone | YES |  |
| `recipe_deleted_at` | timestamp with time zone | YES |  |

<details>
<summary>View definition</summary>

```sql
SELECT f.food_id,
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
   FROM (foods f
     LEFT JOIN recipes r ON (((r.food_id = f.food_id) AND (r.deleted_at IS NULL))))
  WHERE (f.deleted_at IS NULL);
```

</details>

### `v_recipe_ingredients_nutrition`

| Column | Type | Nullable | Description |
|---|---|---|---|
| `recipe_id` | bigint | YES |  |
| `food_id` | bigint | YES |  |
| `food_name` | character varying | YES |  |
| `ing_id` | bigint | YES |  |
| `food_ing_id` | bigint | YES |  |
| `ingredient_id` | bigint | YES |  |
| `ingredient_name` | character varying | YES |  |
| `quantity` | numeric | YES |  |
| `unit` | character varying | YES |  |
| `is_optional` | boolean | YES |  |
| `note` | character varying | YES |  |
| `sort_order` | integer | YES |  |
| `calculated_grams` | numeric | YES |  |
| `calculated_calories` | numeric | YES |  |
| `calculated_protein` | numeric | YES |  |
| `calculated_carbs` | numeric | YES |  |
| `calculated_fat` | numeric | YES |  |

<details>
<summary>View definition</summary>

```sql
SELECT r.recipe_id,
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
    (x.grams)::numeric(10,2) AS calculated_grams,
    round(COALESCE(ri.calculated_calories,
        CASE
            WHEN ((i.calories_per_100g IS NOT NULL) AND (x.grams IS NOT NULL)) THEN ((i.calories_per_100g * x.grams) / (100)::numeric)
            WHEN (i.calories_per_unit IS NOT NULL) THEN (i.calories_per_unit * COALESCE(ri.quantity, fi.amount, (1)::numeric))
            ELSE NULL::numeric
        END), 2) AS calculated_calories,
    round(COALESCE(ri.calculated_protein,
        CASE
            WHEN ((i.protein_per_100g IS NOT NULL) AND (x.grams IS NOT NULL)) THEN ((i.protein_per_100g * x.grams) / (100)::numeric)
            ELSE NULL::numeric
        END), 2) AS calculated_protein,
    round(COALESCE(ri.calculated_carbs,
        CASE
            WHEN ((i.carbs_per_100g IS NOT NULL) AND (x.grams IS NOT NULL)) THEN ((i.carbs_per_100g * x.grams) / (100)::numeric)
            ELSE NULL::numeric
        END), 2) AS calculated_carbs,
    round(COALESCE(ri.calculated_fat,
        CASE
            WHEN ((i.fat_per_100g IS NOT NULL) AND (x.grams IS NOT NULL)) THEN ((i.fat_per_100g * x.grams) / (100)::numeric)
            ELSE NULL::numeric
        END), 2) AS calculated_fat
   FROM (((((((recipe_ingredients ri
     JOIN recipes r ON ((r.recipe_id = ri.recipe_id)))
     JOIN foods f ON ((f.food_id = r.food_id)))
     LEFT JOIN food_ingredients fi ON ((fi.food_ing_id = ri.food_ing_id)))
     LEFT JOIN ingredients i ON ((i.ingredient_id = COALESCE(ri.ingredient_id, fi.ingredient_id))))
     LEFT JOIN units u ON ((u.unit_id = COALESCE(ri.unit_id, fi.unit_id))))
     LEFT JOIN units basis_u ON ((basis_u.unit_id = i.nutrition_basis_unit_id)))
     LEFT JOIN LATERAL ( SELECT COALESCE(ri.calculated_grams, fi.calculated_grams,
                CASE
                    WHEN ((COALESCE(ri.unit_id, fi.unit_id) = i.nutrition_basis_unit_id) AND (i.nutrition_basis_quantity > (0)::numeric)) THEN ((COALESCE(ri.quantity, fi.amount) * (100)::numeric) / i.nutrition_basis_quantity)
                    ELSE NULL::numeric
                END) AS grams) x ON (true));
```

</details>

## Foreign Key Catalogue

| # | Child | Parent | On update | On delete | Constraint |
|---:|---|---|---|---|---|
| 1 | `beverages.food_id` | `foods.food_id` | NO ACTION | NO ACTION | `beverages_food_id_fkey` |
| 2 | `daily_summaries.user_id` | `users.user_id` | NO ACTION | CASCADE | `daily_summaries_user_id_fkey` |
| 3 | `detail_items.food_version_id` | `food_versions.food_version_id` | NO ACTION | SET NULL | `detail_items_food_version_id_fkey` |
| 4 | `detail_items.meal_id` | `meals.meal_id` | NO ACTION | CASCADE | `detail_items_meal_id_fkey` |
| 5 | `detail_items.summary_id` | `daily_summaries.summary_id` | NO ACTION | CASCADE | `detail_items_summary_id_fkey` |
| 6 | `detail_items.unit_id` | `units.unit_id` | NO ACTION | SET NULL | `detail_items_unit_id_fkey` |
| 7 | `detail_items.food_id` | `foods.food_id` | NO ACTION | SET NULL | `fk_detail_items_food` |
| 8 | `detail_items.plan_id` | `user_meal_plans.plan_id` | NO ACTION | CASCADE | `fk_detail_items_plan` |
| 9 | `dishes.dish_category_id` | `dish_categories.dish_category_id` | NO ACTION | RESTRICT | `dishes_dish_category_id_fkey` |
| 10 | `email_verification_codes.user_id` | `users.user_id` | NO ACTION | CASCADE | `email_verification_codes_user_id_fkey` |
| 11 | `exercise_logs.user_id` | `users.user_id` | NO ACTION | CASCADE | `exercise_logs_user_id_fkey` |
| 12 | `food_allergy_flags.flag_id` | `allergy_flags.flag_id` | NO ACTION | CASCADE | `faf_flag_id_fkey` |
| 13 | `food_allergy_flags.food_id` | `foods.food_id` | NO ACTION | CASCADE | `faf_food_id_fkey` |
| 14 | `food_ingredients.food_id` | `foods.food_id` | NO ACTION | CASCADE | `food_ingredients_food_id_fkey` |
| 15 | `food_ingredients.ingredient_id` | `ingredients.ingredient_id` | NO ACTION | RESTRICT | `food_ingredients_ingredient_id_fkey` |
| 16 | `food_ingredients.unit_id` | `units.unit_id` | NO ACTION | SET NULL | `food_ingredients_unit_id_fkey` |
| 17 | `food_regional_name_submissions.food_id` | `foods.food_id` | NO ACTION | CASCADE | `food_regional_name_submissions_food_id_fkey` |
| 18 | `food_regional_name_submissions.reviewed_by` | `users.user_id` | NO ACTION | SET NULL | `food_regional_name_submissions_reviewed_by_fkey` |
| 19 | `food_regional_name_submissions.user_id` | `users.user_id` | NO ACTION | CASCADE | `food_regional_name_submissions_user_id_fkey` |
| 20 | `food_regional_names.approved_by` | `users.user_id` | NO ACTION | SET NULL | `food_regional_names_approved_by_fkey` |
| 21 | `food_regional_names.created_by` | `users.user_id` | NO ACTION | SET NULL | `food_regional_names_created_by_fkey` |
| 22 | `food_regional_names.food_id` | `foods.food_id` | NO ACTION | CASCADE | `food_regional_names_food_id_fkey` |
| 23 | `food_regional_popularity.food_id` | `foods.food_id` | NO ACTION | CASCADE | `food_regional_popularity_food_id_fkey` |
| 24 | `food_versions.created_by` | `users.user_id` | NO ACTION | SET NULL | `food_versions_created_by_fkey` |
| 25 | `food_versions.dish_id` | `dishes.dish_id` | NO ACTION | SET NULL | `food_versions_dish_id_fkey` |
| 26 | `food_versions.food_id` | `foods.food_id` | NO ACTION | CASCADE | `food_versions_food_id_fkey` |
| 27 | `food_versions.serving_unit_id` | `units.unit_id` | NO ACTION | SET NULL | `food_versions_serving_unit_id_fkey` |
| 28 | `foods.current_version_id` | `food_versions.food_version_id` | NO ACTION | SET NULL | `foods_current_version_id_fkey` |
| 29 | `foods.dish_id` | `dishes.dish_id` | NO ACTION | SET NULL | `foods_dish_id_fkey` |
| 30 | `foods.serving_unit_id` | `units.unit_id` | NO ACTION | SET NULL | `foods_serving_unit_id_fkey` |
| 31 | `ingredient_unit_conversions.from_unit_id` | `units.unit_id` | NO ACTION | RESTRICT | `ingredient_unit_conversions_from_unit_id_fkey` |
| 32 | `ingredient_unit_conversions.ingredient_id` | `ingredients.ingredient_id` | NO ACTION | CASCADE | `ingredient_unit_conversions_ingredient_id_fkey` |
| 33 | `ingredient_unit_conversions.to_unit_id` | `units.unit_id` | NO ACTION | RESTRICT | `ingredient_unit_conversions_to_unit_id_fkey` |
| 34 | `ingredients.default_unit_id` | `units.unit_id` | NO ACTION | SET NULL | `ingredients_default_unit_id_fkey` |
| 35 | `ingredients.nutrition_basis_unit_id` | `units.unit_id` | NO ACTION | SET NULL | `ingredients_nutrition_basis_unit_id_fkey` |
| 36 | `meals.user_id` | `users.user_id` | NO ACTION | CASCADE | `fk_meals_user` |
| 37 | `notifications.user_id` | `users.user_id` | NO ACTION | CASCADE | `notifications_user_id_fkey` |
| 38 | `password_reset_codes.user_id` | `users.user_id` | NO ACTION | CASCADE | `password_reset_codes_user_id_fkey` |
| 39 | `recipe_favorites.recipe_id` | `recipes.recipe_id` | NO ACTION | CASCADE | `recipe_favorites_recipe_id_fkey` |
| 40 | `recipe_favorites.user_id` | `users.user_id` | NO ACTION | CASCADE | `recipe_favorites_user_id_fkey` |
| 41 | `recipe_ingredients.food_ing_id` | `food_ingredients.food_ing_id` | NO ACTION | SET NULL | `recipe_ingredients_food_ing_id_fkey` |
| 42 | `recipe_ingredients.ingredient_id` | `ingredients.ingredient_id` | NO ACTION | SET NULL | `recipe_ingredients_ingredient_id_fkey` |
| 43 | `recipe_ingredients.recipe_id` | `recipes.recipe_id` | NO ACTION | CASCADE | `recipe_ingredients_recipe_id_fkey` |
| 44 | `recipe_ingredients.unit_id` | `units.unit_id` | NO ACTION | SET NULL | `recipe_ingredients_unit_id_fkey` |
| 45 | `recipe_reviews.recipe_id` | `recipes.recipe_id` | NO ACTION | CASCADE | `recipe_reviews_recipe_id_fkey` |
| 46 | `recipe_reviews.user_id` | `users.user_id` | NO ACTION | CASCADE | `recipe_reviews_user_id_fkey` |
| 47 | `recipe_steps.recipe_id` | `recipes.recipe_id` | NO ACTION | CASCADE | `recipe_steps_recipe_id_fkey` |
| 48 | `recipe_tips.recipe_id` | `recipes.recipe_id` | NO ACTION | CASCADE | `recipe_tips_recipe_id_fkey` |
| 49 | `recipe_tools.recipe_id` | `recipes.recipe_id` | NO ACTION | CASCADE | `recipe_tools_recipe_id_fkey` |
| 50 | `recipes.food_id` | `foods.food_id` | NO ACTION | NO ACTION | `recipes_food_id_fkey` |
| 51 | `snacks.food_id` | `foods.food_id` | NO ACTION | NO ACTION | `snacks_food_id_fkey` |
| 52 | `temp_food.user_id` | `users.user_id` | NO ACTION | CASCADE | `temp_food_user_id_fkey` |
| 53 | `unit_conversions.from_unit_id` | `units.unit_id` | NO ACTION | CASCADE | `unit_conversions_from_unit_id_fkey` |
| 54 | `unit_conversions.to_unit_id` | `units.unit_id` | NO ACTION | CASCADE | `unit_conversions_to_unit_id_fkey` |
| 55 | `user_allergy_preferences.flag_id` | `allergy_flags.flag_id` | NO ACTION | CASCADE | `user_allergy_preferences_flag_id_fkey` |
| 56 | `user_allergy_preferences.user_id` | `users.user_id` | NO ACTION | CASCADE | `user_allergy_preferences_user_id_fkey` |
| 57 | `user_favorites.food_id` | `foods.food_id` | NO ACTION | CASCADE | `user_favorites_food_id_fkey` |
| 58 | `user_favorites.user_id` | `users.user_id` | NO ACTION | CASCADE | `user_favorites_user_id_fkey` |
| 59 | `user_gamification.user_id` | `users.user_id` | NO ACTION | CASCADE | `user_gamification_user_id_fkey` |
| 60 | `user_meal_plans.user_id` | `users.user_id` | NO ACTION | SET NULL | `user_meal_plans_user_id_fkey` |
| 61 | `users.role_id` | `roles.role_id` | NO ACTION | NO ACTION | `users_role_id_fkey` |
| 62 | `verified_food.tf_id` | `temp_food.tf_id` | NO ACTION | CASCADE | `verified_food_tf_id_fkey` |
| 63 | `verified_food.verified_by` | `users.user_id` | NO ACTION | SET NULL | `verified_food_verified_by_fkey` |
| 64 | `water_logs.user_id` | `users.user_id` | NO ACTION | CASCADE | `water_logs_user_id_fkey` |
| 65 | `weight_logs.user_id` | `users.user_id` | NO ACTION | CASCADE | `weight_logs_user_id_fkey` |

## Notes For Developers

- Treat `foods` as mutable catalog data and `food_versions`/`detail_items.food_snapshot` as immutable user-history protection.
- Treat `ingredients` as a strong entity. Nutrition calculation should use `ingredients`, `units`, `ingredient_unit_conversions`, `food_ingredients`, and `recipe_ingredients` where data is available.
- Do not hard-delete catalog data used by logs. Use soft delete/versioning so user history remains reproducible.
- Archive tables are included because they exist in live schema, but app features should not normally depend on them.
