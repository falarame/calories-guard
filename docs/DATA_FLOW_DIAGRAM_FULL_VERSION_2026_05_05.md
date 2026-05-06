# Data Flow Diagram Full Version - Calories Guard

- Generated at: 2026-05-05
- Source basis: current backend routes, Flutter app flows, and live Supabase/PostgreSQL schema `cleangoal`
- Related schema docs:
  - `docs/ER_DIAGRAM_FULL_VERSION_2026_05_05.md`
  - `docs/DATA_DICTIONARY_FULL_VERSION_2026_05_05.md`
- Scope: user app, admin app/workflows, API backend, Supabase/PostgreSQL, Supabase Auth/Storage, AI services, health integrations, notifications, gamification, and reporting.

## Reading Guide

DFD notation used in this document:

| Symbol | Meaning |
|---|---|
| External Entity | Person or external system outside Calories Guard boundary |
| Process | Application/backend process that transforms data |
| Data Store | Persistent database, storage bucket, or local cache |
| Data Flow | Data moving between entity, process, or store |

Important boundaries:

- Flutter app runs on mobile/web and calls the backend API for most business data.
- Backend API is the source of truth for user targets, food logging, water date handling, food version snapshots, admin review, and Supabase database writes.
- Supabase/PostgreSQL `cleangoal` is the main data store.
- Supabase Auth verifies email/OAuth identity. The backend also issues/validates application JWT for protected endpoints.
- AI features are optional and controlled by backend config; AI output must be treated as estimated until the user/admin confirms it.

## External Entities

| Entity | Description | Main Data Sent | Main Data Received |
|---|---|---|---|
| User | End user using Calories Guard app | profile, login, food logs, water, weight, exercise, favorites, reviews, gamification actions | dashboard, targets, food catalogue, recipes, insights, notifications, progress |
| Admin | Admin/moderator | review decisions, food edits, user updates, regional-name approvals, gamification edits | pending queues, users list, food similarity, moderation result |
| Supabase Auth | External identity provider for email/OAuth verification | email/password/OAuth token, access token verification request | auth user payload, email confirmation status |
| Supabase Storage | File/object storage for uploaded images | uploaded image bytes and metadata | public image URL |
| Supabase/PostgreSQL | Main relational data store | normalized writes and queries | persisted records, views, aggregates |
| SMTP/Email Provider | Email sending provider | verification/reset email requests | email delivery result |
| AI/LLM Provider | Optional AI text/meal/recipe generation provider | user prompt, food name, system prompt | coach response, meal estimate, generated recipe |
| Health Connect / Device Health APIs | Mobile health data source | user-granted permissions and health reads | steps, active calories, exercise signals |
| Cloudflare Workers | Web hosting edge for Flutter web build | static web assets | web app responses |
| Railway/API Runtime | Backend runtime hosting FastAPI | API deployment/runtime traffic | API responses and health status |

## Data Stores

| Store ID | Store | Tables / Objects | Purpose |
|---|---|---|---|
| D1 | Identity Store | `users`, `roles`, `password_reset_codes`, `email_verification_codes` | Account, profile, role, auth lifecycle |
| D2 | User Preferences Store | `user_allergy_preferences`, `users.region`, `users.activity_level`, target fields | Personalization, goals, allergy filters |
| D3 | Food Catalogue Store | `foods`, `food_versions`, `dishes`, `dish_categories`, `beverages`, `snacks`, `units`, `unit_conversions` | Food master data and immutable food versions |
| D4 | Ingredient and Recipe Store | `ingredients`, `food_ingredients`, `ingredient_unit_conversions`, `recipes`, `recipe_ingredients`, `recipe_steps`, `recipe_tools`, `recipe_tips` | Recipe and ingredient-based nutrition calculation |
| D5 | User Log Store | `meals`, `detail_items`, `daily_summaries`, `water_logs`, `exercise_logs`, `weight_logs`, `progress` | User daily health records and historical snapshots |
| D6 | Social Store | `user_favorites`, `recipe_favorites`, `recipe_reviews`, `allergy_flags`, `food_allergy_flags` | Favorites, reviews, allergy warnings |
| D7 | Moderation Store | `temp_food`, `verified_food`, `food_regional_names`, `food_regional_popularity`, `food_regional_name_submissions` | Admin queues and regional food naming |
| D8 | Notification Store | `notifications` | In-app notification and streak messages |
| D9 | Gamification Store | `user_gamification`, `users.current_streak`, `users.total_login_days` | Tama points, tier, badges, login streaks |
| D10 | Content Store | `health_contents` | Health articles/videos |
| D11 | Archive/Migration Store | archive tables and `schema_migrations` | Migration traceability and rollback support |
| D12 | Read Models | `v_admin_temp_food_review`, `v_food_ingredient_nutrition_totals`, `v_food_recipes`, `v_recipe_ingredients_nutrition` | Derived query views |
| D13 | Object Storage | Supabase Storage buckets | Food/avatar/user uploaded images |
| D14 | Local Device Cache | Flutter SharedPreferences/local runtime state | Offline-ish temporary tama points, auth/session hints, UI state |

## Level 0 - System Context Diagram

```mermaid
flowchart LR
    User[External Entity: User]
    Admin[External Entity: Admin]
    Health[External Entity: Health Connect / Device Health APIs]
    AI[External Entity: AI / LLM Provider]
    Auth[External Entity: Supabase Auth]
    Email[External Entity: SMTP / Email Provider]
    Storage[External Entity: Supabase Storage]
    WebHost[External Entity: Cloudflare Workers]
    Runtime[External Entity: Railway API Runtime]

    System((Calories Guard System))
    DB[(Data Store: Supabase PostgreSQL cleangoal)]

    User -->|web/mobile actions, credentials, logs, profile, images| System
    System -->|dashboard, targets, foods, recipes, insights, notifications| User

    Admin -->|review, approve, reject, edit, manage users| System
    System -->|queues, user data, catalog status, moderation results| Admin

    Health -->|steps, exercise, active calories| System
    System -->|AI prompts, food name, text estimate request| AI
    AI -->|coach reply, meal estimate, recipe JSON| System

    System -->|auth verification, token introspection| Auth
    Auth -->|verified identity payload| System

    System -->|verification/reset email request| Email
    Email -->|delivery result| System

    System -->|image bytes and metadata| Storage
    Storage -->|public image URL| System

    WebHost -->|serves Flutter web app| User
    Runtime -->|runs FastAPI API| System

    System <-->|read/write normalized records and views| DB
```

## Level 1 - Main Process Decomposition

```mermaid
flowchart TB
    User[User]
    Admin[Admin]
    AI[AI / LLM Provider]
    Auth[Supabase Auth]
    Email[SMTP / Email Provider]
    Storage[Supabase Storage]
    Health[Health Connect / Device Health APIs]

    P1((P1 Auth and Account Lifecycle))
    P2((P2 Profile, Targets, Preferences))
    P3((P3 Food Catalogue, Ingredients, Recipes))
    P4((P4 Meal Logging and Daily Summaries))
    P5((P5 Water, Weight, Exercise, Progress))
    P6((P6 Insights, Dashboard, Reports))
    P7((P7 Social, Favorites, Reviews, Allergies))
    P8((P8 Gamification and Streaks))
    P9((P9 Notifications and Content))
    P10((P10 Admin Moderation and Governance))
    P11((P11 AI Coach, Meal Estimate, Recipe Generation))
    P12((P12 Uploads and Storage))

    D1[(D1 Identity Store)]
    D2[(D2 Preferences Store)]
    D3[(D3 Food Catalogue Store)]
    D4[(D4 Ingredient and Recipe Store)]
    D5[(D5 User Log Store)]
    D6[(D6 Social Store)]
    D7[(D7 Moderation Store)]
    D8[(D8 Notification Store)]
    D9[(D9 Gamification Store)]
    D10[(D10 Content Store)]
    D12[(D12 Read Models)]
    D13[(D13 Object Storage)]
    D14[(D14 Local Device Cache)]

    User --> P1
    P1 <--> Auth
    P1 --> Email
    P1 <--> D1
    P1 --> D8
    P1 --> User

    User --> P2
    P2 <--> D1
    P2 <--> D2
    P2 --> User

    User --> P3
    P3 <--> D3
    P3 <--> D4
    P3 --> D12
    P3 --> User

    User --> P4
    P4 <--> D3
    P4 <--> D5
    P4 --> User

    User --> P5
    Health --> P5
    P5 <--> D5
    P5 --> User

    User --> P6
    P6 <--> D1
    P6 <--> D5
    P6 <--> D3
    P6 <--> D12
    P6 --> User

    User --> P7
    P7 <--> D6
    P7 <--> D1
    P7 <--> D3
    P7 --> User

    User --> P8
    P8 <--> D9
    P8 <--> D1
    P8 <--> D14
    P8 --> User

    User --> P9
    P9 <--> D8
    P9 <--> D10
    P9 --> User

    Admin --> P10
    P10 <--> D1
    P10 <--> D3
    P10 <--> D4
    P10 <--> D7
    P10 <--> D9
    P10 --> Admin

    User --> P11
    P11 <--> D1
    P11 <--> D3
    P11 <--> D4
    P11 <--> D5
    P11 <--> AI
    P11 --> User

    User --> P12
    P12 <--> Storage
    P12 <--> D3
    P12 <--> D1
    P12 <--> D13
    P12 --> User
```

## Level 2 - Auth and Account Lifecycle

Related endpoints:

- `GET /check-email`
- `POST /register`
- `POST /verify-email`
- `POST /resend-verification-email`
- `POST /login`
- `POST /social-login`
- `POST /password-reset/request`
- `POST /password-reset/verify`
- `POST /password-reset/confirm`

```mermaid
flowchart LR
    User[User]
    P1A((Validate email and registration input))
    P1B((Create or match app user))
    P1C((Verify email / OAuth identity))
    P1D((Issue app session token))
    P1E((Update login streak))
    P1F((Password reset flow))
    Auth[Supabase Auth]
    Email[SMTP / Email Provider]
    D1[(users, roles)]
    D1B[(email_verification_codes)]
    D1C[(password_reset_codes)]
    D8[(notifications)]

    User -->|email, password, profile seed| P1A
    P1A -->|duplicate check| D1
    P1A --> P1B
    P1B -->|create pending user / verification code| D1
    P1B --> D1B
    P1B -->|send verification email| Email

    User -->|verification code or Supabase token| P1C
    P1C -->|token introspection| Auth
    Auth -->|verified identity| P1C
    P1C -->|mark verified| D1
    P1C --> D1B

    User -->|login credentials or OAuth token| P1D
    P1D -->|read user and role| D1
    P1D --> P1E
    P1E -->|last_login_date, total_login_days, current_streak| D1
    P1E -->|streak milestone notification| D8
    P1D -->|JWT, user profile, onboarding_required| User

    User -->|reset email / code / new password| P1F
    P1F --> D1
    P1F --> D1C
    P1F --> Email
    P1F -->|reset result| User
```

Key controls:

- Login and protected endpoints enforce user ownership via auth dependency checks.
- Streak updates happen during login/social login and may create notification rows.
- Email verification uses Supabase confirmation/token checks plus backend user state.

## Level 2 - Profile, Targets, Goals, and Preferences

Related endpoints:

- `GET /users/{user_id}`
- `PUT /users/{user_id}`
- `GET /users/{user_id}/region`
- `PUT /users/{user_id}/region`
- `POST /users/{user_id}/recalc_tdee`
- `GET /users/{user_id}/export`
- `DELETE /users/{user_id}`
- `GET/POST /users/{user_id}/allergies`

```mermaid
flowchart LR
    User[User]
    P2A((Read profile and onboarding state))
    P2B((Update profile and health inputs))
    P2C((Compute target calories and macros))
    P2D((Set region and allergy preferences))
    P2E((Export or delete account data))
    D1[(users)]
    D2[(user_allergy_preferences)]
    D6[(allergy_flags)]
    D5[(meals, detail_items, summaries, logs)]
    D7[(moderation tables)]
    D9[(user_gamification)]

    User -->|profile request| P2A
    P2A --> D1
    P2A -->|profile, targets, streak| User

    User -->|height, weight, goal, activity, dates| P2B
    P2B --> D1
    P2B --> P2C
    P2C -->|target_calories, target_protein, target_carbs, target_fat, recalc date| D1
    P2C -->|backend-calculated targets| User

    User -->|region, allergy flag ids| P2D
    P2D --> D1
    P2D --> D2
    P2D --> D6
    P2D -->|saved preferences| User

    User -->|export/delete request| P2E
    P2E --> D1
    P2E --> D2
    P2E --> D5
    P2E --> D7
    P2E --> D9
    P2E -->|export bundle or deletion result| User
```

Important calculation direction:

- Backend-calculated targets are the primary source of truth.
- Flutter formula should be treated as fallback or preview only and labelled as estimated.

## Level 2 - Food Catalogue, Ingredients, Units, and Recipes

Related endpoints:

- `GET /foods`
- `GET /foods/search`
- `GET /recommended-food`
- `POST /foods/auto-add`
- `GET /recipes/{food_id}`
- `GET /foods/{food_id}/regional-names`
- `POST /foods/{food_id}/regional-names`
- `GET /units`
- `GET /unit_conversions`
- Admin food endpoints covered in the admin section

```mermaid
flowchart TB
    User[User]
    P3A((Search/read food catalogue))
    P3B((Resolve regional display name))
    P3C((Read recipe details))
    P3D((Calculate ingredient-based nutrition))
    P3E((Submit auto-add food or regional name))
    P3F((Lazy-generate missing recipe))
    AI[AI / LLM Provider]
    D1[(users.region)]
    D3[(foods, food_versions, units, unit_conversions, dishes, beverages, snacks)]
    D4[(ingredients, food_ingredients, recipes, recipe_ingredients, recipe_steps, recipe_tools, recipe_tips)]
    D7[(temp_food, food_regional_name_submissions, food_regional_names)]
    D12[(v_food_ingredient_nutrition_totals, v_food_recipes, v_recipe_ingredients_nutrition)]

    User -->|query, user_id| P3A
    P3A --> D3
    P3A --> P3B
    P3B --> D1
    P3B --> D7
    P3B -->|foods with display_name and allergy ids| User

    User -->|food_id| P3C
    P3C --> D3
    P3C --> D4
    P3C --> P3D
    P3D --> D12
    P3D -->|recipe with calculated ingredient nutrition| User

    P3C -->|recipe missing and AI enabled| P3F
    P3F --> AI
    AI -->|recipe JSON| P3F
    P3F --> D4
    P3F -->|generated recipe| User

    User -->|temporary food details| P3E
    P3E --> D7
    P3E -->|pending review result| User

    User -->|regional name suggestion| P3E
    P3E --> D7
```

Ingredient calculation flow:

```mermaid
flowchart LR
    Food[foods]
    FoodIngredients[food_ingredients]
    Ingredients[ingredients]
    Units[units]
    Conversions[ingredient_unit_conversions / unit_conversions]
    RecipeIngredients[recipe_ingredients]
    View[v_recipe_ingredients_nutrition]
    RecipeUI[Recipe detail screen]

    Food --> FoodIngredients
    FoodIngredients --> Ingredients
    FoodIngredients --> Units
    Ingredients --> Conversions
    RecipeIngredients --> FoodIngredients
    RecipeIngredients --> Ingredients
    RecipeIngredients --> Units
    RecipeIngredients --> View
    Ingredients --> View
    Conversions --> View
    View --> RecipeUI
```

## Level 2 - Meal Logging and Food Snapshot Preservation

Related endpoints:

- `POST /meals/{user_id}`
- `GET /daily_summary/{user_id}`
- `GET /meals/{user_id}/detail`
- `GET /daily_logs/{user_id}`
- `GET /daily_logs/{user_id}/calendar`
- `GET /daily_logs/{user_id}/weekly`
- `DELETE /meals/clear/{user_id}`

```mermaid
flowchart TB
    User[User]
    P4A((Select food and quantity))
    P4B((Validate user ownership and meal type))
    P4C((Create or update meal header))
    P4D((Insert detail item))
    P4E((Attach food version snapshot))
    P4F((Recalculate daily summary))
    P4G((Read daily/weekly/calendar logs))
    D3[(foods, food_versions, units)]
    D5[(meals, detail_items, daily_summaries)]

    User -->|food_id, date_record, meal_type, amount, unit| P4A
    P4A --> P4B
    P4B --> P4C
    P4C --> D5
    P4D --> D3
    P4D --> D5
    P4D --> P4E
    P4E -->|food_version_id, food_snapshot JSONB| D5
    P4D --> P4F
    P4F -->|total calories/macros, goal status| D5
    P4F -->|log result| User

    User -->|date/month/week| P4G
    P4G --> D5
    P4G --> D3
    P4G -->|summary, detail items, calendar marks| User
```

Why this flow matters:

- `foods` can change later due to admin edits.
- `food_versions` and `detail_items.food_snapshot` keep user history reproducible.
- Deleting a catalogue food should be soft-delete, not historical log deletion.

## Level 2 - Water, Weight, Exercise, and Progress

Related endpoints:

- `GET /water_logs/{user_id}`
- `POST /water_logs/{user_id}`
- `POST /weight_logs/{user_id}`
- `GET /users/{user_id}/weight_logs`
- `GET /users/{user_id}/goal_progress`
- `GET /weight_status/{user_id}`
- `GET /progress_summary/{user_id}`

```mermaid
flowchart LR
    User[User]
    Health[Health Connect / Device Health APIs]
    P5A((Upsert water log by selected date))
    P5B((Record weight log))
    P5C((Import or enter exercise data))
    P5D((Calculate goal progress direction))
    P5E((Build progress summary))
    D1[(users goal fields)]
    D5[(water_logs, weight_logs, exercise_logs, daily_summaries, progress)]

    User -->|date_record, glasses, amount_ml| P5A
    P5A -->|selected date, not server current date| D5
    P5A -->|water result| User

    User -->|weight, body metrics, date| P5B
    P5B --> D5
    P5B --> P5D

    Health -->|steps, active calories, workout data| P5C
    User -->|manual exercise data| P5C
    P5C --> D5

    P5D --> D1
    P5D --> D5
    P5D -->|moving_toward_goal, progress percentage, estimate| User

    User -->|summary request| P5E
    P5E --> D5
    P5E --> D1
    P5E -->|weight status and progress summary| User
```

Important controls:

- Water logs must use the selected date from the client.
- Goal progress direction must depend on goal type: loss, gain, or maintain.
- Wearable/exercise calories should be shown as estimates and source-labelled when imported.

## Level 2 - Dashboard, Insights, and Reports

Related endpoints:

- `GET /insights/{user_id}`
- `GET /insights/{user_id}/top_foods`
- `GET /insights/{user_id}/calorie_trend`
- `GET /insights/{user_id}/macro_balance`
- `GET /daily_summary/{user_id}`
- `GET /users/{user_id}/food-frequency`

```mermaid
flowchart TB
    User[User]
    P6A((Load dashboard))
    P6B((Aggregate calories and macros))
    P6C((Find top foods and food frequency))
    P6D((Build calorie trend))
    P6E((Build macro balance))
    P6F((Merge backend targets and labels))
    D1[(users targets and streak)]
    D3[(foods)]
    D5[(meals, detail_items, daily_summaries, water_logs, weight_logs)]
    D12[(read model views)]

    User -->|dashboard date/range| P6A
    P6A --> P6B
    P6A --> P6C
    P6A --> P6D
    P6A --> P6E
    P6A --> P6F

    P6B --> D5
    P6C --> D5
    P6C --> D3
    P6D --> D5
    P6E --> D5
    P6F --> D1
    P6F --> D12

    P6A -->|dashboard cards, charts, reports, target source label| User
```

Target display rule:

- If backend target values exist, UI displays backend-calculated values.
- If backend targets are missing and Flutter uses fallback values, UI must label them as estimated.

## Level 2 - Gamification, Tama Points, Badges, and Leaderboard

Related endpoints:

- `GET /users/{user_id}/tama-points`
- `PATCH /users/{user_id}/tama-points`
- `PATCH /admin/users/{user_id}/tama`
- `GET /leaderboard`
- Login/social login streak updates in auth endpoints

```mermaid
flowchart LR
    User[User]
    Admin[Admin]
    P8A((Read gamification state))
    P8B((Award or spend tama points locally))
    P8C((Sync points, tier, badges to backend))
    P8D((Update login streak))
    P8E((Build leaderboard))
    P8F((Admin adjust gamification))
    D1[(users.current_streak, users.total_login_days)]
    D9[(user_gamification)]
    D14[(SharedPreferences local tama cache)]
    D8[(notifications)]

    User -->|open tama/reward screen| P8A
    P8A --> D9
    P8A --> D14
    P8A -->|points, tier, badges| User

    User -->|claim mission / buy reward| P8B
    P8B --> D14
    P8B --> P8C
    P8C --> D9
    P8C -->|sync result| User

    User -->|login| P8D
    P8D --> D1
    P8D --> D8

    User -->|leaderboard request| P8E
    P8E --> D1
    P8E --> D9
    P8E -->|ranked users by streak/points| User

    Admin -->|points/tier/badges override| P8F
    P8F --> D9
    P8F -->|updated gamification| Admin
```

Notes:

- Flutter currently keeps a local point cache and syncs to backend via tama endpoints.
- Backend stores persistent `user_gamification` state for cross-device consistency.
- Login streak is stored on `users`, not only `user_gamification`.

## Level 2 - Social, Favorites, Reviews, and Allergies

Related endpoints:

- `GET /recipes/{food_id}/favorite/{user_id}`
- `POST /recipes/{food_id}/favorite/{user_id}`
- `GET /users/{user_id}/favorites`
- `GET /recipes/{food_id}/reviews`
- `POST /recipes/{food_id}/review`
- `GET /allergy_flags`
- `GET /users/{user_id}/allergies`
- `POST /users/{user_id}/allergies`
- `GET /leaderboard`

```mermaid
flowchart LR
    User[User]
    P7A((Toggle favorite food/recipe))
    P7B((Read favorites))
    P7C((Create or update review))
    P7D((Read allergy flags and preferences))
    P7E((Filter or warn foods by allergies))
    D1[(users)]
    D3[(foods)]
    D4[(recipes)]
    D6[(user_favorites, recipe_favorites, recipe_reviews, allergy_flags, food_allergy_flags, user_allergy_preferences)]

    User -->|favorite action| P7A
    P7A --> D1
    P7A --> D3
    P7A --> D4
    P7A --> D6
    P7A -->|favorite state| User

    User -->|favorites request| P7B
    P7B --> D6
    P7B --> D3
    P7B -->|favorite foods/recipes| User

    User -->|rating/comment| P7C
    P7C --> D4
    P7C --> D6
    P7C -->|review result| User

    User -->|allergy request/update| P7D
    P7D --> D6
    P7D -->|flags/preferences| User

    P7D --> P7E
    P7E --> D3
    P7E --> D6
    P7E -->|food allergy badge or warning| User
```

## Level 2 - Notifications and Health Content

Related endpoints:

- `GET /notifications/{user_id}`
- `GET /notifications/{user_id}/unread_count`
- `PUT /notifications/{user_id}/read_all`
- Health contents are stored in `health_contents` and can be exposed by content routes/features.

```mermaid
flowchart LR
    User[User]
    SystemProcess[System Processes]
    P9A((Create event notification))
    P9B((Read notification list))
    P9C((Mark notifications read))
    P9D((Read health content))
    D8[(notifications)]
    D10[(health_contents)]

    SystemProcess -->|streak milestone, admin/content/system event| P9A
    P9A --> D8

    User -->|open notification sheet| P9B
    P9B --> D8
    P9B -->|notifications and unread count| User

    User -->|mark all read| P9C
    P9C --> D8
    P9C -->|read result| User

    User -->|content request| P9D
    P9D --> D10
    P9D -->|articles/videos| User
```

## Level 2 - Admin Moderation and Data Governance

Related endpoints:

- `GET /admin/users`
- `GET /admin/users/{user_id}`
- `PATCH /admin/users/{user_id}`
- `DELETE /admin/users/{user_id}`
- `GET /admin/temp-foods/pending-count`
- `GET /admin/temp-foods`
- `GET /admin/foods/similar`
- `POST /admin/temp-foods/{tf_id}/approve`
- `DELETE /admin/temp-foods/{tf_id}`
- `GET /admin/regional-name-submissions`
- `POST /admin/regional-name-submissions/{submission_id}/approve`
- `POST /admin/regional-name-submissions/{submission_id}/reject`
- `POST /foods`
- `PUT /foods/{food_id}`
- `PATCH /foods/{food_id}`
- `DELETE /foods/{food_id}`

```mermaid
flowchart TB
    Admin[Admin]
    P10A((Authenticate admin role))
    P10B((Review temp food))
    P10C((Approve temp food into catalog))
    P10D((Reject temp food))
    P10E((Review regional name submission))
    P10F((Edit or soft-delete food catalogue))
    P10G((Manage users and gamification))
    D1[(users, roles)]
    D3[(foods, food_versions, dishes, units)]
    D4[(ingredients, recipes, food_ingredients)]
    D7[(temp_food, verified_food, food_regional_names, food_regional_popularity, food_regional_name_submissions)]
    D9[(user_gamification)]
    D11[(archive and schema_migrations)]

    Admin -->|admin token| P10A
    P10A --> D1
    P10A -->|authorized| P10B
    P10A --> P10E
    P10A --> P10F
    P10A --> P10G

    P10B --> D7
    P10B -->|pending queue and similarity candidates| Admin
    P10C --> D7
    P10C --> D3
    P10C -->|new food and version trigger| D3
    P10C -->|approval result| Admin

    P10D --> D7
    P10D -->|rejection result| Admin

    P10E --> D7
    P10E -->|approved alias or rejection| D7
    P10E --> Admin

    P10F --> D3
    P10F -->|create food_versions row / update current_version_id| D3
    P10F -->|soft delete using deleted_at| D3
    P10F --> Admin

    P10G --> D1
    P10G --> D9
    P10G --> D11
    P10G --> Admin
```

Governance rules:

- Admin food edits create or update immutable food version records.
- Soft delete protects existing user history.
- Regional names are moderated before becoming searchable/displayable.
- Temporary food approval should normalize values into catalog tables and mark review state.

## Level 2 - AI Coach, Meal Estimate, and Recipe Generation

Related endpoints:

- `POST /api/chat/coach`
- `POST /api/meals/estimate`
- `POST /api/chat/multi`
- `GET /recipes/{food_id}` may lazy-generate a recipe if missing and AI is configured.

```mermaid
flowchart LR
    User[User]
    P11A((Sanitize prompt and check AI kill switch))
    P11B((Build nutrition context))
    P11C((Call AI/LLM provider))
    P11D((Parse and validate AI response))
    P11E((Return estimated answer or save generated recipe))
    AI[AI / LLM Provider]
    D1[(users profile and targets)]
    D3[(foods)]
    D4[(recipes and recipe JSON fields)]
    D5[(user logs and summaries)]

    User -->|coach prompt / meal text / food name| P11A
    P11A --> P11B
    P11B --> D1
    P11B --> D3
    P11B --> D5
    P11B --> P11C
    P11C --> AI
    AI -->|text, estimate, recipe JSON| P11D
    P11D -->|invalid JSON or unsafe output| User
    P11D --> P11E
    P11E -->|generated recipe when applicable| D4
    P11E -->|estimated/AI-labelled output| User
```

AI safety constraints:

- AI meal estimates are not treated as exact nutrition values until the user confirms.
- AI-generated recipes must be parsed/validated before storing.
- AI coach should not make diagnosis or treatment claims.
- AI endpoints are disabled when the backend kill switch/config says AI is off.

## Level 2 - Uploads and Storage

Related endpoints:

- `POST /upload-image/`
- `POST /upload_image`

```mermaid
flowchart LR
    User[User]
    P12A((Receive upload request))
    P12B((Validate bytes and MIME by magic bytes))
    P12C((Upload object to Supabase Storage))
    P12D((Return public URL))
    Storage[Supabase Storage]
    D13[(Object metadata / public URL)]
    D1[(users avatar URL if profile upload)]
    D3[(foods image_url if food upload)]

    User -->|image file| P12A
    P12A --> P12B
    P12B -->|valid image bytes| P12C
    P12C --> Storage
    Storage -->|public URL| P12D
    P12D --> D13
    P12D --> D1
    P12D --> D3
    P12D -->|public URL| User
```

Controls:

- Validate content from bytes, not only client-provided content type.
- Store only public URL or storage path in database, not image bytes.

## Cross-Cutting Data Flows

### Authorization and Ownership

```mermaid
flowchart LR
    Client[Flutter Client]
    AuthHeader[Authorization Bearer Token]
    AuthDep((get_current_user / get_current_admin))
    Router[Protected API Route]
    D1[(users, roles)]
    Response[Allowed or 401/403]

    Client --> AuthHeader
    AuthHeader --> AuthDep
    AuthDep --> D1
    AuthDep --> Router
    Router --> Response
```

### Food Edit to Historical Log Protection

```mermaid
sequenceDiagram
    participant Admin
    participant API as Backend API
    participant Foods as foods
    participant Versions as food_versions
    participant Logs as detail_items
    participant User

    Admin->>API: PATCH /foods/{food_id}
    API->>Foods: update mutable catalogue fields
    Foods->>Versions: trigger/create new immutable version
    Versions->>Foods: set current_version_id
    User->>API: POST /meals/{user_id}
    API->>Foods: read current food
    API->>Versions: read current version
    API->>Logs: insert detail_items with food_version_id and food_snapshot
    API-->>User: logged item with stable historical nutrition
```

### User Dashboard Refresh

```mermaid
sequenceDiagram
    participant User
    participant Flutter
    participant API
    participant DB as Supabase PostgreSQL

    User->>Flutter: Open home/dashboard
    Flutter->>API: GET /users/{user_id}
    API->>DB: read users target fields
    API-->>Flutter: backend target calories/macros
    Flutter->>API: GET /daily_summary/{user_id}?date_record=...
    API->>DB: read daily_summaries/detail_items
    API-->>Flutter: totals and goal status
    Flutter->>API: GET /notifications/{user_id}/unread_count
    API->>DB: read notifications
    API-->>Flutter: unread count
    Flutter-->>User: dashboard with backend values as source of truth
```

## CRUD Matrix by Main Data Store

| Data Store | Create | Read | Update | Delete / Soft Delete |
|---|---|---|---|---|
| D1 Identity Store | register, social-login | profile/admin users | profile, login streak, password reset | user delete/soft delete |
| D2 Preferences Store | set allergies/region | profile/allergies | update allergies/region | replace allergy preferences |
| D3 Food Catalogue Store | admin approve/create food | foods/search/recommended | admin edit food, version trigger | soft delete food |
| D4 Ingredient and Recipe Store | generated/manual recipes, ingredients via migration/admin | recipes/ingredient views | recipe/admin maintenance | usually retain or archive |
| D5 User Log Store | meals, water, weight, exercise | daily/weekly/calendar/progress | summaries, water upsert | clear meal type, user deletion cascade |
| D6 Social Store | favorites, reviews, allergy mapping | favorites/reviews/allergy flags | upsert review/allergies | toggle favorite/delete review where supported |
| D7 Moderation Store | temp food, regional submissions | admin pending queues | approve/reject state | reject/delete pending item |
| D8 Notification Store | streak/system/content events | notification list/unread count | mark all read | retention cleanup if added later |
| D9 Gamification Store | first tama sync | tama points/leaderboard | points, tier, claimed badges | admin/user deletion cascade |
| D10 Content Store | admin/seed content | health content | content updates | content removal/soft delete if added |
| D13 Object Storage | image upload | public URL | overwrite/delete-then-upload for avatar | object cleanup if added |

## Open Technical Debt and Risk Notes

| Area | Current Risk | Recommended Control |
|---|---|---|
| AI meal estimate | AI outputs can be approximate or wrong | Require explicit estimated label and user confirmation before saving |
| Flutter local gamification cache | Local points can temporarily diverge from backend | Keep backend sync as final state and resolve conflicts by latest backend update |
| Health data imports | Wearable active calories are estimates | Store source and timestamp; avoid double-counting in TDEE/exercise |
| Food catalog edits | Mutable food data can alter historical meaning | Continue using `food_versions` and `detail_items.food_snapshot` |
| Ingredient conversion gaps | `ingredient_unit_conversions` currently may be sparse | Add conversions for common Thai household units per ingredient |
| Archive tables | Archive tables exist in full schema but are not product stores | Keep out of app queries except migration/admin diagnostics |
| Admin moderation | Duplicate/low-quality food submissions can pollute catalog | Use similarity check, review status, and audit trail |

## Traceability to Current Backend Routes

| Process | Main Routers |
|---|---|
| P1 Auth and Account Lifecycle | `backend/app/routers/auth.py` |
| P2 Profile, Targets, Preferences | `backend/app/routers/users.py`, `backend/app/routers/social.py` |
| P3 Food Catalogue, Ingredients, Recipes | `backend/app/routers/foods.py`, `backend/app/routers/health.py` |
| P4 Meal Logging and Daily Summaries | `backend/app/routers/meals.py` |
| P5 Water, Weight, Exercise, Progress | `backend/app/routers/water.py`, `backend/app/routers/weight.py` |
| P6 Insights, Dashboard, Reports | `backend/app/routers/insights.py`, `backend/app/routers/meals.py` |
| P7 Social, Favorites, Reviews, Allergies | `backend/app/routers/social.py` |
| P8 Gamification and Streaks | `backend/app/routers/users.py`, `backend/app/routers/admin.py`, `backend/app/routers/auth.py` |
| P9 Notifications and Content | `backend/app/routers/notifications.py` |
| P10 Admin Moderation and Governance | `backend/app/routers/admin.py`, `backend/app/routers/foods.py` |
| P11 AI Coach and Estimate | `backend/app/routers/chat.py`, `backend/app/routers/foods.py` |
| P12 Uploads and Storage | `backend/app/routers/health.py` |

