"""
Referral reward grant service.

Single entry point: `grant_referral_rewards_for_user(user_id)`.
Called from auth.verify_email() after `is_email_verified` flips to TRUE.

The grant is idempotent — `referrals.invitee_user_id` is UNIQUE and
`referral_rewards.(referral_id, role)` is UNIQUE — so retries on transient
DB errors cannot double-pay. Reward amounts live as constants here so the
admin can tune them without touching SQL.
"""

from __future__ import annotations

import logging

from psycopg2.extras import RealDictCursor

logger = logging.getLogger(__name__)

# Tunable reward values. Keep in sync with copy in invite email + UI.
INVITER_GEMS = 50
INVITER_XP = 20
INVITEE_GEMS = 20
INVITEE_XP = 0


def _find_inviter_by_pending(cur, pending_value: str) -> tuple[int | None, str | None, int | None]:
    """Resolve a pending_referral_code value into (inviter_user_id, source, invitation_id).

    The pending value can be either a permanent referral_codes.code OR a
    one-time referral_invitations.token. We probe both — the token check
    gets priority because tokens are 32-40 chars while codes are 8 chars,
    so they don't realistically collide, but we still de-ambiguate
    explicitly via separate lookups.
    """
    cur.execute(
        """
        SELECT invitation_id, inviter_user_id, status, expires_at
        FROM cleangoal.referral_invitations
        WHERE token = %s
        LIMIT 1
        """,
        (pending_value,),
    )
    row = cur.fetchone()
    if row:
        if row["status"] == 'accepted':
            return None, None, None
        if row["expires_at"] and row["expires_at"].timestamp() < __import__("datetime").datetime.now(
            __import__("datetime").timezone.utc
        ).timestamp():
            return None, None, None
        return int(row["inviter_user_id"]), 'email', int(row["invitation_id"])

    cur.execute(
        """
        SELECT user_id FROM cleangoal.referral_codes WHERE code = %s LIMIT 1
        """,
        (pending_value,),
    )
    row = cur.fetchone()
    if row:
        return int(row["user_id"]), 'link', None

    return None, None, None


def _upsert_gamification(cur, user_id: int, gems_delta: int, xp_delta: int) -> None:
    """Add gems/XP to user_gamification, creating the row if missing.

    Mirrors the admin-side pattern in app/routers/admin.py:115 but uses
    addition instead of overwrite. `tama_points` is the lifetime XP used
    for tier ranking, so we ADD to it. `gems` is spendable currency.
    """
    cur.execute(
        """
        INSERT INTO cleangoal.user_gamification
            (user_id, tama_points, gems, gems_updated_at, updated_at)
        VALUES (%s, %s, %s, NOW(), NOW())
        ON CONFLICT (user_id) DO UPDATE SET
            tama_points     = cleangoal.user_gamification.tama_points + EXCLUDED.tama_points,
            gems            = cleangoal.user_gamification.gems        + EXCLUDED.gems,
            gems_updated_at = NOW(),
            updated_at      = NOW()
        """,
        (user_id, xp_delta, gems_delta),
    )


def _push_reward_notification(cur, user_id: int, title: str, message: str) -> None:
    cur.execute(
        """
        INSERT INTO cleangoal.notifications (user_id, title, message, type)
        VALUES (%s, %s, %s, 'achievement')
        """,
        (user_id, title, message),
    )


def grant_referral_rewards_for_user(conn, invitee_user_id: int) -> dict | None:
    """Apply the two-sided referral reward.

    Reads users.pending_referral_code, resolves the inviter, binds them
    via cleangoal.referrals (idempotent), and grants gems+XP to both.
    Returns a summary dict or None if there's no pending code / inviter.

    The caller controls the transaction — we never call conn.commit() so
    auth.verify_email() can roll back together with its own updates if
    something later in the same handler fails.
    """
    cur = conn.cursor(cursor_factory=RealDictCursor)

    cur.execute(
        "SELECT pending_referral_code FROM cleangoal.users WHERE user_id = %s",
        (invitee_user_id,),
    )
    row = cur.fetchone()
    if not row or not row["pending_referral_code"]:
        return None

    pending_value = row["pending_referral_code"].strip()
    inviter_user_id, source, invitation_id = _find_inviter_by_pending(cur, pending_value)
    if not inviter_user_id:
        # invalid/expired/used — clear it so we don't retry forever
        cur.execute(
            "UPDATE cleangoal.users SET pending_referral_code = NULL WHERE user_id = %s",
            (invitee_user_id,),
        )
        return None

    if inviter_user_id == invitee_user_id:
        cur.execute(
            "UPDATE cleangoal.users SET pending_referral_code = NULL WHERE user_id = %s",
            (invitee_user_id,),
        )
        return None

    # Bind inviter ↔ invitee (idempotent via UNIQUE on invitee_user_id)
    cur.execute(
        """
        INSERT INTO cleangoal.referrals
            (inviter_user_id, invitee_user_id, source, invitation_id, status, reward_granted_at)
        VALUES (%s, %s, %s, %s, 'rewarded', NOW())
        ON CONFLICT (invitee_user_id) DO NOTHING
        RETURNING referral_id
        """,
        (inviter_user_id, invitee_user_id, source, invitation_id),
    )
    referral_row = cur.fetchone()
    if not referral_row:
        # Already bound previously → reward already granted (UNIQUE on rewards table guards too)
        cur.execute(
            "UPDATE cleangoal.users SET pending_referral_code = NULL WHERE user_id = %s",
            (invitee_user_id,),
        )
        return None
    referral_id = int(referral_row["referral_id"])

    # Two ledger rows + two gamification bumps + two notifications
    # ON CONFLICT DO NOTHING on the unique guards against double-grant under retry.
    cur.execute(
        """
        INSERT INTO cleangoal.referral_rewards
            (referral_id, user_id, role, gems_delta, xp_delta)
        VALUES (%s, %s, 'inviter', %s, %s)
        ON CONFLICT (referral_id, role) DO NOTHING
        """,
        (referral_id, inviter_user_id, INVITER_GEMS, INVITER_XP),
    )
    cur.execute(
        """
        INSERT INTO cleangoal.referral_rewards
            (referral_id, user_id, role, gems_delta, xp_delta)
        VALUES (%s, %s, 'invitee', %s, %s)
        ON CONFLICT (referral_id, role) DO NOTHING
        """,
        (referral_id, invitee_user_id, INVITEE_GEMS, INVITEE_XP),
    )

    _upsert_gamification(cur, inviter_user_id, INVITER_GEMS, INVITER_XP)
    _upsert_gamification(cur, invitee_user_id, INVITEE_GEMS, INVITEE_XP)

    _push_reward_notification(
        cur,
        inviter_user_id,
        "🎉 ได้รับรางวัลจากการชวนเพื่อน!",
        f"เพื่อนของคุณสมัครสำเร็จแล้ว รับ {INVITER_GEMS} gems + {INVITER_XP} XP",
    )
    _push_reward_notification(
        cur,
        invitee_user_id,
        "🎁 ยินดีต้อนรับ! รับโบนัสเริ่มต้น",
        f"คุณได้รับ {INVITEE_GEMS} gems ฟรีจากการสมัครผ่านลิงก์เพื่อน",
    )

    # Mark invitation accepted (if email-source) and clear the pending flag
    if invitation_id is not None:
        cur.execute(
            """
            UPDATE cleangoal.referral_invitations
               SET status = 'accepted',
                   accepted_at = NOW(),
                   accepted_user_id = %s
             WHERE invitation_id = %s
            """,
            (invitee_user_id, invitation_id),
        )
    cur.execute(
        "UPDATE cleangoal.users SET pending_referral_code = NULL WHERE user_id = %s",
        (invitee_user_id,),
    )

    logger.info(
        "Granted referral reward: inviter=%s invitee=%s source=%s referral_id=%s",
        inviter_user_id, invitee_user_id, source, referral_id,
    )
    return {
        "referral_id": referral_id,
        "inviter_user_id": inviter_user_id,
        "invitee_user_id": invitee_user_id,
        "source": source,
        "inviter_gems": INVITER_GEMS,
        "inviter_xp": INVITER_XP,
        "invitee_gems": INVITEE_GEMS,
        "invitee_xp": INVITEE_XP,
    }
