"""
Centralized configuration with pydantic-settings.

Fail-fast behavior:
- Missing env vars for required settings raise at startup, not at first request.
- Optional settings (Sentry, SMTP) are tolerated in dev but logged.

Usage:
    from app.core.config import settings
    print(settings.allowed_origins)

Legacy module-level constants are kept for backward compatibility with
existing router code (`from app.core.config import ALLOWED_ORIGINS, ...`).
"""
from __future__ import annotations

import os
from typing import List

from dotenv import load_dotenv
from pydantic import AliasChoices, Field

load_dotenv()

try:
    from pydantic_settings import BaseSettings, SettingsConfigDict
    _HAS_PSETTINGS = True
except ImportError:
    # Fallback if pydantic-settings not yet installed — keeps the legacy
    # os.getenv path working until requirements are refreshed.
    _HAS_PSETTINGS = False


def _split_csv(value: str) -> List[str]:
    return [v.strip() for v in value.split(",") if v.strip()]


if _HAS_PSETTINGS:

    class Settings(BaseSettings):
        model_config = SettingsConfigDict(
            env_file=".env",
            env_file_encoding="utf-8",
            extra="ignore",
            case_sensitive=False,
        )

        # CORS
        allowed_origins_raw: str = Field(
            default="",
            validation_alias=AliasChoices("ALLOWED_ORIGINS_RAW", "ALLOWED_ORIGINS"),
        )

        # DB
        db_mode: str = "local"
        db_host: str = "localhost"
        db_port: int = 5432
        db_name: str = "caloriesguard"
        db_user: str = "caloriesguard"
        db_password: str = ""

        # Supabase (required in production for Auth)
        supabase_url: str = ""
        supabase_anon_key: str = ""
        supabase_jwt_secret: str = ""
        supabase_project_url: str = ""  # legacy alias used by supabase_storage.py

        # AI — Ollama is the only supported backend. The daemon may run on
        # localhost (dev) or behind a Cloudflare Tunnel (prod). See
        # ollama/README.md for the Docker stack.
        ollama_base_url: str = "http://127.0.0.1:11434"
        ollama_model: str = "deepseek-r1:1.5b"
        ollama_timeout: int = 60
        ollama_num_predict: int = 320
        ollama_api_key: str = Field(
            default="",
            validation_alias=AliasChoices("OLLAMA_SECRET_API_KEY", "OLLAMA_API_KEY"),
        )  # bearer when behind a protected Ollama tunnel/proxy
        cf_access_client_id: str = ""        # alt Cloudflare Access auth
        cf_access_client_secret: str = ""
        # Kill-switch: set AI_ENABLED=false in Railway to disable AI
        # endpoints (chat + food auto-add) without a redeploy. Used when
        # the provider is rate-limiting, when we're over budget, or during
        # incidents.
        ai_enabled: bool = True

        # SMTP (optional — password-reset/verify email uses this)
        smtp_server: str = "smtp.gmail.com"
        smtp_port: int = 587
        smtp_username: str = ""
        smtp_password: str = ""
        from_email: str = ""
        from_name: str = "Calories Guard"

        # Admin notifications
        admin_notify_email: str = ""

        # Sentry (optional)
        sentry_dsn: str = ""
        app_env: str = "development"

        @property
        def allowed_origins(self) -> List[str]:
            return _split_csv(self.allowed_origins_raw) or ["*"]

    settings = Settings()

    # Legacy aliases (kept so existing imports keep working)
    ALLOWED_ORIGINS = settings.allowed_origins
    SMTP_SERVER = settings.smtp_server
    SMTP_PORT = settings.smtp_port
    SMTP_USERNAME = settings.smtp_username
    SMTP_PASSWORD = settings.smtp_password
    FROM_EMAIL = settings.from_email or settings.smtp_username
    FROM_NAME = settings.from_name
    ADMIN_NOTIFY_EMAIL = settings.admin_notify_email
    SENTRY_DSN = settings.sentry_dsn
    APP_ENV = settings.app_env
    AI_ENABLED = settings.ai_enabled

else:
    # ── Fallback path: plain os.getenv, matches prior behavior ──────────────
    _raw_origins = os.getenv("ALLOWED_ORIGINS", "").strip()
    ALLOWED_ORIGINS = _split_csv(_raw_origins) or ["*"]
    SMTP_SERVER = os.getenv("SMTP_SERVER", "smtp.gmail.com")
    SMTP_PORT = int(os.getenv("SMTP_PORT", "587"))
    SMTP_USERNAME = os.getenv("SMTP_USERNAME", "")
    SMTP_PASSWORD = os.getenv("SMTP_PASSWORD", "")
    FROM_EMAIL = os.getenv("FROM_EMAIL", SMTP_USERNAME)
    FROM_NAME = os.getenv("FROM_NAME", "Calories Guard")
    ADMIN_NOTIFY_EMAIL = os.getenv("ADMIN_NOTIFY_EMAIL", "")
    SENTRY_DSN = os.getenv("SENTRY_DSN", "")
    APP_ENV = os.getenv("APP_ENV", "development")
    AI_ENABLED = os.getenv("AI_ENABLED", "true").strip().lower() not in {"0", "false", "no", "off"}
    settings = None  # sentinel; callers should use the legacy constants

# --- Image upload (constants — not env-driven) ----------------------------
ALLOWED_MIME_TYPES = {"image/jpeg", "image/png", "image/webp", "image/gif"}
MAX_UPLOAD_SIZE = 5 * 1024 * 1024  # 5 MB
IMAGEDIR = "static/images"

# --- API version (bumped on breaking changes only) -------------------------
# Format: "YYYY.MM" of the release the change shipped in. Clients compare
# the major (year) segment; a year bump means clients MUST update.
# See docs/CHANGELOG_API.md for the running list of what each version covers.
API_VERSION = "2026.04"
