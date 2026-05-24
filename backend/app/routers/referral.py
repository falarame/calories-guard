import random
import string
from datetime import datetime, timezone, timedelta

from fastapi import APIRouter, HTTPException, Depends
from psycopg2.extras import RealDictCursor

from database import get_db_connection
from auth.dependencies import get_current_user
from app.core.dependencies import check_ownership

router = APIRouter()

_BUFF_DAYS = 7
_INVITER_GEMS = 50
_INVITEE_GEMS = 30
_MAX_ACCOUNT_AGE_DAYS = 7


def _gen_code() -> str:
    prefix = random.choice(["RICE", "MEAL", "KCAL", "SEED", "GOAL"])
    suffix = "".join(random.choices(string.digits, k=4))
    return f"{prefix}-{suffix}"


@router.post("/referral/generate")
def generate_referral_code(current_user: dict = Depends(get_current_user)):
    """Return existing code or create a new one for the authenticated user."""
    user_id = current_user["user_id"]
    conn = None
    try:
        conn = get_db_connection()
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                "SELECT code FROM cleangoal.referral_codes WHERE owner_id = %s",
                (user_id,),
            )
            row = cur.fetchone()
            if row:
                return {"code": row["code"]}

            # Generate a unique code
            for _ in range(10):
                code = _gen_code()
                cur.execute(
                    "SELECT 1 FROM cleangoal.referral_codes WHERE code = %s", (code,)
                )
                if not cur.fetchone():
                    break
            else:
                raise HTTPException(status_code=500, detail="Could not generate unique code")

            cur.execute(
                "INSERT INTO cleangoal.referral_codes (code, owner_id) VALUES (%s, %s)",
                (code, user_id),
            )
            conn.commit()
            return {"code": code}
    except HTTPException:
        raise
    except Exception as e:
        if conn:
            conn.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        if conn:
            conn.close()


@router.post("/referral/redeem")
def redeem_referral_code(payload: dict, current_user: dict = Depends(get_current_user)):
    """
    New user redeems a referral code.
    Rules:
    - Account must be <= 7 days old.
    - Each user can only redeem once.
    - Code owner cannot redeem their own code.
    Rewards:
    - New user: +INVITEE_GEMS gems + 7-day x2 gem buff
    - Inviter: +INVITER_GEMS gems
    """
    redeemer_id = current_user["user_id"]
    code = (payload.get("code") or "").strip().upper()
    if not code:
        raise HTTPException(status_code=400, detail="code is required")

    conn = None
    try:
        conn = get_db_connection()
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            # 1. Check account age
            cur.execute(
                "SELECT created_at FROM cleangoal.users WHERE user_id = %s",
                (redeemer_id,),
            )
            user_row = cur.fetchone()
            if not user_row:
                raise HTTPException(status_code=404, detail="User not found")
            created_at = user_row["created_at"]
            if created_at.tzinfo is None:
                created_at = created_at.replace(tzinfo=timezone.utc)
            age_days = (datetime.now(timezone.utc) - created_at).days
            if age_days > _MAX_ACCOUNT_AGE_DAYS:
                raise HTTPException(
                    status_code=403,
                    detail=f"Account must be at most {_MAX_ACCOUNT_AGE_DAYS} days old to use a referral code",
                )

            # 2. Validate code + owner
            cur.execute(
                "SELECT owner_id FROM cleangoal.referral_codes WHERE code = %s", (code,)
            )
            code_row = cur.fetchone()
            if not code_row:
                raise HTTPException(status_code=404, detail="Invalid referral code")
            owner_id = int(code_row["owner_id"])
            if owner_id == redeemer_id:
                raise HTTPException(status_code=400, detail="Cannot use your own referral code")

            # 3. Check not already redeemed by this user
            cur.execute(
                "SELECT 1 FROM cleangoal.referral_redemptions WHERE redeemed_by = %s",
                (redeemer_id,),
            )
            if cur.fetchone():
                raise HTTPException(status_code=409, detail="You have already used a referral code")

            # 4. Record redemption
            cur.execute(
                "INSERT INTO cleangoal.referral_redemptions (code, redeemed_by) VALUES (%s, %s)",
                (code, redeemer_id),
            )

            buff_expires = datetime.now(timezone.utc) + timedelta(days=_BUFF_DAYS)

            # 5. Reward new user: gems + x2 buff
            cur.execute(
                """
                INSERT INTO cleangoal.user_gamification
                    (user_id, gems, gem_buff_multiplier, gem_buff_expires_at, gems_updated_at, updated_at)
                VALUES (%s, %s, 2, %s, NOW(), NOW())
                ON CONFLICT (user_id) DO UPDATE
                  SET gems                 = cleangoal.user_gamification.gems + %s,
                      gem_buff_multiplier  = 2,
                      gem_buff_expires_at  = %s,
                      gems_updated_at      = NOW(),
                      updated_at           = NOW()
                """,
                (redeemer_id, _INVITEE_GEMS, buff_expires, _INVITEE_GEMS, buff_expires),
            )

            # 6. Reward inviter: gems
            cur.execute(
                """
                INSERT INTO cleangoal.user_gamification
                    (user_id, gems, gems_updated_at, updated_at)
                VALUES (%s, %s, NOW(), NOW())
                ON CONFLICT (user_id) DO UPDATE
                  SET gems            = cleangoal.user_gamification.gems + %s,
                      gems_updated_at = NOW(),
                      updated_at      = NOW()
                """,
                (owner_id, _INVITER_GEMS, _INVITER_GEMS),
            )

        conn.commit()
        return {
            "ok": True,
            "invitee_gems": _INVITEE_GEMS,
            "buff_days": _BUFF_DAYS,
            "buff_expires_at": buff_expires.isoformat(),
            "inviter_gems_awarded": _INVITER_GEMS,
        }
    except HTTPException:
        raise
    except Exception as e:
        if conn:
            conn.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        if conn:
            conn.close()


@router.get("/referral/invitees")
def get_referral_invitees(current_user: dict = Depends(get_current_user)):
    """Return list of users who redeemed the current user's code (for mission tracking)."""
    user_id = current_user["user_id"]
    conn = None
    try:
        conn = get_db_connection()
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                """
                SELECT rr.redeemed_by AS user_id, rr.redeemed_at
                FROM cleangoal.referral_redemptions rr
                JOIN cleangoal.referral_codes rc ON rc.code = rr.code
                WHERE rc.owner_id = %s
                ORDER BY rr.redeemed_at DESC
                """,
                (user_id,),
            )
            rows = cur.fetchall()
        return [dict(r) for r in rows]
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        if conn:
            conn.close()


@router.get("/referral/status")
def get_referral_status(current_user: dict = Depends(get_current_user)):
    """Return the user's referral code and active buff info."""
    user_id = current_user["user_id"]
    conn = None
    try:
        conn = get_db_connection()
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                "SELECT code FROM cleangoal.referral_codes WHERE owner_id = %s",
                (user_id,),
            )
            code_row = cur.fetchone()

            cur.execute(
                """
                SELECT COALESCE(gem_buff_multiplier, 1) AS gem_buff_multiplier,
                       gem_buff_expires_at
                FROM cleangoal.user_gamification WHERE user_id = %s
                """,
                (user_id,),
            )
            buff_row = cur.fetchone()

        now = datetime.now(timezone.utc)
        buff_active = False
        buff_expires_at = None
        multiplier = 1
        if buff_row:
            exp = buff_row.get("gem_buff_expires_at")
            if exp:
                if exp.tzinfo is None:
                    exp = exp.replace(tzinfo=timezone.utc)
                if exp > now:
                    buff_active = True
                    buff_expires_at = exp.isoformat()
                    multiplier = int(buff_row.get("gem_buff_multiplier") or 1)

        return {
            "code": code_row["code"] if code_row else None,
            "buff_active": buff_active,
            "gem_buff_multiplier": multiplier,
            "buff_expires_at": buff_expires_at,
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        if conn:
            conn.close()
