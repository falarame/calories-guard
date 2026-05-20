"""
Shared FCM push helper.

Lazily initializes the Firebase Admin SDK and exposes `send_push_to_tokens()`
for fire-and-forget pushes. Stays quiet (returns 0) when firebase-admin isn't
installed or FIREBASE_SERVICE_ACCOUNT_JSON isn't set so dev environments
don't crash on missing config.

Same SDK is used by app/jobs/reengagement_push.py; both share the singleton
init through firebase_admin._apps so re-init is a no-op.
"""

from __future__ import annotations

import json
import logging
import os
from typing import Iterable

logger = logging.getLogger(__name__)

try:
    import firebase_admin
    from firebase_admin import credentials, messaging
    _FCM_AVAILABLE = True
except ImportError:
    _FCM_AVAILABLE = False


def _init_firebase() -> bool:
    if not _FCM_AVAILABLE:
        return False
    if firebase_admin._apps:
        return True
    sa_json = os.getenv("FIREBASE_SERVICE_ACCOUNT_JSON", "").strip()
    if not sa_json:
        return False
    try:
        firebase_admin.initialize_app(credentials.Certificate(json.loads(sa_json)))
        return True
    except Exception:
        logger.exception("Failed to initialize Firebase Admin SDK")
        return False


def send_push_to_tokens(
    tokens: Iterable[str],
    title: str,
    body: str,
    data: dict[str, str] | None = None,
) -> int:
    """Send the same payload to many tokens. Returns # of successes.

    Invalid tokens are returned in the caller's responsibility to clean up —
    we expose nothing about which ones failed. Caller can re-query DB after.
    """
    if not _init_firebase():
        return 0
    valid_tokens = [t for t in tokens if t]
    if not valid_tokens:
        return 0

    sent = 0
    for token in valid_tokens:
        try:
            msg = messaging.Message(
                notification=messaging.Notification(title=title, body=body),
                data={k: str(v) for k, v in (data or {}).items()},
                token=token,
            )
            messaging.send(msg)
            sent += 1
        except messaging.UnregisteredError:
            # caller can sweep DB for stale tokens out-of-band; we don't block here
            logger.info("FCM token unregistered (will be cleared on next sweep)")
        except Exception as exc:
            logger.warning("FCM send error: %s", exc)
    return sent
