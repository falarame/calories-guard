"""
Supabase Auth dependencies for FastAPI.

Provides:
  - get_current_user: verify Supabase JWT → return user dict with user_id, email, role_id
  - get_current_admin: same but requires role_id == 1
"""

import os
from typing import Optional

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from jose import jwt, JWTError
from dotenv import load_dotenv
import requests

from database import get_db_connection

# โหลด env
load_dotenv(dotenv_path=os.path.join(os.path.dirname(__file__), '..', '..', '.env'))
load_dotenv(dotenv_path=os.path.join(os.path.dirname(__file__), '..', '.env'))

_JWT_SECRET = os.getenv("SUPABASE_JWT_SECRET", "")
_SUPABASE_URL = os.getenv("SUPABASE_URL") or os.getenv("SUPABASE_PROJECT_URL", "")
_SUPABASE_ANON_KEY = os.getenv("SUPABASE_ANON_KEY", "")
_JWT_ALGO = "HS256"

_bearer_scheme = HTTPBearer(auto_error=False)


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


def _decode_token(token: str) -> dict:
    """Verify backend-issued JWT or a Supabase access token."""
    try:
        payload = jwt.decode(
            token,
            _JWT_SECRET,
            algorithms=[_JWT_ALGO],
            options={"verify_aud": False},
        )
        return payload
    except JWTError as e:
        payload = _fetch_supabase_user_payload(token)
        if payload:
            return payload
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token",
            headers={"WWW-Authenticate": "Bearer"},
        )


def _get_user_id_from_payload(payload: dict) -> Optional[int]:
    """
    Map Supabase auth user (UUID in 'sub') to our DB user_id.
    Supabase JWT contains 'sub' (UUID) and optionally 'email'.
    We store the mapping in app_metadata or look up by email.

    For now: check if 'user_id' is in app_metadata, otherwise
    the endpoint must resolve it from the email.
    """
    # Try app_metadata.user_id first (set during registration)
    app_meta = payload.get("app_metadata", {})
    if "user_id" in app_meta:
        return int(app_meta["user_id"])

    # Try user_metadata.user_id
    user_meta = payload.get("user_metadata", {})
    if "user_id" in user_meta:
        return int(user_meta["user_id"])

    return None


def _lookup_user_by_email(email: str | None) -> dict | None:
    if not email:
        return None
    conn = get_db_connection()
    if not conn:
        return None
    try:
        cur = conn.cursor()
        cur.execute(
            "SELECT user_id, role_id FROM users WHERE LOWER(email) = LOWER(%s) LIMIT 1",
            (email,),
        )
        row = cur.fetchone()
        if not row:
            return None
        return {"user_id": int(row[0]), "role_id": int(row[1] or 2)}
    finally:
        conn.close()


async def get_current_user(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(_bearer_scheme),
) -> dict:
    """
    FastAPI dependency: verify Bearer token → return user info dict.

    Returns:
        {
            "sub": "uuid-...",           # Supabase auth UUID
            "email": "user@example.com",
            "user_id": 123,              # Our DB user_id (if available in metadata)
            "role": "authenticated",
        }

    Raises 401 if no token or invalid token.
    """
    if credentials is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authentication required",
            headers={"WWW-Authenticate": "Bearer"},
        )

    payload = _decode_token(credentials.credentials)

    user_id = _get_user_id_from_payload(payload)
    role_id = (payload.get("app_metadata") or {}).get("role_id")
    if user_id is None or role_id is None:
        db_user = _lookup_user_by_email(payload.get("email"))
        if db_user:
            user_id = user_id or db_user["user_id"]
            role_id = role_id or db_user["role_id"]

    return {
        "sub": payload.get("sub"),
        "email": payload.get("email"),
        "user_id": user_id,
        "role_id": role_id,
        "role": payload.get("role", "authenticated"),
    }


async def get_current_admin(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(_bearer_scheme),
) -> dict:
    """
    FastAPI dependency: require admin role (role_id == 1).

    Verifies the JWT and checks app_metadata.role_id == 1.
    Raises 401 if no/invalid token, 403 if not an admin.
    """
    if credentials is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authentication required",
            headers={"WWW-Authenticate": "Bearer"},
        )

    payload = _decode_token(credentials.credentials)
    app_meta = payload.get("app_metadata") or {}
    role_id = app_meta.get("role_id")
    user_id = _get_user_id_from_payload(payload)
    if role_id is None or user_id is None:
        db_user = _lookup_user_by_email(payload.get("email"))
        if db_user:
            role_id = role_id or db_user["role_id"]
            user_id = user_id or db_user["user_id"]
    if role_id != 1:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Admin privileges required",
        )

    return {
        "sub": payload.get("sub"),
        "email": payload.get("email"),
        "user_id": user_id,
        "role_id": role_id,
    }


def get_optional_user(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(_bearer_scheme),
) -> Optional[dict]:
    """
    FastAPI dependency: optionally extract user from token.
    Returns None if no token provided (for public endpoints).
    Raises 401 only if token IS provided but invalid.
    """
    if credentials is None:
        return None

    payload = _decode_token(credentials.credentials)
    user_id = _get_user_id_from_payload(payload)
    role_id = (payload.get("app_metadata") or {}).get("role_id")
    if user_id is None or role_id is None:
        db_user = _lookup_user_by_email(payload.get("email"))
        if db_user:
            user_id = user_id or db_user["user_id"]
            role_id = role_id or db_user["role_id"]

    return {
        "sub": payload.get("sub"),
        "email": payload.get("email"),
        "user_id": user_id,
        "role_id": role_id,
        "role": payload.get("role", "authenticated"),
    }
