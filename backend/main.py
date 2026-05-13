"""
Calories Guard API — thin entry point.

All endpoint logic lives in app/routers/*.
Shared models, services, and config are in app/.
"""

import os

from dotenv import load_dotenv

load_dotenv()

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import PlainTextResponse, Response
from fastapi.staticfiles import StaticFiles
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded

from database import get_db_connection
from psycopg2.extras import RealDictCursor
from app.core.config import ALLOWED_ORIGINS, IMAGEDIR, API_VERSION

# ── Sentry (optional: only if SENTRY_DSN is set) ──────────────────────────────
_SENTRY_DSN = os.getenv("SENTRY_DSN", "").strip()
if _SENTRY_DSN:
    try:
        import sentry_sdk
        from sentry_sdk.integrations.fastapi import FastApiIntegration
        from sentry_sdk.integrations.starlette import StarletteIntegration

        sentry_sdk.init(
            dsn=_SENTRY_DSN,
            environment=os.getenv("APP_ENV", "development"),
            traces_sample_rate=float(os.getenv("SENTRY_TRACES_SAMPLE_RATE", "0.1")),
            profiles_sample_rate=float(os.getenv("SENTRY_PROFILES_SAMPLE_RATE", "0.0")),
            integrations=[StarletteIntegration(), FastApiIntegration()],
            send_default_pii=False,
        )
    except ImportError:
        # sentry-sdk not installed — skip silently
        pass

# ── App & rate limiter ────────────────────────────────────────────────────────
limiter = Limiter(key_func=get_remote_address)
app = FastAPI(title="Calories Guard API")
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

# ── CORS ──────────────────────────────────────────────────────────────────────
app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,
    allow_origin_regex=(
        r"^https://([a-z0-9-]+\.)?caloriesguard\.com$|"
        r"^https://([a-z0-9-]+\.)?calories-guard\.com$|"
        r"^https://calories-guard\.pages\.dev$|"
        r"^https://[a-z0-9-]+-calories-guard\.pages\.dev$|"
        r"^https://[a-z0-9-]+\.framesirisak\.workers\.dev$|"
        r"^http://localhost(:\d+)?$|"
        r"^http://127\.0\.0\.1(:\d+)?$"
    ),
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
    allow_headers=["Authorization", "Content-Type", "Accept"],
    # expose X-Api-Version so browser/Flutter clients can read it off every
    # response (CORS strips non-safelist headers by default)
    expose_headers=["X-Api-Version"],
    max_age=600,
)


# ── API version header ───────────────────────────────────────────────────────
# Every response carries X-Api-Version so an old Flutter build can detect
# a major bump and prompt the user to update. See docs/CHANGELOG_API.md.
@app.middleware("http")
async def add_api_version_header(request, call_next):
    response = await call_next(request)
    response.headers["X-Api-Version"] = API_VERSION
    return response


# ── last_active_at updater ────────────────────────────────────────────────────
# Update the user's last_active_at on every authenticated request (debounced:
# only writes if the previous update was >5 minutes ago) so the server-side
# re-engagement job can find truly inactive users.
import re as _re
_AUTH_PATH_RE = _re.compile(r"^/users/(\d+)/")

@app.middleware("http")
async def update_last_active(request, call_next):
    response = await call_next(request)

    # Only act on successful authenticated requests that carry a user_id in path
    if response.status_code >= 400:
        return response

    m = _AUTH_PATH_RE.match(request.url.path)
    if not m:
        return response

    try:
        user_id = int(m.group(1))
        from database import get_db_connection
        from datetime import datetime, timezone, timedelta

        conn = get_db_connection()
        if conn:
            try:
                cur = conn.cursor()
                # Debounce: only write if last update was >5 minutes ago
                cur.execute(
                    """
                    UPDATE users
                    SET last_active_at = NOW()
                    WHERE user_id = %s
                      AND (last_active_at IS NULL
                           OR last_active_at < NOW() - INTERVAL '5 minutes')
                    """,
                    (user_id,),
                )
                conn.commit()
            except Exception:
                conn.rollback()
            finally:
                conn.close()
    except Exception:
        pass  # Never let middleware crash the request

    return response


@app.get("/robots.txt", include_in_schema=False)
def robots_txt():
    return PlainTextResponse(
        "User-agent: *\n"
        "Allow: /health\n"
        "Allow: /docs\n"
        "Disallow: /\n"
        "Sitemap: https://api.caloriesguard.com/sitemap.xml\n"
    )


@app.get("/sitemap.xml", include_in_schema=False)
def sitemap_xml():
    return Response(
        """<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <url>
    <loc>https://api.caloriesguard.com/health</loc>
  </url>
</urlset>
""",
        media_type="application/xml",
    )

# ── Static files (uploaded images) ───────────────────────────────────────────
if not os.path.exists(IMAGEDIR):
    os.makedirs(IMAGEDIR)
app.mount("/images", StaticFiles(directory=IMAGEDIR), name="images")

# ── Startup: ensure helper tables exist ──────────────────────────────────────
def _init_missing_tables():
    """Create tables missing from original schema."""
    conn = get_db_connection()
    if not conn:
        return
    try:
        cur = conn.cursor()
        cur.execute("""
            CREATE TABLE IF NOT EXISTS recipe_reviews (
                review_id BIGSERIAL PRIMARY KEY,
                food_id   BIGINT NOT NULL REFERENCES foods(food_id) ON DELETE CASCADE,
                user_id   BIGINT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
                rating    SMALLINT NOT NULL CHECK (rating BETWEEN 1 AND 5),
                comment   TEXT,
                created_at TIMESTAMP DEFAULT NOW(),
                UNIQUE (food_id, user_id)
            )
        """)
        cur.execute("""
            CREATE TABLE IF NOT EXISTS user_favorites (
                id         BIGSERIAL PRIMARY KEY,
                user_id    BIGINT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
                food_id    BIGINT NOT NULL REFERENCES foods(food_id) ON DELETE CASCADE,
                created_at TIMESTAMP DEFAULT NOW(),
                UNIQUE (user_id, food_id)
            )
        """)
        cur.execute("""
            CREATE TABLE IF NOT EXISTS water_logs (
                log_id      BIGSERIAL PRIMARY KEY,
                user_id     BIGINT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
                date_record DATE NOT NULL DEFAULT CURRENT_DATE,
                amount_ml   INT  NOT NULL DEFAULT 0 CHECK (amount_ml >= 0),
                glasses     INT  NOT NULL DEFAULT 0,
                updated_at  TIMESTAMP DEFAULT NOW(),
                UNIQUE (user_id, date_record)
            )
        """)
        cur.execute("ALTER TABLE water_logs ADD COLUMN IF NOT EXISTS amount_ml INT NOT NULL DEFAULT 0")
        cur.execute("ALTER TABLE water_logs ADD COLUMN IF NOT EXISTS glasses INT NOT NULL DEFAULT 0")
        cur.execute("ALTER TABLE water_logs ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP DEFAULT NOW()")
        cur.execute("""
            CREATE TABLE IF NOT EXISTS ai_feedback (
                id               BIGSERIAL PRIMARY KEY,
                user_id          BIGINT REFERENCES users(user_id) ON DELETE SET NULL,
                query            TEXT NOT NULL,
                response         TEXT NOT NULL,
                rating           VARCHAR(4) NOT NULL CHECK (rating IN ('up', 'down')),
                context_type     VARCHAR(20) DEFAULT 'chat',
                used_in_training BOOLEAN DEFAULT FALSE,
                created_at       TIMESTAMP DEFAULT NOW()
            )
        """)
        cur.execute("""
            CREATE TABLE IF NOT EXISTS notifications (
                notification_id BIGSERIAL PRIMARY KEY,
                user_id         BIGINT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
                title           VARCHAR(255),
                message         TEXT,
                type            VARCHAR(50) DEFAULT 'info',
                is_read         BOOLEAN DEFAULT FALSE,
                created_at      TIMESTAMP DEFAULT NOW()
            )
        """)
        # Add macro columns to detail_items if missing
        for col in ('protein_per_unit', 'carbs_per_unit', 'fat_per_unit'):
            cur.execute(f"""
                DO $$ BEGIN
                    ALTER TABLE detail_items ADD COLUMN {col} DOUBLE PRECISION DEFAULT 0;
                EXCEPTION WHEN duplicate_column THEN NULL;
                END $$;
            """)
        conn.commit()
    except Exception as e:
        print(f"[init] Could not ensure helper tables: {e}")
    finally:
        conn.close()


_init_missing_tables()

# ── Register routers ─────────────────────────────────────────────────────────
from app.routers import (
    health, auth, users, foods, admin,
    meals, weight, water, exercise,
    insights, social, chat, notifications, feedback, places,
)

app.include_router(health.router)
app.include_router(auth.router)
app.include_router(users.router)
app.include_router(foods.router)
app.include_router(admin.router)
app.include_router(meals.router)
app.include_router(weight.router)
app.include_router(water.router)
app.include_router(exercise.router)
app.include_router(insights.router)
app.include_router(social.router)
app.include_router(chat.router)
app.include_router(notifications.router)
app.include_router(feedback.router)
app.include_router(places.router)
