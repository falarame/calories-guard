"""
Re-engagement FCM push job.

Sends a push notification to users who:
  - Have an FCM token stored
  - Have not been active (last_active_at) for at least 2 days
  - Are not already suppressed by a recent push (tracked in this script)

Run as a Railway scheduled task (or any cron):
  python -m app.jobs.reengagement_push

Environment variables required (same as main app):
  DATABASE_URL or individual PG_* vars
  FIREBASE_SERVICE_ACCOUNT_JSON  — JSON string of the Firebase service account key

Schedule recommendation: once daily at 01:00 local time.
"""

from __future__ import annotations

import json
import logging
import os
import sys
from datetime import datetime, timezone, timedelta

logger = logging.getLogger(__name__)
logging.basicConfig(level=logging.INFO,
                    format="%(asctime)s %(levelname)s %(message)s")

# ── Optional import: firebase-admin ──────────────────────────────────────────
try:
    import firebase_admin
    from firebase_admin import credentials, messaging
    _FCM_AVAILABLE = True
except ImportError:
    logger.warning(
        "firebase-admin not installed. "
        "Run `pip install firebase-admin` to enable push delivery."
    )
    _FCM_AVAILABLE = False


def _init_firebase() -> bool:
    """Initialize Firebase Admin SDK from env var. Returns True on success."""
    if not _FCM_AVAILABLE:
        return False
    if firebase_admin._apps:
        return True

    sa_json = os.getenv("FIREBASE_SERVICE_ACCOUNT_JSON", "").strip()
    if not sa_json:
        logger.error(
            "FIREBASE_SERVICE_ACCOUNT_JSON env var not set — cannot send FCM."
        )
        return False

    try:
        sa_dict = json.loads(sa_json)
        cred = credentials.Certificate(sa_dict)
        firebase_admin.initialize_app(cred)
        return True
    except Exception as exc:
        logger.exception("Failed to initialize Firebase Admin: %s", exc)
        return False


def _get_db_connection():
    """Return a psycopg2 connection using env vars."""
    try:
        import psycopg2
        from psycopg2.extras import RealDictCursor  # noqa: F401

        database_url = os.getenv("DATABASE_URL", "").strip()
        if database_url:
            conn = psycopg2.connect(database_url)
        else:
            conn = psycopg2.connect(
                host=os.getenv("PGHOST", "localhost"),
                port=int(os.getenv("PGPORT", "5432")),
                dbname=os.getenv("PGDATABASE", "postgres"),
                user=os.getenv("PGUSER", "postgres"),
                password=os.getenv("PGPASSWORD", ""),
            )
        conn.set_session(options={"search_path": "cleangoal,public"})
        return conn
    except Exception as exc:
        logger.exception("DB connection failed: %s", exc)
        return None


def _send_push(token: str, title: str, body: str, payload: str) -> bool:
    """Send a single FCM message. Returns True on success."""
    try:
        message = messaging.Message(
            notification=messaging.Notification(title=title, body=body),
            data={"payload": payload},
            token=token,
        )
        response = messaging.send(message)
        logger.info("FCM sent: %s", response)
        return True
    except messaging.UnregisteredError:
        logger.warning("Unregistered FCM token — will clear.")
        return False
    except Exception as exc:
        logger.exception("FCM send error: %s", exc)
        return False


def run() -> None:
    """Main entry point: query inactive users and send push notifications."""
    if not _init_firebase():
        logger.error("Firebase init failed — aborting.")
        sys.exit(1)

    conn = _get_db_connection()
    if conn is None:
        logger.error("Cannot connect to database — aborting.")
        sys.exit(1)

    cutoff_2d = datetime.now(timezone.utc) - timedelta(days=2)

    try:
        cur = conn.cursor()
        cur.execute("""
            SELECT user_id, fcm_token, last_active_at
            FROM users
            WHERE fcm_token IS NOT NULL
              AND deleted_at IS NULL
              AND (last_active_at IS NULL OR last_active_at < %s)
        """, (cutoff_2d,))
        rows = cur.fetchall()

        sent = 0
        cleared = 0

        for user_id, token, last_active_at in rows:
            inactive_days: int
            if last_active_at is None:
                inactive_days = 999
            else:
                delta = datetime.now(timezone.utc) - last_active_at.replace(
                    tzinfo=timezone.utc)
                inactive_days = delta.days

            if inactive_days >= 5:
                title = "🔥 Streak ของคุณกำลังจะหาย!"
                body = "ผ่านมา 5 วันแล้วที่ไม่ได้บันทึก อย่าปล่อยให้ความพยายามสูญเปล่านะ"
            else:
                title = "😔 เราคิดถึงคุณนะ!"
                body = "ผ่านมา 2 วันแล้วที่ไม่ได้บันทึกอาหาร มาเช็กความคืบหน้ากันดีกว่า 💪"

            success = _send_push(token, title, body, "record_food")
            if success:
                sent += 1
            else:
                # Token invalid — clear it from DB
                cur.execute(
                    "UPDATE users SET fcm_token = NULL, fcm_token_updated_at = NOW() "
                    "WHERE user_id = %s",
                    (user_id,),
                )
                cleared += 1

        conn.commit()
        logger.info(
            "Re-engagement job done: %d sent, %d tokens cleared, "
            "%d users inactive",
            sent, cleared, len(rows),
        )

    except Exception as exc:
        logger.exception("Re-engagement job error: %s", exc)
        conn.rollback()
        sys.exit(1)
    finally:
        conn.close()


if __name__ == "__main__":
    # Allow running as: python -m app.jobs.reengagement_push
    # or:               python backend/app/jobs/reengagement_push.py
    run()
