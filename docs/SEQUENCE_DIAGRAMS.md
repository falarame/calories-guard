# Calories Guard — Sequence Diagrams

**Generated:** 2026-04-26 (หลัง v24 + Supabase auth fix)
**ภาษา:** ไทย
**Scope:** ครอบคลุมทุก flow หลักของแอป (auth, food, tracking, AI, admin)

หมายเหตุ:
- `Flutter` = mobile + web client (`flutter_application_1`)
- `API` = FastAPI backend (`backend/app`)
- `DB` = Supabase Postgres schema `cleangoal`
- `Supabase` = Supabase Auth + Storage
- `Ollama` = self-hosted LLM proxy (DeepSeek หรือ local model)

## สารบัญ

### Authentication
1. [Register + Email Verification](#1-register--email-verification)
2. [Login (Email/Password)](#2-login-emailpassword)
3. [Login (Supabase Social / Web)](#3-login-supabase-social--web)
4. [Password Reset](#4-password-reset)

### Food & Meal Logging
5. [Search Food (with Regional Names)](#5-search-food-with-regional-names)
6. [Record Meal → Auto Daily Summary](#6-record-meal--auto-daily-summary)
7. [Submit New Food (temp_food → admin)](#7-submit-new-food-temp_food--admin)
8. [Submit Regional Name (variant → admin)](#8-submit-regional-name-variant--admin)
9. [View Recipe Detail + Review](#9-view-recipe-detail--review)

### Tracking
10. [Water Log (1 row/day)](#10-water-log-1-rowday)
11. [Weight Log + Goal Progress](#11-weight-log--goal-progress)

### AI / Coach
12. [Chat Coach (Ollama Proxy)](#12-chat-coach-ollama-proxy)
13. [Meal Estimation from Photo](#13-meal-estimation-from-photo)

### User Profile
14. [Update Profile + Recalc TDEE](#14-update-profile--recalc-tdee)
15. [Set User Region (v20)](#15-set-user-region-v20)
16. [PDPA Soft-Delete Account](#16-pdpa-soft-delete-account)

### Admin
17. [Approve temp_food](#17-approve-temp_food)
18. [Approve/Reject Regional Name Submission](#18-approvereject-regional-name-submission)

### Notifications
19. [Login Streak → Notification](#19-login-streak--notification)

---

## 1. Register + Email Verification

```mermaid
sequenceDiagram
    autonumber
    actor U as User
    participant F as Flutter
    participant A as API /auth
    participant DB as DB cleangoal
    participant SMTP as SMTP / Supabase Email

    U->>F: กรอก email + password + username
    F->>A: GET /check-email?email=...
    A->>DB: SELECT 1 FROM users WHERE LOWER(email)=...
    DB-->>A: empty
    A-->>F: {available:true}
    U->>F: กด "ลงทะเบียน"
    F->>A: POST /register {email,password,username}
    A->>DB: INSERT users (role_id=2, is_email_verified=false)
    A->>DB: INSERT email_verification_codes (6-digit OTP, 15min)
    A->>SMTP: send_verification_email(otp)
    A-->>F: {message, user}
    F->>U: หน้ากรอก OTP

    U->>F: กรอก OTP
    F->>A: POST /verify-email {email, code}
    A->>DB: UPDATE email_verification_codes SET used=TRUE
    A->>DB: UPDATE users SET is_email_verified=TRUE
    A->>SMTP: send_welcome_email
    A-->>F: success → ไปหน้า login
```

**จุดสำคัญ:**
- OTP เก็บใน `email_verification_codes` (15 นาที, used=FALSE)
- ถ้า Flutter ใช้ Supabase Auth verify OTP เอง → backend route ยังรับเป็น mirror ได้ (race-safe)
- Send email failure → **ไม่** ทำให้ register fail (user resend ได้)

---

## 2. Login (Email/Password)

```mermaid
sequenceDiagram
    autonumber
    actor U as User
    participant F as Flutter
    participant A as API /auth
    participant DB as DB
    participant Sup as Supabase Auth

    U->>F: email + password
    F->>Sup: signInWithPassword (เก็บ session)
    Sup-->>F: access_token (Supabase JWT)
    F->>A: POST /login {email,password}<br/>Authorization: Bearer <supabase_token>
    A->>A: _decode_optional_bearer(token)
    alt token เป็น HS256 ของเรา
        A->>A: jwt.decode → payload
    else fallback
        A->>Sup: GET /auth/v1/user (apikey + bearer)
        Sup-->>A: user payload
    end
    A->>DB: SELECT * FROM users WHERE LOWER(email)=...
    DB-->>A: user row
    alt token ตรง email
        Note over A: skip password check
    else
        A->>A: verify_password(password, hash)
    end
    A->>A: ตรวจ is_email_verified
    A->>DB: UPDATE users (last_login_date, streak)
    opt streak hit milestone (1/3/7/14/30)
        A->>DB: INSERT notifications (achievement)
    end
    A->>A: _issue_access_token (HS256, 12h, role)
    A-->>F: {access_token, user_id, role_id, current_streak}
    F->>F: เก็บ JWT ใน secure storage
```

**จุดสำคัญ:**
- ระบบรับ **2 ชนิด token**: backend HS256 (ของเอง) และ Supabase token (fallback ผ่าน `/auth/v1/user`)
- การ verify password ข้ามได้ถ้า Supabase token พิสูจน์ email แล้ว (กรณี social/web)
- streak ทำใน transaction เดียวกับ last_login_date — ถ้าครั้งแรกของวัน จึงนับ +1

---

## 3. Login (Supabase Social / Web)

```mermaid
sequenceDiagram
    autonumber
    actor U as User
    participant F as Flutter Web
    participant Sup as Supabase Auth (Google/Apple)
    participant A as API
    participant DB as DB

    U->>F: กด "Sign in with Google"
    F->>Sup: signInWithOAuth(provider=google)
    Sup-->>F: redirect callback + session
    F->>A: POST /social-login {email, name, provider}
    A->>DB: SELECT users WHERE email=... AND deleted_at IS NULL
    alt user มีอยู่แล้ว
        A->>DB: UPDATE last_login_date / streak
    else user ใหม่
        A->>DB: INSERT users (password_hash=random, is_email_verified=true, role_id=2)
    end
    A-->>F: {user_id, email, role_id, is_new_user?}
    F->>F: ไป onboarding (ถ้า new) หรือ home
```

**จุดสำคัญ:**
- Social login ไม่มีรหัสผ่านจริง — เก็บ `secrets.token_hex(32)` เป็น placeholder
- Email ถือว่าตรวจแล้ว (Google/Apple ตรวจให้)
- New user → ส่ง flag `is_new_user=true` → Flutter route ไป `setting_screen` เพื่อให้กรอกข้อมูล TDEE

---

## 4. Password Reset

```mermaid
sequenceDiagram
    autonumber
    actor U as User
    participant F as Flutter
    participant A as API /auth
    participant DB as DB
    participant SMTP as SMTP

    U->>F: ลืมรหัสผ่าน → กรอก email
    F->>A: POST /password-reset/request {email}
    A->>DB: INSERT password_reset_codes (6-digit, 15min)
    A->>SMTP: send_password_reset_email
    A-->>F: ส่งรหัสยืนยันแล้ว

    U->>F: กรอก OTP + วันเดือนปีเกิด
    F->>A: POST /password-reset/verify {email, code, birth_date}
    A->>DB: ตรวจ birth_date ตรง user
    A->>DB: ตรวจ code ยังไม่หมดอายุ + used=FALSE
    A-->>F: ยืนยันโค้ดสำเร็จ

    U->>F: กรอกรหัสผ่านใหม่
    F->>A: POST /password-reset/confirm {email, code, birth_date, new_password}
    A->>DB: UPDATE users SET password_hash=...
    A->>DB: UPDATE password_reset_codes SET used=TRUE
    A-->>F: รีเซ็ตสำเร็จ
```

**จุดสำคัญ:**
- มี **2 factor**: OTP ทาง email + birth_date (กัน account hijack ถ้า email ถูก compromise)
- Code ใช้ครั้งเดียว (`used=TRUE`)

---

## 5. Search Food (with Regional Names)

```mermaid
sequenceDiagram
    autonumber
    actor U as User
    participant F as Flutter
    participant A as API /foods
    participant DB as DB

    U->>F: พิมพ์ "ข้าวปุ้น" (อีสาน)
    F->>A: GET /foods/search?q=ข้าวปุ้น&user_id=102
    A->>DB: SELECT users.region WHERE user_id=102
    DB-->>A: region=northeastern
    A->>DB: SELECT f.*, COALESCE(frn.name_th, f.food_name) AS display_name<br/>FROM foods f<br/>LEFT JOIN food_regional_names frn ON frn.food_id=f.food_id<br/> AND frn.region='northeastern' AND frn.is_primary<br/>WHERE f.food_name ILIKE '%ข้าวปุ้น%'<br/> OR EXISTS (SELECT 1 FROM food_regional_names<br/>            WHERE food_id=f.food_id AND name_th ILIKE '%ข้าวปุ้น%')
    DB-->>A: [{food_id:42, food_name:"ขนมจีน", display_name:"ข้าวปุ้น"}]
    A-->>F: results พร้อม display_name
    F->>U: แสดง "ข้าวปุ้น (ขนมจีน)"
```

**จุดสำคัญ:**
- การค้นหาตี match ทั้ง canonical name (`foods.food_name`) และ alt names (`food_regional_names.name_th`)
- การแสดงผลใช้ `display_name` ที่ผูกกับ `users.region` (ถ้ามี is_primary ของภาคนั้น)
- ถ้า `users.region IS NULL` → fallback ใช้ `food_name` (Central) เป็น display

---

## 6. Record Meal → Auto Daily Summary

```mermaid
sequenceDiagram
    autonumber
    actor U as User
    participant F as Flutter
    participant A as API /meals
    participant DB as DB
    participant T as fn_sync_daily_summary trigger

    U->>F: เลือกอาหาร + จำนวน serving + meal_type
    F->>A: POST /meals/{user_id} {food_id, qty, meal_type}
    A->>DB: BEGIN
    A->>DB: INSERT meals (user_id, meal_type, eaten_at)
    A->>DB: INSERT detail_items (meal_id, food_id, qty, cached macros)
    DB->>T: AFTER INSERT detail_items
    T->>DB: UPSERT daily_summaries (user_id, date)<br/>SET total_cal/protein/carbs/fat
    T->>DB: INSERT detail_items (summary_id=...) คัดลอก<br/>(polymorphism — Phase 4 จะแยก)
    A->>DB: COMMIT
    A-->>F: meal_id, daily_summary updated
    F->>U: แสดงค่าวันนี้อัพเดต
```

**จุดสำคัญ:**
- `detail_items` มี cached columns (`food_name`, `cal_per_unit`, ...) — v24 trigger `trg_foods_sync_detail_items` ทำให้ sync เมื่อ foods แก้
- `daily_summaries` เป็น materialized aggregate — trigger รันเองเวลา insert/update detail_items
- คอลัมน์ polymorphism (meal_id | plan_id | summary_id) ใน detail_items — CHECK บังคับว่าเลือก 1 (Phase 4)

---

## 7. Submit New Food (temp_food → admin)

```mermaid
sequenceDiagram
    autonumber
    actor U as User
    participant F as Flutter
    participant A as API /foods
    participant DB as DB
    participant Trg as trg_create_verified_food
    actor Adm as Admin
    participant Adp as API /admin

    U->>F: เพิ่มอาหารใหม่ที่ไม่มีในระบบ
    F->>A: POST /foods/auto-add {food_name, macros, image_url, user_id}
    A->>DB: INSERT temp_food (status=pending)
    DB->>Trg: AFTER INSERT temp_food
    Trg->>DB: INSERT verified_food (tf_id, is_verify=false)
    A-->>F: tf_id — แสดง "รออนุมัติ"

    Adm->>Adp: GET /admin/temp-foods?status=pending
    Adp->>DB: SELECT temp_food JOIN verified_food
    Adp-->>Adm: list
    Adm->>Adp: POST /admin/temp-foods/{tf_id}/approve
    Adp->>DB: BEGIN
    Adp->>DB: INSERT foods (จาก temp_food)
    Adp->>DB: UPDATE verified_food SET is_verify=true, verified_by, verified_at
    Adp->>DB: INSERT notifications (user_id, "อาหารของคุณถูกอนุมัติ")
    Adp->>DB: COMMIT
    Adp-->>Adm: approved
```

**จุดสำคัญ:**
- `temp_food` 1:1 กับ `verified_food` (trigger สร้างให้อัตโนมัติ)
- approve flow ผูกกับ admin role (`role_id=1`) — RLS ป้องกันคน normal เรียกได้
- notification ส่งกลับให้ user เจ้าของ

---

## 8. Submit Regional Name (variant → admin)

```mermaid
sequenceDiagram
    autonumber
    actor U as User
    participant F as Flutter
    participant A as API /foods
    participant DB as DB
    actor Adm as Admin

    U->>F: บนหน้า food detail → "เสนอชื่อท้องถิ่น"
    F->>U: form (region, name_th, popularity 1-5)
    U->>F: ส่ง
    F->>A: POST /foods/{food_id}/regional-names {region, name_th, popularity}
    A->>DB: INSERT food_regional_name_submissions (status=pending)
    A-->>F: submission_id

    Adm->>A: GET /admin/regional-name-submissions?status=pending
    A->>DB: SELECT submissions JOIN users JOIN foods
    A-->>Adm: list

    alt approve
        Adm->>A: POST /admin/regional-name-submissions/{id}/approve
        A->>DB: BEGIN
        A->>DB: INSERT food_regional_names (food_id, region, name_th, is_primary=...)
        opt มี popularity
            A->>DB: UPSERT food_regional_popularity
        end
        A->>DB: UPDATE submissions SET status=approved, reviewed_by, reviewed_at
        A->>DB: INSERT notifications (user "ชื่อ X ของคุณถูกอนุมัติ")
        A->>DB: COMMIT
    else reject
        Adm->>A: POST /admin/regional-name-submissions/{id}/reject
        A->>DB: UPDATE submissions SET status=rejected
        A->>DB: INSERT notifications (user "ชื่อ X ถูกปฏิเสธ")
    end
```

**จุดสำคัญ:**
- มี UNIQUE `(food_id, region, name_th)` กัน duplicate
- มี partial index `WHERE is_primary AND deleted_at IS NULL` กัน is_primary ซ้ำต่อ (food, region)

---

## 9. View Recipe Detail + Review

```mermaid
sequenceDiagram
    autonumber
    actor U as User
    participant F as Flutter
    participant A as API
    participant DB as DB

    U->>F: เปิด recipe_detail_screen (food_id=42)
    par โหลดข้อมูลพร้อมกัน
        F->>A: GET /recipes/42
        A->>DB: SELECT recipes + recipe_ingredients + recipe_steps + recipe_tips + recipe_tools<br/>WHERE food_id=42
        A-->>F: recipe payload
    and
        F->>A: GET /recipes/42/reviews
        A->>DB: SELECT recipe_reviews JOIN users WHERE food_id=42 ORDER BY created_at DESC
        A-->>F: reviews
    and
        F->>A: GET /recipes/42/favorite/102
        A->>DB: SELECT 1 FROM recipe_favorites WHERE food_id=42 AND user_id=102
        A-->>F: {is_favorite:bool}
    end
    F->>U: render recipe + reviews + ปุ่มหัวใจ

    U->>F: เขียนรีวิว 5 ดาว
    F->>A: POST /recipes/42/review {rating, comment, user_id}
    A->>DB: UPSERT recipe_reviews (UNIQUE user_id+food_id)
    A->>DB: UPDATE recipes (avg_rating, review_count)
    A-->>F: ok
```

**จุดสำคัญ:**
- 3 calls ขนานกันลด latency
- review เป็น UPSERT — user 1 คนรีวิว 1 ครั้งต่อ recipe

---

## 10. Water Log (1 row/day)

```mermaid
sequenceDiagram
    autonumber
    actor U as User
    participant F as Flutter
    participant A as API /water
    participant DB as DB

    U->>F: เพิ่มแก้วน้ำ (+1)
    F->>A: POST /water_logs/{user_id} {date_record, glasses=current+1}
    A->>DB: INSERT INTO water_logs (user_id, date_record, glasses)<br/>ON CONFLICT (user_id, date_record) DO UPDATE SET glasses=EXCLUDED.glasses
    Note over DB: CHECK constraint glasses BETWEEN 0 AND 30
    DB-->>A: row
    A-->>F: {glasses}
    F->>U: progress bar อัพเดต
```

**จุดสำคัญ:**
- UNIQUE `(user_id, date_record)` — UPSERT pattern
- cap ที่ 30 แก้ว (~7.5 ลิตร)

---

## 11. Weight Log + Goal Progress

```mermaid
sequenceDiagram
    autonumber
    actor U as User
    participant F as Flutter
    participant A as API /weight
    participant DB as DB

    U->>F: ชั่งน้ำหนัก (เช่น 65.2 kg)
    F->>A: POST /weight_logs/{user_id} {weight_kg, date_record}
    A->>DB: UPSERT weight_logs (UNIQUE user_id+date_record)
    A->>DB: UPDATE users SET current_weight_kg=65.2
    A-->>F: ok

    F->>A: GET /users/{user_id}/goal_progress
    A->>DB: SELECT users (current, target, goal_type)
    A->>DB: SELECT weight_logs ORDER BY date_record (สำหรับ chart)
    A->>A: คำนวณ % progress (ลด/เพิ่ม/คงที่)
    A-->>F: {progress_pct, history, est_target_date}
    F->>U: chart + ETA
```

**จุดสำคัญ:**
- UPSERT ต่อวัน — ถ้าชั่งซ้ำในวันเดียวกัน update row เดิม
- `current_weight_kg` บน users sync จาก log ล่าสุด (เพื่อ TDEE calc)

---

## 12. Chat Coach (Ollama Proxy)

```mermaid
sequenceDiagram
    autonumber
    actor U as User
    participant F as Flutter
    participant A as API /api/chat
    participant DB as DB
    participant LLM as Ollama Proxy<br/>(DeepSeek / local)

    U->>F: "วันนี้ควรกินอะไรดี?"
    F->>A: POST /api/chat/coach {message, user_id}
    A->>DB: SELECT users (goals, current_weight, target_calories)
    A->>DB: SELECT daily_summaries (วันนี้)
    A->>A: build system prompt + user context (Thai)
    A->>LLM: POST /api/chat (model=deepseek-r1, stream=true)
    loop streaming
        LLM-->>A: token chunks
        A-->>F: SSE event chunks
        F->>U: render token-by-token
    end
    LLM-->>A: done
    A-->>F: end
```

**จุดสำคัญ:**
- LLM provider configurable: Ollama local / DeepSeek cloud — ตัด AbstractProvider ใน `app/services/ai/`
- Streaming ผ่าน Server-Sent Events
- System prompt บรรจุ user goal + remaining calories ของวัน → ตอบเฉพาะตัว

---

## 13. Meal Estimation from Photo

```mermaid
sequenceDiagram
    autonumber
    actor U as User
    participant F as Flutter
    participant A as API
    participant Sup as Supabase Storage
    participant LLM as LLM Vision
    participant DB as DB

    U->>F: ถ่ายรูปอาหาร
    F->>A: POST /upload-image (multipart)
    A->>Sup: upload file → public URL
    Sup-->>A: image_url
    A-->>F: {image_url}

    F->>A: POST /api/meals/estimate {image_url}
    A->>LLM: POST /api/chat<br/>messages=[{vision:image_url, "estimate macros"}]
    LLM-->>A: JSON {food_name, cal, protein, carbs, fat, confidence}
    A->>A: validate JSON schema
    A-->>F: estimated meal
    F->>U: แสดงผล + ปุ่ม "บันทึก"

    opt user กด save
        F->>A: POST /meals/{user_id} (flow #6)
    end
```

**จุดสำคัญ:**
- Image hosting ผ่าน Supabase Storage bucket `food-photos` (RLS public read, authenticated write)
- LLM response ต้อง JSON parse — มี retry ถ้า invalid
- Confidence score < 0.5 → Flutter แสดงคำเตือน "ผลอาจไม่แม่น"

---

## 14. Update Profile + Recalc TDEE

```mermaid
sequenceDiagram
    autonumber
    actor U as User
    participant F as Flutter
    participant A as API /users
    participant DB as DB

    U->>F: แก้น้ำหนัก / ส่วนสูง / activity_level
    F->>A: PUT /users/{user_id} {height, weight, activity, goal_type, target_weight}
    A->>DB: UPDATE users SET ...
    F->>A: POST /users/{user_id}/recalc_tdee
    A->>DB: SELECT users (height, weight, age, gender, activity_level)
    A->>A: BMR (Mifflin-St Jeor) + activity multiplier
    A->>A: ปรับตาม goal_type (ลด -500, เพิ่ม +300)
    A->>DB: UPDATE users SET target_calories, target_protein, target_carbs, target_fat
    A-->>F: {target_calories, macros}
    F->>U: dashboard แสดงเป้าหมายใหม่
```

**จุดสำคัญ:**
- TDEE = BMR × activity_multiplier (1.2 sedentary → 1.9 very_active)
- macro split: protein 30% / carbs 45% / fat 25% (default; user override ใน setting)

---

## 15. Set User Region (v20)

```mermaid
sequenceDiagram
    autonumber
    actor U as User
    participant F as Flutter
    participant A as API /users
    participant DB as DB

    U->>F: setting_screen → เลือกภาค (เหนือ/ใต้/อีสาน/กลาง)
    F->>A: PUT /users/{user_id}/region {region: "northeastern"}
    A->>DB: UPDATE users SET region='northeastern', region_source='manual'
    A-->>F: ok
    F->>F: refresh search/display caches
    F->>U: ค้นหาอาหารแสดงชื่ออีสานเป็น primary
```

**จุดสำคัญ:**
- ENUM `thai_region` — รองรับ 4 ค่า
- `region_source`: manual / auto_ip / unset (placeholder สำหรับ future geo IP)
- ทันทีที่ตั้ง region → search ใช้ regional name ทันที (flow #5)

---

## 16. PDPA Soft-Delete Account

```mermaid
sequenceDiagram
    autonumber
    actor U as User
    participant F as Flutter
    participant A as API /users
    participant DB as DB
    participant Cron as Cron Job (30 วัน)

    U->>F: ตั้งค่า → "ลบบัญชี"
    F->>U: ยืนยัน (รหัสผ่าน)
    F->>A: DELETE /users/{user_id}
    A->>DB: UPDATE users SET deleted_at=NOW()
    Note over DB: row ยังอยู่ — CASCADE ไม่ trigger
    A-->>F: success
    F->>U: logout + แสดง "บัญชีถูกระงับ 30 วัน"

    Note over Cron: หลัง 30 วัน
    Cron->>DB: DELETE FROM users WHERE deleted_at < NOW() - INTERVAL '30 days'
    DB->>DB: CASCADE → meals, detail_items, water_logs, etc.
```

**จุดสำคัญ:**
- Soft delete = `deleted_at` set, row คงอยู่ — user undo ได้ภายใน 30 วัน
- Cron job (ยังไม่ deploy) จะ hard delete ตามนโยบาย PDPA
- export `/users/{user_id}/export` คืน JSON ทุก data ของ user ก่อนลบ

---

## 17. Approve temp_food

ดู Flow #7 (มี admin path อยู่แล้ว). เน้นเพิ่มจุด:

```mermaid
sequenceDiagram
    autonumber
    actor Adm as Admin
    participant Adp as API /admin
    participant DB as DB

    Adm->>Adp: GET /admin/foods/similar?q=ข้าวมันไก่
    Adp->>DB: SELECT foods WHERE food_name % q (pg_trgm fuzzy)
    Adp-->>Adm: 3 results
    Note over Adm: ตรวจว่า temp food ใหม่<br/>ไม่ซ้ำของเดิม

    Adm->>Adp: POST /admin/temp-foods/{tf_id}/approve {dish_id, serving_unit_id}
    Adp->>DB: BEGIN
    Adp->>DB: INSERT foods (FK dish_id, serving_unit_id) — ไม่มี food_category/serving_unit แล้ว (v21)
    Adp->>DB: INSERT recipes ถ้าเป็น MainDish
    Adp->>DB: UPDATE verified_food
    Adp->>DB: INSERT notifications
    Adp->>DB: COMMIT
```

**จุดสำคัญหลัง v21:**
- foods ใหม่ต้องระบุ `dish_id` + `serving_unit_id` — ไม่มี free-text columns แล้ว
- มี similar-search ป้องกัน admin approve duplicate

---

## 18. Approve/Reject Regional Name Submission

ดู Flow #8 (รวมไว้). จุดเพิ่ม: **decay rule** เมื่อ approve เป็น primary.

```mermaid
sequenceDiagram
    participant Adm as Admin
    participant A as API /admin
    participant DB as DB

    Adm->>A: POST /admin/regional-name-submissions/{id}/approve {is_primary:true}
    A->>DB: BEGIN
    alt is_primary
        A->>DB: UPDATE food_regional_names<br/>SET is_primary=false<br/>WHERE food_id=? AND region=? AND deleted_at IS NULL
    end
    A->>DB: INSERT food_regional_names (is_primary=?)
    A->>DB: UPDATE submissions SET status=approved
    A->>DB: COMMIT
```

**จุดสำคัญ:**
- การตั้งใหม่เป็น primary ทำ **demote** ของเดิม (constraint partial index บังคับ 1 primary ต่อ region)

---

## 19. Login Streak → Notification

```mermaid
sequenceDiagram
    autonumber
    participant A as API /auth (login)
    participant DB as DB
    participant F as Flutter

    Note over A: หลัง verify password
    A->>DB: SELECT last_login_date, total_login_days, current_streak FROM users
    alt last_login_date != today
        A->>A: total_days += 1
        alt streak ต่อเนื่อง (yesterday)
            A->>A: streak += 1
        else ขาด > 1 วัน
            A->>A: streak = 1
        end
        A->>DB: UPDATE users (last_login_date, total_login_days, current_streak)
        opt streak ∈ {1,3,7,14,30}
            A->>DB: INSERT notifications (type='achievement', title="Streak X วัน!", message=...)
        end
    end
    A-->>F: {current_streak}
    Note over F: หน้า home แสดง<br/>"streak X วันแล้ว"
```

**จุดสำคัญ:**
- streak reset ถ้าขาดเกิน 1 วัน
- milestone notification กัน duplicate ด้วย `ON CONFLICT DO NOTHING` (UNIQUE on user_id + title + date)
- bell icon ที่ home pull `/notifications/{user_id}/unread_count`

---

## หมายเหตุการอ่าน

- ทุก flow ที่มี `Authorization: Bearer <token>` (ไม่ render ในทุก diagram) จะถูก validate โดย `get_current_user` (HS256 + Supabase fallback)
- RLS layer ทำงานคู่ขนาน — ถ้า request มาจาก anon key (ไม่มี JWT) → policies เช่น `deny_anon` block ก่อนถึง code
- error path (4xx/5xx) ไม่วาดเพื่อให้ diagram อ่านง่าย — ดู [routers source](../backend/app/routers/) สำหรับ HTTPException details

---

**END OF SEQUENCE DIAGRAMS**
