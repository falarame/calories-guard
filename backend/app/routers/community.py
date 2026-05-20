"""
Community / Chat / Invite router.

Owns: referral codes & email invites, friendships, conversations (DM + group),
messages (text + image + file + system), presence heartbeat, and the FCM
fan-out for offline recipients.

All endpoints (except `/referral/preview/{code_or_token}`) require an
authenticated user. The router uses the backend service-role connection,
so RLS is bypassed — every handler enforces ownership/membership explicitly.
"""

from __future__ import annotations

import os
import secrets
from datetime import datetime, timedelta, timezone
from typing import List, Literal, Optional
from urllib.parse import urlparse

from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form, Query
from pydantic import BaseModel, EmailStr, Field
from psycopg2.extras import RealDictCursor, execute_values

from database import get_db_connection
from auth.dependencies import get_current_user
from app.services.email_service import send_invite_email
from app.services.chat_storage import upload_chat_attachment
from app.services.fcm_push import send_push_to_tokens


router = APIRouter()


_INVITE_TOKEN_BYTES = 24          # → 32-char URL-safe token
_INVITE_TTL_DAYS = 14
_OFFLINE_AFTER_SECONDS = 90

_DEFAULT_APP_PUBLIC_URL = "https://app.caloriesguard.com"
_UNROUTED_APP_PUBLIC_HOSTS = {"caloriesguard.app", "www.caloriesguard.app"}


def _normalize_app_public_url(raw_url: str | None) -> str:
    raw = (raw_url or _DEFAULT_APP_PUBLIC_URL).strip()
    if not raw:
        raw = _DEFAULT_APP_PUBLIC_URL
    if not raw.startswith(("http://", "https://")):
        raw = f"https://{raw}"

    parsed = urlparse(raw)
    if parsed.netloc.lower() in _UNROUTED_APP_PUBLIC_HOSTS:
        return _DEFAULT_APP_PUBLIC_URL
    return raw.rstrip("/")


_APP_PUBLIC_URL = _normalize_app_public_url(os.getenv("APP_PUBLIC_URL"))


def _invite_share_url(code: str) -> str:
    return f"{_APP_PUBLIC_URL}/invite/{code}"


def _require_user_id(current_user: dict) -> int:
    uid = current_user.get("user_id")
    if uid is None:
        raise HTTPException(status_code=401, detail="Authenticated user missing user_id")
    return int(uid)


def _row_to_iso(row: dict, fields: list[str]) -> dict:
    """In-place convert datetime → isoformat for json-friendly output."""
    out = dict(row)
    for f in fields:
        v = out.get(f)
        if v is not None and hasattr(v, "isoformat"):
            out[f] = v.isoformat()
    return out


# ═══════════════════════════════════════════════════════════════════════════
# Pydantic bodies
# ═══════════════════════════════════════════════════════════════════════════

class InviteByEmailBody(BaseModel):
    email: EmailStr


class ClaimReferralBody(BaseModel):
    """Used by the register screen to validate the code BEFORE signup so the
    user sees a "You were invited by X" preview. Public endpoint."""
    value: str = Field(..., min_length=4, max_length=64)


class FriendActionBody(BaseModel):
    user_id: int


class CreateDmBody(BaseModel):
    user_id: int


class CreateGroupBody(BaseModel):
    name: str = Field(..., min_length=1, max_length=120)
    member_user_ids: List[int] = Field(..., min_length=1)


class AddMembersBody(BaseModel):
    member_user_ids: List[int] = Field(..., min_length=1)


class SendMessageBody(BaseModel):
    kind: Literal["text", "image", "file"] = "text"
    body: Optional[str] = None
    attachment_url: Optional[str] = None
    attachment_mime: Optional[str] = None
    attachment_size: Optional[int] = None
    attachment_name: Optional[str] = None
    reply_to_message_id: Optional[int] = None


class EditMessageBody(BaseModel):
    body: str = Field(..., min_length=1)


class MarkReadBody(BaseModel):
    message_id: int


class PresenceHeartbeatBody(BaseModel):
    status: Literal["online", "away", "offline"] = "online"


# ═══════════════════════════════════════════════════════════════════════════
# Section 1 — Referral / Invite
# ═══════════════════════════════════════════════════════════════════════════

def _ensure_referral_code(cur, user_id: int) -> str:
    """Get or generate this user's permanent referral code."""
    cur.execute(
        "SELECT code FROM cleangoal.referral_codes WHERE user_id = %s",
        (user_id,),
    )
    row = cur.fetchone()
    if row:
        return row["code"]
    cur.execute(
        """
        INSERT INTO cleangoal.referral_codes (user_id, code)
        VALUES (%s, cleangoal.gen_referral_code())
        ON CONFLICT (user_id) DO NOTHING
        RETURNING code
        """,
        (user_id,),
    )
    row = cur.fetchone()
    if row:
        return row["code"]
    # extremely-rare race: another tx created it between SELECT and INSERT
    cur.execute(
        "SELECT code FROM cleangoal.referral_codes WHERE user_id = %s",
        (user_id,),
    )
    return cur.fetchone()["code"]


@router.get("/referral/me")
def get_my_referral(current_user: dict = Depends(get_current_user)):
    user_id = _require_user_id(current_user)
    conn = get_db_connection()
    if not conn:
        raise HTTPException(status_code=503, detail="Database unavailable")
    try:
        cur = conn.cursor(cursor_factory=RealDictCursor)
        code = _ensure_referral_code(cur, user_id)

        cur.execute(
            """
            SELECT
                (SELECT COUNT(*) FROM cleangoal.referral_invitations WHERE inviter_user_id = %(uid)s) AS total_invites,
                (SELECT COUNT(*) FROM cleangoal.referrals WHERE inviter_user_id = %(uid)s) AS accepted,
                (SELECT COUNT(*) FROM cleangoal.referrals WHERE inviter_user_id = %(uid)s AND status = 'rewarded') AS rewarded,
                COALESCE((SELECT SUM(gems_delta) FROM cleangoal.referral_rewards WHERE user_id = %(uid)s), 0) AS gems,
                COALESCE((SELECT SUM(xp_delta)   FROM cleangoal.referral_rewards WHERE user_id = %(uid)s), 0) AS xp
            """,
            {"uid": user_id},
        )
        row = cur.fetchone()

        conn.commit()
        return {
            "code": code,
            "share_url": _invite_share_url(code),
            "deep_link": f"com.caloriesguard.app://invite/{code}",
            "total_invites": int(row["total_invites"]),
            "accepted_count": int(row["accepted"]),
            "rewarded_count": int(row["rewarded"]),
            "total_gems_earned": int(row["gems"]),
            "total_xp_earned":   int(row["xp"]),
        }
    finally:
        if conn:
            conn.close()


@router.get("/referral/invitees")
def list_my_invitees(current_user: dict = Depends(get_current_user)):
    user_id = _require_user_id(current_user)
    conn = get_db_connection()
    if not conn:
        raise HTTPException(status_code=503, detail="Database unavailable")
    try:
        cur = conn.cursor(cursor_factory=RealDictCursor)
        cur.execute(
            """
            SELECT r.referral_id,
                   r.invitee_user_id,
                   r.source,
                   r.status,
                   r.reward_granted_at,
                   r.created_at,
                   u.username       AS invitee_username,
                   u.avatar_url     AS invitee_avatar
            FROM cleangoal.referrals r
            JOIN cleangoal.users u ON u.user_id = r.invitee_user_id
            WHERE r.inviter_user_id = %s
            ORDER BY r.created_at DESC
            """,
            (user_id,),
        )
        rows = [_row_to_iso(r, ["reward_granted_at", "created_at"]) for r in cur.fetchall()]
        return rows
    finally:
        if conn:
            conn.close()


@router.post("/referral/invite/email")
def invite_by_email(body: InviteByEmailBody, current_user: dict = Depends(get_current_user)):
    """Create a per-email invitation token and email it. Idempotent: if an
    active invite already exists for the same (inviter, email), reuse it."""
    user_id = _require_user_id(current_user)
    invitee_email = body.email.lower().strip()
    conn = get_db_connection()
    if not conn:
        raise HTTPException(status_code=503, detail="Database unavailable")
    try:
        cur = conn.cursor(cursor_factory=RealDictCursor)

        # Make sure the inviter has their code (for the email signature line)
        _ensure_referral_code(cur, user_id)

        # Reuse existing active invite if present
        cur.execute(
            """
            SELECT invitation_id, token, expires_at
            FROM cleangoal.referral_invitations
            WHERE inviter_user_id = %s
              AND invitee_email = %s
              AND status IN ('pending','sent')
            ORDER BY created_at DESC LIMIT 1
            """,
            (user_id, invitee_email),
        )
        row = cur.fetchone()
        if row and row["expires_at"] > datetime.now(timezone.utc):
            token = row["token"]
            invitation_id = int(row["invitation_id"])
        else:
            token = secrets.token_urlsafe(_INVITE_TOKEN_BYTES)
            expires = datetime.now(timezone.utc) + timedelta(days=_INVITE_TTL_DAYS)
            cur.execute(
                """
                INSERT INTO cleangoal.referral_invitations
                    (inviter_user_id, invitee_email, token, status, expires_at, sent_at)
                VALUES (%s, %s, %s, 'sent', %s, NOW())
                RETURNING invitation_id
                """,
                (user_id, invitee_email, token, expires),
            )
            invitation_id = int(cur.fetchone()["invitation_id"])

        # Get inviter's username for the email greeting
        cur.execute("SELECT username FROM cleangoal.users WHERE user_id = %s", (user_id,))
        inviter = cur.fetchone()
        inviter_name = inviter["username"] if inviter else "เพื่อน"

        conn.commit()

        share_url = _invite_share_url(token)
        email_sent = False
        try:
            email_sent = send_invite_email(
                invitee_email,
                inviter_name=inviter_name,
                invite_url=share_url,
            )
        except Exception:
            # Logging only; UI already shows the link to copy if email failed.
            email_sent = False

        # Update sent_at on success
        if email_sent:
            cur.execute(
                """
                UPDATE cleangoal.referral_invitations
                   SET sent_at = NOW(), status = 'sent'
                 WHERE invitation_id = %s
                """,
                (invitation_id,),
            )
            conn.commit()

        return {
            "invitation_id": invitation_id,
            "token": token,
            "share_url": share_url,
            "email_sent": email_sent,
            "expires_at": (datetime.now(timezone.utc) + timedelta(days=_INVITE_TTL_DAYS)).isoformat(),
        }
    except HTTPException:
        conn.rollback()
        raise
    except Exception as exc:
        conn.rollback()
        raise HTTPException(status_code=500, detail=str(exc))
    finally:
        if conn:
            conn.close()


@router.get("/referral/preview/{value}")
def preview_referral(value: str):
    """Public endpoint — register screen calls this to show 'invited by X'."""
    if len(value) < 4 or len(value) > 64:
        raise HTTPException(status_code=400, detail="Invalid referral value")
    conn = get_db_connection()
    if not conn:
        raise HTTPException(status_code=503, detail="Database unavailable")
    try:
        cur = conn.cursor(cursor_factory=RealDictCursor)

        # try as one-time token first
        cur.execute(
            """
            SELECT i.expires_at, i.status, u.username, u.avatar_url
            FROM cleangoal.referral_invitations i
            JOIN cleangoal.users u ON u.user_id = i.inviter_user_id
            WHERE i.token = %s
            """,
            (value,),
        )
        row = cur.fetchone()
        if row:
            if row["status"] == 'accepted':
                raise HTTPException(status_code=410, detail="ลิงก์เชิญถูกใช้งานไปแล้ว")
            if row["expires_at"] < datetime.now(timezone.utc):
                raise HTTPException(status_code=410, detail="ลิงก์เชิญหมดอายุแล้ว")
            return {
                "valid": True,
                "kind": "email",
                "inviter_username": row["username"],
                "inviter_avatar":   row["avatar_url"],
            }

        # else, try as permanent code
        cur.execute(
            """
            SELECT u.username, u.avatar_url
            FROM cleangoal.referral_codes c
            JOIN cleangoal.users u ON u.user_id = c.user_id
            WHERE c.code = %s
            """,
            (value,),
        )
        row = cur.fetchone()
        if not row:
            raise HTTPException(status_code=404, detail="ไม่พบลิงก์เชิญนี้")
        return {
            "valid": True,
            "kind": "link",
            "inviter_username": row["username"],
            "inviter_avatar":   row["avatar_url"],
        }
    finally:
        if conn:
            conn.close()


# ═══════════════════════════════════════════════════════════════════════════
# Section 2 — Friendships
# ═══════════════════════════════════════════════════════════════════════════

def _push_to_user(cur, user_id: int, title: str, body: str, data: dict) -> None:
    """Look up FCM token + send. Silent on failure."""
    cur.execute(
        "SELECT fcm_token FROM cleangoal.users WHERE user_id = %s AND fcm_token IS NOT NULL",
        (user_id,),
    )
    row = cur.fetchone()
    if not row or not row.get("fcm_token"):
        return
    send_push_to_tokens([row["fcm_token"]], title, body, data)


@router.get("/friends")
def list_friends(current_user: dict = Depends(get_current_user)):
    user_id = _require_user_id(current_user)
    conn = get_db_connection()
    if not conn:
        raise HTTPException(status_code=503, detail="Database unavailable")
    try:
        cur = conn.cursor(cursor_factory=RealDictCursor)
        cur.execute(
            """
            SELECT f.friend_id        AS user_id,
                   u.username,
                   u.avatar_url,
                   f.status,
                   f.created_at,
                   f.accepted_at,
                   COALESCE(p.status, 'offline') AS presence,
                   p.last_seen_at
            FROM cleangoal.friendships f
            JOIN cleangoal.users u           ON u.user_id = f.friend_id
            LEFT JOIN cleangoal.user_presence p ON p.user_id = f.friend_id
            WHERE f.user_id = %s
              AND f.status = 'accepted'
              AND u.deleted_at IS NULL
            ORDER BY u.username
            """,
            (user_id,),
        )
        rows = [_row_to_iso(r, ["created_at", "accepted_at", "last_seen_at"]) for r in cur.fetchall()]
        return rows
    finally:
        if conn:
            conn.close()


@router.get("/friends/requests")
def list_friend_requests(current_user: dict = Depends(get_current_user)):
    """Incoming pending requests (someone else asked me)."""
    user_id = _require_user_id(current_user)
    conn = get_db_connection()
    if not conn:
        raise HTTPException(status_code=503, detail="Database unavailable")
    try:
        cur = conn.cursor(cursor_factory=RealDictCursor)
        cur.execute(
            """
            SELECT f.user_id, u.username, u.avatar_url, f.created_at
            FROM cleangoal.friendships f
            JOIN cleangoal.users u ON u.user_id = f.user_id
            WHERE f.friend_id = %s
              AND f.status = 'pending'
              AND u.deleted_at IS NULL
              AND NOT EXISTS (
                SELECT 1 FROM cleangoal.friendships f2
                WHERE f2.user_id = %s AND f2.friend_id = f.user_id AND f2.status = 'blocked'
              )
            ORDER BY f.created_at DESC
            """,
            (user_id, user_id),
        )
        return [_row_to_iso(r, ["created_at"]) for r in cur.fetchall()]
    finally:
        if conn:
            conn.close()


@router.post("/friends/request")
def request_friend(body: FriendActionBody, current_user: dict = Depends(get_current_user)):
    user_id = _require_user_id(current_user)
    target = int(body.user_id)
    if target == user_id:
        raise HTTPException(status_code=400, detail="เพิ่มตัวเองเป็นเพื่อนไม่ได้")
    conn = get_db_connection()
    if not conn:
        raise HTTPException(status_code=503, detail="Database unavailable")
    try:
        cur = conn.cursor(cursor_factory=RealDictCursor)
        cur.execute("SELECT 1 FROM cleangoal.users WHERE user_id = %s AND deleted_at IS NULL", (target,))
        if not cur.fetchone():
            raise HTTPException(status_code=404, detail="ไม่พบผู้ใช้นี้")

        # Block check: target has blocked me?
        cur.execute(
            "SELECT 1 FROM cleangoal.friendships WHERE user_id = %s AND friend_id = %s AND status = 'blocked'",
            (target, user_id),
        )
        if cur.fetchone():
            raise HTTPException(status_code=403, detail="ไม่สามารถส่งคำขอเพื่อนได้")

        # If the other party already sent ME a pending request, accept it.
        cur.execute(
            "SELECT status FROM cleangoal.friendships WHERE user_id = %s AND friend_id = %s",
            (target, user_id),
        )
        existing_inbound = cur.fetchone()
        if existing_inbound and existing_inbound["status"] == "pending":
            cur.execute(
                """
                UPDATE cleangoal.friendships
                   SET status = 'accepted', accepted_at = NOW()
                 WHERE user_id = %s AND friend_id = %s
                """,
                (target, user_id),
            )
            # mirror trigger inserts the inverse row
            conn.commit()
            return {"status": "accepted"}

        cur.execute(
            """
            INSERT INTO cleangoal.friendships (user_id, friend_id, status)
            VALUES (%s, %s, 'pending')
            ON CONFLICT (user_id, friend_id) DO UPDATE
              SET status = CASE
                WHEN cleangoal.friendships.status = 'blocked' THEN 'blocked'
                ELSE 'pending'
              END
            """,
            (user_id, target),
        )
        # Best-effort push to the recipient
        cur.execute("SELECT username FROM cleangoal.users WHERE user_id = %s", (user_id,))
        me = cur.fetchone()
        _push_to_user(
            cur, target,
            title="👋 มีคำขอเป็นเพื่อนใหม่",
            body=f"{me['username'] if me else 'มีผู้ใช้'} อยากเป็นเพื่อนกับคุณ",
            data={"type": "friend_request", "from_user_id": user_id},
        )
        conn.commit()
        return {"status": "pending"}
    except HTTPException:
        conn.rollback()
        raise
    except Exception as exc:
        conn.rollback()
        raise HTTPException(status_code=500, detail=str(exc))
    finally:
        if conn:
            conn.close()


@router.post("/friends/{target_user_id}/accept")
def accept_friend(target_user_id: int, current_user: dict = Depends(get_current_user)):
    """Accept an incoming request sent by `target_user_id` to me."""
    user_id = _require_user_id(current_user)
    conn = get_db_connection()
    if not conn:
        raise HTTPException(status_code=503, detail="Database unavailable")
    try:
        cur = conn.cursor(cursor_factory=RealDictCursor)
        cur.execute(
            "SELECT status FROM cleangoal.friendships WHERE user_id = %s AND friend_id = %s",
            (target_user_id, user_id),
        )
        row = cur.fetchone()
        if not row or row["status"] != "pending":
            raise HTTPException(status_code=404, detail="ไม่พบคำขอเพื่อนที่รอการตอบรับ")

        cur.execute(
            """
            UPDATE cleangoal.friendships
               SET status = 'accepted', accepted_at = NOW()
             WHERE user_id = %s AND friend_id = %s
            """,
            (target_user_id, user_id),
        )

        # Push back to requester
        cur.execute("SELECT username FROM cleangoal.users WHERE user_id = %s", (user_id,))
        me = cur.fetchone()
        _push_to_user(
            cur, target_user_id,
            title="🎉 ตอบรับคำขอเป็นเพื่อนแล้ว",
            body=f"{me['username'] if me else 'ผู้ใช้'} ตอบรับคำขอของคุณแล้ว",
            data={"type": "friend_accepted", "from_user_id": user_id},
        )
        conn.commit()
        return {"status": "accepted"}
    except HTTPException:
        conn.rollback()
        raise
    except Exception as exc:
        conn.rollback()
        raise HTTPException(status_code=500, detail=str(exc))
    finally:
        if conn:
            conn.close()


@router.delete("/friends/{target_user_id}")
def remove_friend(target_user_id: int, current_user: dict = Depends(get_current_user)):
    user_id = _require_user_id(current_user)
    conn = get_db_connection()
    if not conn:
        raise HTTPException(status_code=503, detail="Database unavailable")
    try:
        cur = conn.cursor()
        cur.execute(
            """
            DELETE FROM cleangoal.friendships
             WHERE (user_id = %s AND friend_id = %s)
                OR (user_id = %s AND friend_id = %s)
            """,
            (user_id, target_user_id, target_user_id, user_id),
        )
        conn.commit()
        return {"status": "removed"}
    except Exception as exc:
        conn.rollback()
        raise HTTPException(status_code=500, detail=str(exc))
    finally:
        if conn:
            conn.close()


@router.post("/friends/{target_user_id}/block")
def block_user(target_user_id: int, current_user: dict = Depends(get_current_user)):
    user_id = _require_user_id(current_user)
    if target_user_id == user_id:
        raise HTTPException(status_code=400, detail="บล็อกตัวเองไม่ได้")
    conn = get_db_connection()
    if not conn:
        raise HTTPException(status_code=503, detail="Database unavailable")
    try:
        cur = conn.cursor()
        # Unilateral block: only MY row goes to 'blocked'. Inverse row may exist; leave it.
        cur.execute(
            """
            INSERT INTO cleangoal.friendships (user_id, friend_id, status)
            VALUES (%s, %s, 'blocked')
            ON CONFLICT (user_id, friend_id) DO UPDATE SET status = 'blocked'
            """,
            (user_id, target_user_id),
        )
        # Also remove the inverse accepted/pending row so the blocked user can't message me
        cur.execute(
            "DELETE FROM cleangoal.friendships WHERE user_id = %s AND friend_id = %s AND status <> 'blocked'",
            (target_user_id, user_id),
        )
        conn.commit()
        return {"status": "blocked"}
    except Exception as exc:
        conn.rollback()
        raise HTTPException(status_code=500, detail=str(exc))
    finally:
        if conn:
            conn.close()


# ═══════════════════════════════════════════════════════════════════════════
# Section 3 — Conversations
# ═══════════════════════════════════════════════════════════════════════════

def _assert_member(cur, conversation_id: int, user_id: int) -> dict:
    cur.execute(
        """
        SELECT role, last_read_message_id, muted, archived
        FROM cleangoal.conversation_members
        WHERE conversation_id = %s AND user_id = %s
        """,
        (conversation_id, user_id),
    )
    row = cur.fetchone()
    if not row:
        raise HTTPException(status_code=403, detail="คุณไม่ใช่สมาชิกของห้องสนทนานี้")
    return row


@router.get("/conversations")
def list_conversations(current_user: dict = Depends(get_current_user)):
    user_id = _require_user_id(current_user)
    conn = get_db_connection()
    if not conn:
        raise HTTPException(status_code=503, detail="Database unavailable")
    try:
        cur = conn.cursor(cursor_factory=RealDictCursor)
        # Unread count derived from last_read_message_id (0 means everything unread)
        cur.execute(
            """
            SELECT c.conversation_id,
                   c.type,
                   c.name,
                   c.avatar_url,
                   c.created_at,
                   c.last_message_at,
                   c.last_message_id,
                   m.muted,
                   m.archived,
                   m.last_read_message_id,
                   lm.body          AS last_message_body,
                   lm.kind          AS last_message_kind,
                   lm.sender_user_id AS last_message_sender,
                   (
                     SELECT COUNT(*)
                     FROM cleangoal.messages mm
                     WHERE mm.conversation_id = c.conversation_id
                       AND mm.deleted_at IS NULL
                       AND mm.message_id > COALESCE(m.last_read_message_id, 0)
                       AND mm.sender_user_id IS DISTINCT FROM %s
                   ) AS unread_count,
                   -- DM peer info for the list tile
                   peer.user_id  AS peer_user_id,
                   peer.username AS peer_username,
                   peer.avatar_url AS peer_avatar
            FROM cleangoal.conversation_members m
            JOIN cleangoal.conversations c        ON c.conversation_id = m.conversation_id
            LEFT JOIN cleangoal.messages lm       ON lm.message_id    = c.last_message_id
            LEFT JOIN LATERAL (
              SELECT u.user_id, u.username, u.avatar_url
              FROM cleangoal.conversation_members cm
              JOIN cleangoal.users u ON u.user_id = cm.user_id
              WHERE cm.conversation_id = c.conversation_id
                AND cm.user_id <> %s
                AND c.type = 'dm'
              LIMIT 1
            ) peer ON TRUE
            WHERE m.user_id = %s
            ORDER BY c.last_message_at DESC NULLS LAST, c.conversation_id DESC
            """,
            (user_id, user_id, user_id),
        )
        rows = [_row_to_iso(r, ["created_at", "last_message_at"]) for r in cur.fetchall()]
        return rows
    finally:
        if conn:
            conn.close()


@router.post("/conversations/dm")
def create_or_get_dm(body: CreateDmBody, current_user: dict = Depends(get_current_user)):
    """Get-or-create a DM with `body.user_id`. Always returns the same id for
    the same pair (enforced by dm_pairs UNIQUE)."""
    me = _require_user_id(current_user)
    other = int(body.user_id)
    if other == me:
        raise HTTPException(status_code=400, detail="ไม่สามารถสร้างแชทกับตัวเองได้")
    conn = get_db_connection()
    if not conn:
        raise HTTPException(status_code=503, detail="Database unavailable")
    try:
        cur = conn.cursor(cursor_factory=RealDictCursor)
        cur.execute(
            "SELECT 1 FROM cleangoal.users WHERE user_id = %s AND deleted_at IS NULL",
            (other,),
        )
        if not cur.fetchone():
            raise HTTPException(status_code=404, detail="ไม่พบผู้ใช้นี้")

        # Block guard — neither side has blocked the other
        cur.execute(
            """
            SELECT 1 FROM cleangoal.friendships
             WHERE ((user_id = %s AND friend_id = %s) OR (user_id = %s AND friend_id = %s))
               AND status = 'blocked'
             LIMIT 1
            """,
            (me, other, other, me),
        )
        if cur.fetchone():
            raise HTTPException(status_code=403, detail="ไม่สามารถสร้างแชทได้")

        low, high = (me, other) if me < other else (other, me)

        cur.execute(
            "SELECT conversation_id FROM cleangoal.dm_pairs WHERE user_low = %s AND user_high = %s",
            (low, high),
        )
        existing = cur.fetchone()
        if existing:
            return {"conversation_id": int(existing["conversation_id"]), "created": False}

        cur.execute(
            """
            INSERT INTO cleangoal.conversations (type, created_by)
            VALUES ('dm', %s)
            RETURNING conversation_id
            """,
            (me,),
        )
        conv_id = int(cur.fetchone()["conversation_id"])

        # Race-safe pair insert (rolls back if someone beat us to it)
        try:
            cur.execute(
                "INSERT INTO cleangoal.dm_pairs (user_low, user_high, conversation_id) VALUES (%s, %s, %s)",
                (low, high, conv_id),
            )
        except Exception:
            conn.rollback()
            cur = conn.cursor(cursor_factory=RealDictCursor)
            cur.execute(
                "SELECT conversation_id FROM cleangoal.dm_pairs WHERE user_low = %s AND user_high = %s",
                (low, high),
            )
            return {"conversation_id": int(cur.fetchone()["conversation_id"]), "created": False}

        for uid in (me, other):
            cur.execute(
                """
                INSERT INTO cleangoal.conversation_members (conversation_id, user_id, role)
                VALUES (%s, %s, 'member')
                """,
                (conv_id, uid),
            )

        conn.commit()
        return {"conversation_id": conv_id, "created": True}
    except HTTPException:
        conn.rollback()
        raise
    except Exception as exc:
        conn.rollback()
        raise HTTPException(status_code=500, detail=str(exc))
    finally:
        if conn:
            conn.close()


@router.post("/conversations/group")
def create_group(body: CreateGroupBody, current_user: dict = Depends(get_current_user)):
    user_id = _require_user_id(current_user)
    members = list({user_id, *body.member_user_ids})
    if len(members) < 2:
        raise HTTPException(status_code=400, detail="กลุ่มต้องมีสมาชิกอย่างน้อย 2 คน")
    conn = get_db_connection()
    if not conn:
        raise HTTPException(status_code=503, detail="Database unavailable")
    try:
        cur = conn.cursor(cursor_factory=RealDictCursor)
        # Validate all member users exist
        cur.execute(
            "SELECT user_id FROM cleangoal.users WHERE user_id = ANY(%s) AND deleted_at IS NULL",
            (members,),
        )
        valid = {int(r["user_id"]) for r in cur.fetchall()}
        missing = set(members) - valid
        if missing:
            raise HTTPException(status_code=404, detail=f"ไม่พบผู้ใช้: {sorted(missing)}")

        cur.execute(
            """
            INSERT INTO cleangoal.conversations (type, name, created_by)
            VALUES ('group', %s, %s)
            RETURNING conversation_id
            """,
            (body.name.strip(), user_id),
        )
        conv_id = int(cur.fetchone()["conversation_id"])

        execute_values(
            cur,
            "INSERT INTO cleangoal.conversation_members (conversation_id, user_id, role) VALUES %s",
            [(conv_id, uid, 'admin' if uid == user_id else 'member') for uid in members],
        )

        # Optional system message
        cur.execute(
            """
            INSERT INTO cleangoal.messages (conversation_id, sender_user_id, kind, body)
            VALUES (%s, NULL, 'system', %s)
            """,
            (conv_id, f"สร้างกลุ่ม '{body.name}' แล้ว"),
        )

        conn.commit()
        return {"conversation_id": conv_id}
    except HTTPException:
        conn.rollback()
        raise
    except Exception as exc:
        conn.rollback()
        raise HTTPException(status_code=500, detail=str(exc))
    finally:
        if conn:
            conn.close()


@router.get("/conversations/{conversation_id}")
def get_conversation(conversation_id: int, current_user: dict = Depends(get_current_user)):
    user_id = _require_user_id(current_user)
    conn = get_db_connection()
    if not conn:
        raise HTTPException(status_code=503, detail="Database unavailable")
    try:
        cur = conn.cursor(cursor_factory=RealDictCursor)
        _assert_member(cur, conversation_id, user_id)

        cur.execute(
            "SELECT * FROM cleangoal.conversations WHERE conversation_id = %s",
            (conversation_id,),
        )
        conv = cur.fetchone()
        if not conv:
            raise HTTPException(status_code=404, detail="ไม่พบห้องสนทนา")

        cur.execute(
            """
            SELECT m.user_id, m.role, m.joined_at,
                   u.username, u.avatar_url,
                   COALESCE(p.status, 'offline') AS presence, p.last_seen_at
            FROM cleangoal.conversation_members m
            JOIN cleangoal.users u           ON u.user_id = m.user_id
            LEFT JOIN cleangoal.user_presence p ON p.user_id = m.user_id
            WHERE m.conversation_id = %s
            ORDER BY (m.role = 'admin') DESC, u.username
            """,
            (conversation_id,),
        )
        members = [_row_to_iso(r, ["joined_at", "last_seen_at"]) for r in cur.fetchall()]
        return {
            **_row_to_iso(conv, ["created_at", "last_message_at"]),
            "members": members,
        }
    finally:
        if conn:
            conn.close()


@router.post("/conversations/{conversation_id}/members")
def add_members(
    conversation_id: int,
    body: AddMembersBody,
    current_user: dict = Depends(get_current_user),
):
    user_id = _require_user_id(current_user)
    conn = get_db_connection()
    if not conn:
        raise HTTPException(status_code=503, detail="Database unavailable")
    try:
        cur = conn.cursor(cursor_factory=RealDictCursor)
        my_membership = _assert_member(cur, conversation_id, user_id)
        if my_membership["role"] != 'admin':
            raise HTTPException(status_code=403, detail="ต้องเป็น admin ของกลุ่ม")

        cur.execute(
            "SELECT type FROM cleangoal.conversations WHERE conversation_id = %s",
            (conversation_id,),
        )
        row = cur.fetchone()
        if not row:
            raise HTTPException(status_code=404, detail="ไม่พบห้องสนทนา")
        if row["type"] != 'group':
            raise HTTPException(status_code=400, detail="เพิ่มสมาชิกได้เฉพาะกลุ่ม")

        execute_values(
            cur,
            """
            INSERT INTO cleangoal.conversation_members (conversation_id, user_id, role)
            VALUES %s
            ON CONFLICT (conversation_id, user_id) DO NOTHING
            """,
            [(conversation_id, int(uid), 'member') for uid in body.member_user_ids],
        )
        conn.commit()
        return {"added": len(body.member_user_ids)}
    except HTTPException:
        conn.rollback()
        raise
    except Exception as exc:
        conn.rollback()
        raise HTTPException(status_code=500, detail=str(exc))
    finally:
        if conn:
            conn.close()


@router.delete("/conversations/{conversation_id}/members/{target_user_id}")
def remove_member(
    conversation_id: int,
    target_user_id: int,
    current_user: dict = Depends(get_current_user),
):
    """Admin can kick. Member can leave (target == self)."""
    user_id = _require_user_id(current_user)
    conn = get_db_connection()
    if not conn:
        raise HTTPException(status_code=503, detail="Database unavailable")
    try:
        cur = conn.cursor(cursor_factory=RealDictCursor)
        my_membership = _assert_member(cur, conversation_id, user_id)
        if user_id != target_user_id and my_membership["role"] != 'admin':
            raise HTTPException(status_code=403, detail="เฉพาะ admin ที่ลบสมาชิกอื่นได้")

        cur.execute(
            "DELETE FROM cleangoal.conversation_members WHERE conversation_id = %s AND user_id = %s",
            (conversation_id, target_user_id),
        )
        conn.commit()
        return {"removed": True}
    except HTTPException:
        conn.rollback()
        raise
    except Exception as exc:
        conn.rollback()
        raise HTTPException(status_code=500, detail=str(exc))
    finally:
        if conn:
            conn.close()


# ═══════════════════════════════════════════════════════════════════════════
# Section 4 — Messages
# ═══════════════════════════════════════════════════════════════════════════

@router.get("/conversations/{conversation_id}/messages")
def list_messages(
    conversation_id: int,
    before: Optional[int] = Query(default=None, description="message_id cursor (keyset pagination)"),
    limit: int = Query(default=50, ge=1, le=100),
    current_user: dict = Depends(get_current_user),
):
    user_id = _require_user_id(current_user)
    conn = get_db_connection()
    if not conn:
        raise HTTPException(status_code=503, detail="Database unavailable")
    try:
        cur = conn.cursor(cursor_factory=RealDictCursor)
        _assert_member(cur, conversation_id, user_id)

        if before:
            cur.execute(
                """
                SELECT * FROM cleangoal.messages
                WHERE conversation_id = %s AND message_id < %s
                ORDER BY message_id DESC
                LIMIT %s
                """,
                (conversation_id, before, limit),
            )
        else:
            cur.execute(
                """
                SELECT * FROM cleangoal.messages
                WHERE conversation_id = %s
                ORDER BY message_id DESC
                LIMIT %s
                """,
                (conversation_id, limit),
            )
        rows = [_row_to_iso(r, ["created_at", "edited_at", "deleted_at"]) for r in cur.fetchall()]
        return rows
    finally:
        if conn:
            conn.close()


def _fanout_message_push(cur, conversation_id: int, sender_id: int, body: SendMessageBody) -> None:
    """Send FCM to members who appear offline + not muted + not the sender."""
    cur.execute(
        """
        SELECT u.fcm_token, u.username
        FROM cleangoal.conversation_members m
        JOIN cleangoal.users u           ON u.user_id = m.user_id
        LEFT JOIN cleangoal.user_presence p ON p.user_id = m.user_id
        WHERE m.conversation_id = %s
          AND m.user_id <> %s
          AND m.muted = FALSE
          AND u.fcm_token IS NOT NULL
          AND (
            p.user_id IS NULL
            OR p.status <> 'online'
            OR p.last_seen_at < NOW() - (INTERVAL '1 second' * %s)
          )
        """,
        (conversation_id, sender_id, _OFFLINE_AFTER_SECONDS),
    )
    tokens = [r["fcm_token"] for r in cur.fetchall()]
    if not tokens:
        return

    # Sender username for notification title
    cur.execute("SELECT username FROM cleangoal.users WHERE user_id = %s", (sender_id,))
    sender_row = cur.fetchone()
    sender_name = sender_row["username"] if sender_row else "ผู้ใช้"

    preview = body.body or {
        "image": "📷 ส่งรูปภาพ",
        "file": "📎 ส่งไฟล์",
    }.get(body.kind, "ข้อความใหม่")

    send_push_to_tokens(
        tokens,
        title=sender_name,
        body=preview[:140],
        data={"type": "chat", "conversation_id": conversation_id},
    )


@router.post("/conversations/{conversation_id}/messages")
def send_message(
    conversation_id: int,
    body: SendMessageBody,
    current_user: dict = Depends(get_current_user),
):
    user_id = _require_user_id(current_user)
    if not body.body and not body.attachment_url:
        raise HTTPException(status_code=400, detail="ต้องระบุ body หรือ attachment_url")
    conn = get_db_connection()
    if not conn:
        raise HTTPException(status_code=503, detail="Database unavailable")
    try:
        cur = conn.cursor(cursor_factory=RealDictCursor)
        _assert_member(cur, conversation_id, user_id)

        cur.execute(
            """
            INSERT INTO cleangoal.messages
              (conversation_id, sender_user_id, kind, body,
               attachment_url, attachment_mime, attachment_size, attachment_name,
               reply_to_message_id)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
            RETURNING *
            """,
            (
                conversation_id, user_id, body.kind, body.body,
                body.attachment_url, body.attachment_mime, body.attachment_size, body.attachment_name,
                body.reply_to_message_id,
            ),
        )
        new_msg = cur.fetchone()

        # Sender's own last_read advances automatically (so their unread count stays 0)
        cur.execute(
            """
            UPDATE cleangoal.conversation_members
               SET last_read_message_id = %s
             WHERE conversation_id = %s AND user_id = %s
            """,
            (new_msg["message_id"], conversation_id, user_id),
        )

        try:
            _fanout_message_push(cur, conversation_id, user_id, body)
        except Exception:
            pass  # never block message send on FCM failure

        conn.commit()
        return _row_to_iso(new_msg, ["created_at", "edited_at", "deleted_at"])
    except HTTPException:
        conn.rollback()
        raise
    except Exception as exc:
        conn.rollback()
        raise HTTPException(status_code=500, detail=str(exc))
    finally:
        if conn:
            conn.close()


@router.patch("/messages/{message_id}")
def edit_message(message_id: int, body: EditMessageBody, current_user: dict = Depends(get_current_user)):
    user_id = _require_user_id(current_user)
    conn = get_db_connection()
    if not conn:
        raise HTTPException(status_code=503, detail="Database unavailable")
    try:
        cur = conn.cursor(cursor_factory=RealDictCursor)
        cur.execute(
            "SELECT sender_user_id, kind FROM cleangoal.messages WHERE message_id = %s AND deleted_at IS NULL",
            (message_id,),
        )
        row = cur.fetchone()
        if not row:
            raise HTTPException(status_code=404, detail="ไม่พบข้อความ")
        if row["sender_user_id"] != user_id:
            raise HTTPException(status_code=403, detail="แก้ไขได้เฉพาะข้อความตัวเอง")
        if row["kind"] != "text":
            raise HTTPException(status_code=400, detail="แก้ไขได้เฉพาะข้อความตัวอักษร")

        cur.execute(
            """
            UPDATE cleangoal.messages
               SET body = %s, edited_at = NOW()
             WHERE message_id = %s
             RETURNING *
            """,
            (body.body, message_id),
        )
        updated = cur.fetchone()
        conn.commit()
        return _row_to_iso(updated, ["created_at", "edited_at", "deleted_at"])
    except HTTPException:
        conn.rollback()
        raise
    except Exception as exc:
        conn.rollback()
        raise HTTPException(status_code=500, detail=str(exc))
    finally:
        if conn:
            conn.close()


@router.delete("/messages/{message_id}")
def delete_message(message_id: int, current_user: dict = Depends(get_current_user)):
    user_id = _require_user_id(current_user)
    conn = get_db_connection()
    if not conn:
        raise HTTPException(status_code=503, detail="Database unavailable")
    try:
        cur = conn.cursor()
        cur.execute(
            "SELECT sender_user_id FROM cleangoal.messages WHERE message_id = %s AND deleted_at IS NULL",
            (message_id,),
        )
        row = cur.fetchone()
        if not row:
            raise HTTPException(status_code=404, detail="ไม่พบข้อความ")
        if row[0] != user_id:
            raise HTTPException(status_code=403, detail="ลบได้เฉพาะข้อความตัวเอง")

        cur.execute(
            "UPDATE cleangoal.messages SET deleted_at = NOW(), body = NULL, attachment_url = NULL WHERE message_id = %s",
            (message_id,),
        )
        conn.commit()
        return {"deleted": True}
    except HTTPException:
        conn.rollback()
        raise
    except Exception as exc:
        conn.rollback()
        raise HTTPException(status_code=500, detail=str(exc))
    finally:
        if conn:
            conn.close()


@router.post("/conversations/{conversation_id}/read")
def mark_read(conversation_id: int, body: MarkReadBody, current_user: dict = Depends(get_current_user)):
    user_id = _require_user_id(current_user)
    conn = get_db_connection()
    if not conn:
        raise HTTPException(status_code=503, detail="Database unavailable")
    try:
        cur = conn.cursor()
        # never go backwards — keep the highest seen id
        cur.execute(
            """
            UPDATE cleangoal.conversation_members
               SET last_read_message_id = GREATEST(COALESCE(last_read_message_id, 0), %s)
             WHERE conversation_id = %s AND user_id = %s
            """,
            (body.message_id, conversation_id, user_id),
        )
        if cur.rowcount == 0:
            raise HTTPException(status_code=403, detail="คุณไม่ใช่สมาชิกของห้องนี้")
        conn.commit()
        return {"last_read_message_id": body.message_id}
    except HTTPException:
        conn.rollback()
        raise
    except Exception as exc:
        conn.rollback()
        raise HTTPException(status_code=500, detail=str(exc))
    finally:
        if conn:
            conn.close()


# ═══════════════════════════════════════════════════════════════════════════
# Section 5 — Uploads + Presence
# ═══════════════════════════════════════════════════════════════════════════

@router.post("/uploads/chat")
async def upload_chat_file(
    conversation_id: int = Form(...),
    file: UploadFile = File(...),
    current_user: dict = Depends(get_current_user),
):
    user_id = _require_user_id(current_user)
    conn = get_db_connection()
    if not conn:
        raise HTTPException(status_code=503, detail="Database unavailable")
    try:
        cur = conn.cursor(cursor_factory=RealDictCursor)
        _assert_member(cur, conversation_id, user_id)
    finally:
        if conn:
            conn.close()

    try:
        data = await file.read()
        result = upload_chat_attachment(
            data,
            original_filename=file.filename or "upload",
            conversation_id=conversation_id,
            sender_user_id=user_id,
        )
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))
    return result


@router.post("/presence/heartbeat")
def presence_heartbeat(body: PresenceHeartbeatBody, current_user: dict = Depends(get_current_user)):
    user_id = _require_user_id(current_user)
    conn = get_db_connection()
    if not conn:
        raise HTTPException(status_code=503, detail="Database unavailable")
    try:
        cur = conn.cursor()
        cur.execute(
            """
            INSERT INTO cleangoal.user_presence (user_id, status, last_seen_at)
            VALUES (%s, %s, NOW())
            ON CONFLICT (user_id) DO UPDATE SET
                status = EXCLUDED.status,
                last_seen_at = NOW()
            """,
            (user_id, body.status),
        )
        conn.commit()
        return {"status": body.status, "last_seen_at": datetime.now(timezone.utc).isoformat()}
    except Exception as exc:
        conn.rollback()
        raise HTTPException(status_code=500, detail=str(exc))
    finally:
        if conn:
            conn.close()


@router.get("/presence")
def get_presence_for_users(
    user_ids: str = Query(..., description="Comma-separated user ids"),
    current_user: dict = Depends(get_current_user),
):
    _require_user_id(current_user)
    try:
        ids = [int(x) for x in user_ids.split(",") if x.strip()]
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid user_ids")
    if not ids:
        return []
    if len(ids) > 200:
        raise HTTPException(status_code=400, detail="ขอ presence ได้สูงสุด 200 users ต่อครั้ง")
    conn = get_db_connection()
    if not conn:
        raise HTTPException(status_code=503, detail="Database unavailable")
    try:
        cur = conn.cursor(cursor_factory=RealDictCursor)
        cur.execute(
            """
            SELECT user_id, status, last_seen_at
            FROM cleangoal.user_presence
            WHERE user_id = ANY(%s)
            """,
            (ids,),
        )
        rows = [_row_to_iso(r, ["last_seen_at"]) for r in cur.fetchall()]
        return rows
    finally:
        if conn:
            conn.close()
