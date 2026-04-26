DROP TABLE IF EXISTS notification_reads, user_saved_contents, content_view_logs, user_achievements,
           daily_recommendations, user_reports, weight_logs, detail_items, user_active_plans,
           user_meal_plans, meals, daily_summaries, dishes, recipes, snacks, beverages,
           food_ingredients, food_sources, food_allergy_flags, favorite_foods,
           user_allergy_preferences, progress, user_goals, user_activities,
           admin_audit_logs, food_requests, weekly_summaries, monthly_summaries,
           recommendation_plan, foods, ingredients, units, allergy_flags, roles,
           users, achievements, health_contents, notifications CASCADE;

-- ลบ Enum Types
DROP TYPE IF EXISTS goal_type_enum, activity_level, content_type, food_type,
           gender_type, meal_type, notification_type, request_status CASCADE;

-- ==========================================
-- 🧱 1. ENUMS
-- ==========================================
CREATE TYPE goal_type_enum AS ENUM ('lose_weight', 'maintain_weight', 'gain_muscle');
CREATE TYPE activity_level AS ENUM ('sedentary', 'lightly_active', 'moderately_active', 'very_active');
CREATE TYPE content_type AS ENUM ('article', 'video');
CREATE TYPE food_type AS ENUM ('raw_ingredient', 'recipe_dish');
CREATE TYPE gender_type AS ENUM ('male', 'female');
CREATE TYPE meal_type AS ENUM ('breakfast', 'lunch', 'dinner', 'snack');
CREATE TYPE notification_type AS ENUM ('system_alert', 'achievement', 'content_update', 'system_announcement');
CREATE TYPE request_status AS ENUM ('pending', 'approved', 'rejected');

-- ==========================================
-- 👤 2. MODULE: Identity & Roles
-- ==========================================
CREATE TABLE roles (
    role_id SERIAL PRIMARY KEY,
    role_name VARCHAR UNIQUE NOT NULL
);

CREATE TABLE users (
    user_id BIGSERIAL PRIMARY KEY,
    username VARCHAR,
    email VARCHAR UNIQUE NOT NULL,
    password_hash VARCHAR NOT NULL,
    gender gender_type,
    birth_date DATE,
    height_cm DECIMAL(5,2),
    current_weight_kg DECIMAL(5,2),
    goal_type goal_type_enum,
    target_weight_kg DECIMAL(5,2),
    target_calories INT,
    target_protein INT,
    target_carbs INT,
    target_fat INT,
    activity_level activity_level,
    goal_start_date DATE DEFAULT CURRENT_DATE,
    goal_target_date DATE,
    last_kpi_check_date DATE DEFAULT CURRENT_DATE,
    current_streak INT DEFAULT 0,
    last_login_date TIMESTAMP,
    total_login_days INT DEFAULT 0,
    avatar_url VARCHAR,
    role_id INT DEFAULT 2 REFERENCES roles(role_id),
    is_email_verified BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP,
    deleted_at TIMESTAMP
);

CREATE TABLE IF NOT EXISTS password_reset_codes (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    code VARCHAR(10) NOT NULL,
    expires_at TIMESTAMP NOT NULL,
    used BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS email_verification_codes (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    code VARCHAR(10) NOT NULL,
    expires_at TIMESTAMP NOT NULL,
    used BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT NOW()
);

-- ==========================================
-- 🥗 3. MODULE: Preferences & Allergies
-- ==========================================
CREATE TABLE allergy_flags (
    flag_id SERIAL PRIMARY KEY,
    name VARCHAR NOT NULL,
    description VARCHAR
);

CREATE TABLE user_allergy_preferences (
    user_id BIGINT REFERENCES users(user_id) ON DELETE CASCADE,
    flag_id INT REFERENCES allergy_flags(flag_id) ON DELETE CASCADE,
    preference_type VARCHAR,
    created_at TIMESTAMP DEFAULT NOW(),
    PRIMARY KEY (user_id, flag_id)
);

-- ==========================================
-- 🍳 4. MODULE: Food & Recipes Database
-- ==========================================
CREATE TABLE units (
    unit_id SERIAL PRIMARY KEY,
    name VARCHAR NOT NULL,
    quantity DECIMAL(10,4)
);

CREATE TABLE foods (
    food_id BIGSERIAL PRIMARY KEY,
    food_name VARCHAR NOT NULL,
    food_type food_type DEFAULT 'raw_ingredient',
    calories DECIMAL(6,2),
    protein DECIMAL(6,2),
    carbs DECIMAL(6,2),
    fat DECIMAL(6,2),
    sodium DECIMAL(6,2),
    sugar DECIMAL(6,2),
    cholesterol DECIMAL(6,2),
    serving_quantity DECIMAL(6,2) DEFAULT 100,
    serving_unit VARCHAR DEFAULT 'g',
    image_url VARCHAR,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP,
    deleted_at TIMESTAMP
);

CREATE TABLE ingredients (
    ingredient_id BIGSERIAL PRIMARY KEY,
    name VARCHAR NOT NULL UNIQUE,
    category VARCHAR,
    default_unit_id INT REFERENCES units(unit_id),
    calories_per_unit DECIMAL(6,2),
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE food_ingredients (
    food_ing_id BIGSERIAL PRIMARY KEY,
    food_id BIGINT REFERENCES foods(food_id) ON DELETE CASCADE,
    ingredient_id BIGINT REFERENCES ingredients(ingredient_id),
    amount DECIMAL(6,2),
    unit_id INT REFERENCES units(unit_id),
    calculated_grams DECIMAL(6,2),
    note VARCHAR
);

CREATE TABLE beverages (
    beverage_id BIGSERIAL PRIMARY KEY,
    food_id BIGINT UNIQUE REFERENCES foods(food_id),
    volume_ml DECIMAL(6,2),
    is_alcoholic BOOLEAN DEFAULT FALSE,
    caffeine_mg DECIMAL(6,2) DEFAULT 0,
    sugar_level_label VARCHAR,
    container_type VARCHAR
);

CREATE TABLE snacks (
    snack_id BIGSERIAL PRIMARY KEY,
    food_id BIGINT UNIQUE REFERENCES foods(food_id),
    is_sweet BOOLEAN DEFAULT TRUE,
    packaging_type VARCHAR,
    trans_fat DECIMAL(6,2)
);

CREATE TABLE recipes (
    recipe_id BIGSERIAL PRIMARY KEY,
    food_id BIGINT UNIQUE REFERENCES foods(food_id),
    description VARCHAR,
    instructions TEXT,
    prep_time_minutes INT DEFAULT 0,
    cooking_time_minutes INT DEFAULT 0,
    serving_people DECIMAL(3,1) DEFAULT 1.0,
    source_reference VARCHAR,
    image_url VARCHAR,
    created_at TIMESTAMP DEFAULT NOW(),
    deleted_at TIMESTAMP
);

-- ==========================================
-- 📝 5. MODULE: Logs, Planning & Unified Items
-- ==========================================
CREATE TABLE meals (
    meal_id BIGSERIAL PRIMARY KEY,
    user_id BIGINT REFERENCES users(user_id) ON DELETE CASCADE,
    item_id BIGINT,
    meal_type meal_type,
    meal_time TIMESTAMP DEFAULT NOW(),
    total_amount DECIMAL,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE user_meal_plans (
    plan_id BIGSERIAL PRIMARY KEY,
    user_id BIGINT REFERENCES users(user_id) ON DELETE SET NULL,
    item_id BIGINT,
    name VARCHAR NOT NULL,
    description TEXT,
    source_type VARCHAR DEFAULT 'SYSTEM',
    is_premium BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE daily_summaries (
    summary_id BIGSERIAL PRIMARY KEY,
    user_id BIGINT REFERENCES users(user_id) ON DELETE CASCADE,
    item_id BIGINT,
    date_record DATE DEFAULT CURRENT_DATE,
    total_calories_intake DECIMAL(10,2) DEFAULT 0,
    goal_calories INT,
    is_goal_met BOOLEAN DEFAULT FALSE,
    UNIQUE (user_id, date_record)
);

CREATE TABLE detail_items (
    item_id BIGSERIAL PRIMARY KEY,
    meal_id BIGINT REFERENCES meals(meal_id) ON DELETE CASCADE,
    plan_id BIGINT REFERENCES user_meal_plans(plan_id) ON DELETE CASCADE,
    summary_id BIGINT REFERENCES daily_summaries(summary_id) ON DELETE CASCADE,
    food_id BIGINT REFERENCES foods(food_id),
    food_name VARCHAR,
    day_number INT,
    amount DECIMAL(8,2) DEFAULT 1.0,
    unit_id INT REFERENCES units(unit_id),
    cal_per_unit DECIMAL(10,2),
    note VARCHAR,
    created_at TIMESTAMP DEFAULT NOW()
);

-- ==========================================
-- 🎯 6. MODULE: Goals, Activities & Weight Logs
-- ==========================================
CREATE TABLE user_activities (
    activity_id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    activity_level activity_level NOT NULL,
    is_current BOOLEAN DEFAULT TRUE,
    date_record DATE DEFAULT CURRENT_DATE,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE user_goals (
    goal_id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    goal_name VARCHAR,
    goal_type goal_type_enum NOT NULL,
    target_weight_kg DECIMAL(5,2),
    is_current BOOLEAN DEFAULT TRUE,
    goal_start_at DATE DEFAULT CURRENT_DATE,
    goal_target_date DATE,
    goal_end_at DATE,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE weight_logs (
    log_id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    weight_kg DECIMAL(5,2) NOT NULL,
    recorded_date DATE DEFAULT CURRENT_DATE,
    created_at TIMESTAMP DEFAULT NOW(),
    UNIQUE (user_id, recorded_date)
);

CREATE TABLE progress (
    progress_id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    weight_id BIGINT REFERENCES weight_logs(log_id),
    daily_id BIGINT REFERENCES daily_summaries(summary_id),
    current_streak INT DEFAULT 0,
    weekly_target VARCHAR,
    created_at TIMESTAMP DEFAULT NOW()
);

-- ==========================================
-- 🛡️ 7. MODULE: Admin & Analytics
-- ==========================================
CREATE TABLE food_requests (
    request_id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(user_id),
    food_name VARCHAR NOT NULL,
    status request_status DEFAULT 'pending',
    ingredients_json JSONB,
    reviewed_by BIGINT REFERENCES users(user_id),
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE weekly_summaries (
    weekly_id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    start_date DATE NOT NULL,
    avg_daily_calories INT,
    days_logged_count INT,
    UNIQUE (user_id, start_date)
);

-- ==========================================
-- 🏆 8. MODULE: Notifications & Content
-- ==========================================
CREATE TABLE notifications (
    notification_id BIGSERIAL PRIMARY KEY,
    user_id BIGINT REFERENCES users(user_id) ON DELETE CASCADE,
    title VARCHAR NOT NULL,
    message TEXT,
    type notification_type,
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE health_contents (
    content_id BIGSERIAL PRIMARY KEY,
    title VARCHAR NOT NULL,
    type content_type,
    thumbnail_url VARCHAR,
    resource_url VARCHAR,
    description TEXT,
    category_tag VARCHAR,
    difficulty_level VARCHAR,
    is_published BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT NOW()
);

-- ==========================================
-- 📌 9. SEED DATA (ข้อมูลเริ่มต้น)
-- ==========================================
INSERT INTO roles (role_id, role_name) VALUES
    (1, 'admin'),
    (2, 'user')
ON CONFLICT (role_name) DO NOTHING;

-- เลือก set sequence ให้ role_id เริ่มจาก 3 ถ้ามีการ insert ใหม่
SELECT setval('roles_role_id_seq', (SELECT COALESCE(MAX(role_id), 2) FROM roles));

