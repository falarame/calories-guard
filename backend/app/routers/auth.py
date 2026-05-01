import os
import re
import secrets
from datetime import date, datetime, timedelta, timezone
from random import randint

from fastapi import APIRouter, HTTPException, Request, Depends
from psycopg2.extras import RealDictCursor
from slowapi import Limiter
from slowapi.util import get_remote_address
from jose import jwt
import requests

from database import get_db_connection
from app.core.security import get_password_hash, verify_password
from app.core.observability import track


_JWT_SECRET = os.getenv("SUPABASE_JWT_SECRET", "")
_SUPABASE_URL = os.getenv("SUPABASE_URL") or os.getenv("SUPABASE_PROJECT_URL", "")
_SUPABASE_ANON_KEY = os.getenv("SUPABASE_ANON_KEY", "")
_JWT_ALGO = "HS256"
_JWT_TTL_HOURS = 12


def _issue_access_token(user_id: int, email: str, role_id: int) -> str:
    """
    Issue an HS256 JWT signed with SUPABASE_JWT_SECRET so that
    backend's get_current_user / get_current_admin can verify it.
    Payload mirrors what Supabase Auth would set, so the same
    verification path works for both self-issued + Supabase tokens.
    """
    now = datetime.utcnow()
    payload = {
        "sub": f"cg-user-{user_id}",
        "email": email,
        "role": "authenticated",
        "iat": int(now.timestamp()),
        "exp": int((now + timedelta(hours=_JWT_TTL_HOURS)).timestamp()),
        "app_metadata": {"user_id": user_id, "role_id": role_id},
    }
    return jwt.encode(payload, _JWT_SECRET, algorithm=_JWT_ALGO)


def _onboarding_required(user: dict) -> bool:
    """True when the profile still misses fields collected in onboarding."""
    required_fields = (
        "gender",
        "birth_date",
        "height_cm",
        "current_weight_kg",
        "activity_level",
        "goal_type",
        "target_weight_kg",
        "goal_target_date",
    )
    return any(not user.get(field) for field in required_fields)


def _decode_optional_bearer(request: Request) -> dict | None:
    """Return a verified Supabase/backend JWT payload if Authorization exists."""
    auth_header = request.headers.get("authorization") or ""
    scheme, _, token = auth_header.partition(" ")
    if scheme.lower() != "bearer" or not token:
        return None
    try:
        return jwt.decode(
            token,
            _JWT_SECRET,
            algorithms=[_JWT_ALGO],
            options={"verify_aud": False},
        )
    except Exception:
        return _fetch_supabase_user_payload(token)


def _fetch_supabase_user_payload(token: str) -> dict | None:
    """Validate a Supabase access token with Supabase Auth as a fallback."""
    if not _SUPABASE_URL or not _SUPABASE_ANON_KEY:
        return None
    try:
        response = requests.get(
            f"{_SUPABASE_URL.rstrip('/')}/auth/v1/user",
            headers={
                "apikey": _SUPABASE_ANON_KEY,
                "Authorization": f"Bearer {token}",
            },
            timeout=5,
        )
    except requests.RequestException:
        return None
    if response.status_code != 200:
        return None
    data = response.json()
    return {
        "sub": data.get("id"),
        "email": data.get("email"),
        "role": "authenticated",
        "app_metadata": data.get("app_metadata") or {},
        "user_metadata": data.get("user_metadata") or {},
    }


def _token_email_matches(payload: dict | None, email: str) -> bool:
    if not payload:
        return False
    token_email = (payload.get("email") or "").strip().lower()
    return bool(token_email) and token_email == email
from app.services.email_service import (
    send_welcome_email, send_verification_email, send_password_reset_email,
)
from app.models.schemas import (
    UserRegister, UserLogin, UserVerifyEmail,
    PasswordResetRequest, PasswordResetVerify, PasswordResetConfirm,
    SocialLoginRequest,
)

router = APIRouter()
limiter = Limiter(key_func=get_remote_address)


def _generate_code() -> str:
    return f"{randint(100000, 999999)}"


def _init_password_reset_table():
    conn = get_db_connection()
    if not conn:
        return
    try:
        cur = conn.cursor()
        cur.execute("""
        CREATE TABLE IF NOT EXISTS password_reset_codes (
            id BIGSERIAL PRIMARY KEY,
            user_id BIGINT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
            code VARCHAR(10) NOT NULL,
            expires_at TIMESTAMP NOT NULL,
            used BOOLEAN DEFAULT FALSE,
            created_at TIMESTAMP DEFAULT NOW()
        )
        """)
        conn.commit()
    except Exception as e:
        print('Could not create password reset table:', e)
    finally:
        conn.close()


_init_password_reset_table()


_EMAIL_RE = re.compile(r'^[\w\.\-\+]+@[\w\-]+(\.[\w\-]+)*\.[a-zA-Z]{2,}$')


def _normalize_email(email: str) -> str:
    """Lowercase + strip. Emails are case-insensitive in practice; store normalized."""
    return (email or "").strip().lower()


def _email_exists(cur, email: str) -> bool:
    cur.execute("SELECT 1 FROM users WHERE LOWER(email) = %s LIMIT 1", (email,))
    return cur.fetchone() is not None


def _get_user_by_email(cur, email: str) -> dict | None:
    cur.execute("SELECT * FROM users WHERE LOWER(email) = %s AND deleted_at IS NULL LIMIT 1", (email,))
    return cur.fetchone()


@router.get("/check-email")
@limiter.limit("20/minute")
def check_email(request: Request, email: str):
    """
    Live availability check used by the register screen as the user types.
    Returns {available: bool, reason: str|None}. Rate-limited to curb enumeration.
    """
    normalized = _normalize_email(email)
    if not normalized:
        return {"available": False, "reason": "format"}
    if not _EMAIL_RE.match(normalized):
        return {"available": False, "reason": "format"}
    conn = get_db_connection()
    try:
        cur = conn.cursor(cursor_factory=RealDictCursor)
        existing_user = _get_user_by_email(cur, normalized)
        if existing_user and not existing_user.get("is_email_verified"):
            return {"available": False, "reason": "unverified"}
        if existing_user:
            return {"available": False, "reason": "taken"}
        return {"available": True, "reason": None}
    finally:
        if conn:
            conn.close()


@router.post("/register")
@limiter.limit("5/minute")
def register(request: Request, user: UserRegister):
    email = _normalize_email(user.email)
    if not _EMAIL_RE.match(email):
        raise HTTPException(status_code=400, detail="รูปแบบอีเมลไม่ถูกต้อง")
    username = (user.username or "").strip()
    if len(username) < 2:
        raise HTTPException(status_code=400, detail="ชื่อผู้ใช้ต้องมีอย่างน้อย 2 ตัวอักษร")
    if len(username) > 100:
        raise HTTPException(status_code=400, detail="ชื่อผู้ใช้ต้องไม่เกิน 100 ตัวอักษร")
    conn = get_db_connection()
    try:
        cur = conn.cursor(cursor_factory=RealDictCursor)
        hashed_pw = get_password_hash(user.password)
        existing_user = _get_user_by_email(cur, email)
        if existing_user:
            if existing_user.get("is_email_verified"):
                # 409 Conflict is the correct status for duplicate resource
                raise HTTPException(status_code=409, detail="อีเมลนี้ถูกใช้งานแล้ว")
            cur.execute("""
                UPDATE users
                SET username = %s,
                    password_hash = %s,
                    updated_at = NOW()
                WHERE user_id = %s
                RETURNING user_id, email, username
            """, (username, hashed_pw, existing_user["user_id"]))
        else:
            try:
                cur.execute("""
                    INSERT INTO users (email, password_hash, username, role_id, is_email_verified)
                    VALUES (%s, %s, %s, 2, FALSE)
                    RETURNING user_id, email, username
                """, (email, hashed_pw, username))
            except Exception as e:
                conn.rollback()
                # psycopg2 UniqueViolation → race condition between check and insert
                if 'unique' in str(e).lower() or 'duplicate' in str(e).lower():
                    raise HTTPException(status_code=409, detail="อีเมลนี้ถูกใช้งานแล้ว")
                raise
        new_user = cur.fetchone()
        code = str(randint(100000, 999999))
        expires = datetime.now(timezone.utc) + timedelta(minutes=15)
        cur.execute("""
            CREATE TABLE IF NOT EXISTS email_verification_codes (
                id BIGSERIAL PRIMARY KEY, user_id BIGINT NOT NULL, code VARCHAR(10) NOT NULL,
                expires_at TIMESTAMP NOT NULL, used BOOLEAN DEFAULT FALSE
            )
        """)
        cur.execute("UPDATE email_verification_codes SET used = TRUE WHERE user_id = %s", (new_user['user_id'],))
        cur.execute("INSERT INTO email_verification_codes (user_id, code, expires_at) VALUES (%s, %s, %s)",
                    (new_user['user_id'], code, expires))
        conn.commit()
        try:
            send_verification_email(new_user['email'], new_user['username'], code)
        except Exception as e:
            # Don't fail registration if email send fails — user can request resend.
            print(f"[register] send_verification_email failed: {e}")
        return {"message": "User created. Please check email for verification code.", "user": new_user}
    except HTTPException:
        conn.rollback()
        raise
    except Exception:
        conn.rollback()
        raise HTTPException(status_code=500, detail="ลงทะเบียนไม่สำเร็จ กรุณาลองใหม่ภายหลัง")
    finally:
        if conn:
            conn.close()


@router.post("/verify-email")
def verify_email(req: UserVerifyEmail):
    """
    Sync users.is_email_verified = TRUE after Supabase Auth confirms the email.

    Supabase is the source of truth for email verification (it sends the OTP
    and validates it). The Flutter client calls Supabase.auth.verifyOTP(...)
    first; only on success does it hit this endpoint to mirror the state into
    our DB so /login can pass the is_email_verified check.

    As a fallback, we still honour the legacy backend-generated OTP stored in
    email_verification_codes (for dev environments that skip Supabase email).
    """
    conn = get_db_connection()
    try:
        cur = conn.cursor(cursor_factory=RealDictCursor)
        email = _normalize_email(req.email)
        cur.execute("SELECT * FROM users WHERE LOWER(email) = %s", (email,))
        user = cur.fetchone()
        if not user:
            raise HTTPException(status_code=404, detail="Email not found")

        if req.supabase_verified:
            code_record = None
        else:
            cur.execute(
                """SELECT * FROM email_verification_codes
                   WHERE user_id = %s AND code = %s AND used = FALSE
                   ORDER BY id DESC LIMIT 1""",
                (user['user_id'], req.code),
            )
            code_record = cur.fetchone()
            if not code_record or code_record['expires_at'] < datetime.now(timezone.utc):
                raise HTTPException(status_code=400, detail="รหัสไม่ถูกต้องหรือหมดอายุ")
            cur.execute(
                "UPDATE email_verification_codes SET used = TRUE WHERE id = %s",
                (code_record['id'],),
            )

        cur.execute(
            "UPDATE users SET is_email_verified = TRUE WHERE user_id = %s",
            (user['user_id'],),
        )
        conn.commit()

        # Welcome email is a nice-to-have; never block verification on SMTP.
        try:
            send_welcome_email(user['email'], user['username'])
        except Exception as e:
            print(f"[verify-email] send_welcome_email failed: {e}")

        return {
            "message": "Email verified successfully",
            "user_id": user['user_id'],
            "access_token": _issue_access_token(user['user_id'], user['email'], int(user.get('role_id') or 2)),
            "token_type": "bearer",
        }
    except HTTPException:
        conn.rollback()
        raise
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        if conn:
            conn.close()


@router.post("/resend-verification-email")
def resend_verification_email(req: PasswordResetRequest):
    conn = get_db_connection()
    try:
        cur = conn.cursor(cursor_factory=RealDictCursor)
        cur.execute("SELECT * FROM users WHERE LOWER(email) = %s", (_normalize_email(req.email),))
        user = cur.fetchone()
        if not user:
            raise HTTPException(status_code=404, detail="ไม่พบอีเมลนี้ในระบบ")
        if user['is_email_verified']:
            raise HTTPException(status_code=400, detail="อีเมลนี้ได้รับการยืนยันแล้ว")
        cur.execute("UPDATE email_verification_codes SET used = TRUE WHERE user_id = %s", (user['user_id'],))
        code = str(randint(100000, 999999))
        expires = datetime.now(timezone.utc) + timedelta(minutes=15)
        cur.execute("INSERT INTO email_verification_codes (user_id, code, expires_at) VALUES (%s, %s, %s)",
                    (user['user_id'], code, expires))
        conn.commit()
        send_verification_email(user['email'], user['username'], code)
        return {"message": "ส่งรหัสยืนยันใหม่ไปยังอีเมลแล้ว"}
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        if conn:
            conn.close()


@router.post("/login")
@limiter.limit("10/minute")
def login(request: Request, user: UserLogin):
    # SLO: login success rate is one of the three dashboard panels (#14)
    with track("auth.login", "POST /login", email_domain=(user.email or "").split("@")[-1]):
        return _login_impl(user, request)


def _login_impl(user, request: Request | None = None):
    email = _normalize_email(user.email)
    token_payload = _decode_optional_bearer(request) if request is not None else None
    authenticated_by_supabase = _token_email_matches(token_payload, email)
    conn = get_db_connection()
    try:
        cur = conn.cursor(cursor_factory=RealDictCursor)
        cur.execute("SELECT * FROM users WHERE LOWER(email) = %s AND deleted_at IS NULL", (email,))
        db_user = cur.fetchone()
        if not db_user:
            raise HTTPException(status_code=401, detail="Invalid email or password")
        if not authenticated_by_supabase and not verify_password(
            user.password, db_user['password_hash']
        ):
            raise HTTPException(status_code=401, detail="Invalid email or password")
        if not db_user.get('is_email_verified'):
            raise HTTPException(status_code=403, detail="Email not verified. Please check your inbox for the verification code.")

        today = date.today()
        last_login = db_user.get('last_login_date')
        if isinstance(last_login, datetime):
            last_login = last_login.date()
        total_days = int(db_user.get('total_login_days') or 0)
        streak = int(db_user.get('current_streak') or 0)
        if last_login != today:
            total_days += 1
            if last_login is None or (today - last_login).days > 1:
                streak = 1
            else:
                streak += 1
            cur.execute("""
                UPDATE users
                SET last_login_date = %s, total_login_days = %s, current_streak = %s
                WHERE user_id = %s
            """, (datetime.combine(today, datetime.min.time()), total_days, streak, db_user['user_id']))
            streak_milestones = {
                1: "ยินดีต้อนรับ! เริ่มต้นดูแลสุขภาพกับ Calories Guard วันนี้เลย",
                3: "ยอดเยี่ยม! คุณใช้แอปต่อเนื่อง 3 วันแล้ว ไปต่อได้เลย!",
                7: "เจ๋งมาก! 7 วันติดต่อกัน! คุณมีวินัยสุดๆ!",
                14: "สุดยอด! 2 สัปดาห์ติดต่อกันแล้ว นับถือมากครับ!",
                30: "ระดับตำนาน! 30 วันไม่เคยพลาด คุณทำได้แล้ว!",
            }
            if streak in streak_milestones:
                msg = streak_milestones[streak]
                cur.execute("""
                    INSERT INTO notifications (user_id, title, message, type)
                    VALUES (%s, %s, %s, 'achievement')
                    ON CONFLICT DO NOTHING
                """, (db_user['user_id'], f"Streak {streak} วัน!", msg))
        conn.commit()
        access_token = _issue_access_token(
            db_user['user_id'], db_user['email'], db_user['role_id']
        )
        return {
            "message": "Login successful",
            "user_id": db_user['user_id'],
            "username": db_user['username'],
            "email": db_user['email'],
            "role_id": db_user['role_id'],
            "current_streak": streak,
            "access_token": access_token,
            "token_type": "Bearer",
            "onboarding_required": _onboarding_required(db_user),
        }
    except HTTPException:
        raise
    except Exception:
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail="Login failed. Please try again later.")
    finally:
        if conn:
            conn.close()


@router.post("/social-login")
def social_login(body: SocialLoginRequest):
    email = _normalize_email(body.email)
    conn = get_db_connection()
    try:
        cur = conn.cursor(cursor_factory=RealDictCursor)
        cur.execute(
            "SELECT * FROM users WHERE LOWER(email) = %s AND deleted_at IS NULL",
            (email,)
        )
        user = cur.fetchone()
        if user:
            today = date.today()
            last_login = user.get('last_login_date')
            if last_login and hasattr(last_login, 'date'):
                last_login = last_login.date()
            total_days = int(user.get('total_login_days') or 0) + 1
            streak = int(user.get('current_streak') or 0)
            if last_login is None:
                streak = 1
            elif last_login == today:
                total_days -= 1
            elif (today - last_login).days == 1:
                streak += 1
            else:
                streak = 1
            cur.execute(
                """UPDATE users SET last_login_date = %s, total_login_days = %s,
                   current_streak = %s WHERE user_id = %s""",
                (today, total_days, streak, user['user_id'])
            )
            conn.commit()
            role_id = int(user.get('role_id') or 2)
            onboarding_required = _onboarding_required(user)
            return {
                "user_id": int(user['user_id']),
                "email": user['email'],
                "username": user.get('username') or body.name,
                "role_id": role_id,
                "provider": body.provider,
                "onboarding_required": onboarding_required,
                "access_token": _issue_access_token(
                    int(user['user_id']),
                    user['email'],
                    role_id,
                ),
                "token_type": "bearer",
            }
        else:
            fake_hash = secrets.token_hex(32)
            cur.execute(
                """INSERT INTO users
                   (username, email, password_hash, role_id, is_email_verified, created_at)
                   VALUES (%s, %s, %s, 2, TRUE, NOW())
                   RETURNING user_id""",
                (body.name, email, fake_hash)
            )
            row = cur.fetchone()
            new_id = row['user_id']
            conn.commit()
            return {
                "user_id": int(new_id),
                "email": email,
                "username": body.name,
                "role_id": 2,
                "provider": body.provider,
                "is_new_user": True,
                "onboarding_required": True,
                "access_token": _issue_access_token(int(new_id), email, 2),
                "token_type": "bearer",
            }
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        if conn:
            conn.close()


@router.post('/password-reset/request')
def password_reset_request(req: PasswordResetRequest):
    conn = get_db_connection()
    try:
        cur = conn.cursor(cursor_factory=RealDictCursor)
        cur.execute("SELECT * FROM users WHERE LOWER(email) = %s", (_normalize_email(req.email),))
        user = cur.fetchone()
        if not user:
            raise HTTPException(status_code=404, detail="อีเมลไม่ถูกต้อง")
        code = _generate_code()
        expires = datetime.now(timezone.utc) + timedelta(minutes=15)
        cur.execute(
            "INSERT INTO password_reset_codes (user_id, code, expires_at, used) VALUES (%s, %s, %s, %s)",
            (user['user_id'], code, expires, False),
        )
        conn.commit()
        send_password_reset_email(req.email, user['username'], code)
        return {"message": "รหัสยืนยันถูกส่งไปยังอีเมลแล้ว"}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        if conn:
            conn.close()


@router.post('/password-reset/verify')
def password_reset_verify(req: PasswordResetVerify):
    conn = get_db_connection()
    try:
        cur = conn.cursor(cursor_factory=RealDictCursor)
        cur.execute("SELECT * FROM users WHERE LOWER(email) = %s", (_normalize_email(req.email),))
        user = cur.fetchone()
        if not user:
            raise HTTPException(status_code=404, detail="ไม่พบผู้ใช้")
        if not user.get('birth_date'):
            raise HTTPException(status_code=400, detail="กรุณากรอกข้อมูล วันเดือนปีเกิด ในโปรไฟล์")
        if isinstance(user['birth_date'], datetime):
            user_birth = user['birth_date'].date()
        else:
            user_birth = user['birth_date']
        if user_birth != req.birth_date:
            raise HTTPException(status_code=401, detail="วันเดือนปีเกิดไม่ตรงกับบัญชี")
        cur.execute("SELECT * FROM password_reset_codes WHERE user_id = %s AND code = %s AND used = FALSE ORDER BY created_at DESC LIMIT 1", (user['user_id'], req.code))
        row = cur.fetchone()
        if not row or row['expires_at'] < datetime.now(timezone.utc):
            raise HTTPException(status_code=401, detail="รหัสไม่ถูกต้องหรือหมดอายุ")
        return {"message": "ยืนยันโค้ดสำเร็จ"}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        if conn:
            conn.close()


@router.post('/password-reset/confirm')
def password_reset_confirm(req: PasswordResetConfirm):
    conn = get_db_connection()
    try:
        cur = conn.cursor(cursor_factory=RealDictCursor)
        cur.execute("SELECT * FROM users WHERE LOWER(email) = %s", (_normalize_email(req.email),))
        user = cur.fetchone()
        if not user:
            raise HTTPException(status_code=404, detail="ไม่พบผู้ใช้")
        if not user.get('birth_date'):
            raise HTTPException(status_code=400, detail="กรุณากรอกข้อมูล วันเดือนปีเกิด ในโปรไฟล์")
        if isinstance(user['birth_date'], datetime):
            user_birth = user['birth_date'].date()
        else:
            user_birth = user['birth_date']
        if user_birth != req.birth_date:
            raise HTTPException(status_code=401, detail="วันเดือนปีเกิดไม่ตรงกับบัญชี")
        cur.execute("SELECT * FROM password_reset_codes WHERE user_id = %s AND code = %s AND used = FALSE ORDER BY created_at DESC LIMIT 1", (user['user_id'], req.code))
        row = cur.fetchone()
        if not row or row['expires_at'] < datetime.now(timezone.utc):
            raise HTTPException(status_code=401, detail="รหัสไม่ถูกต้องหรือหมดอายุ")
        new_hash = get_password_hash(req.new_password)
        cur.execute("UPDATE users SET password_hash = %s WHERE user_id = %s", (new_hash, user['user_id']))
        cur.execute("UPDATE password_reset_codes SET used = TRUE WHERE id = %s", (row['id'],))
        conn.commit()
        return {"message": "รีเซ็ตรหัสผ่านสำเร็จ"}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        if conn:
            conn.close()
