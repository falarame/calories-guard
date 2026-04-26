from types import SimpleNamespace

import pytest
from fastapi import HTTPException
from jose import jwt
from starlette.requests import Request


def _request_with_bearer(token: str) -> Request:
    return Request(
        {
            "type": "http",
            "method": "POST",
            "path": "/login",
            "headers": [(b"authorization", f"Bearer {token}".encode())],
        }
    )


class _Cursor:
    def __init__(self, row):
        self.row = row

    def execute(self, *_args, **_kwargs):
        return None

    def fetchone(self):
        return self.row


class _Connection:
    def __init__(self, row):
        self.row = row
        self.committed = False
        self.closed = False

    def cursor(self, *_args, **_kwargs):
        return _Cursor(self.row)

    def commit(self):
        self.committed = True

    def close(self):
        self.closed = True


def _user_row():
    return {
        "user_id": 42,
        "email": "user@example.com",
        "username": "Test User",
        "role_id": 2,
        "password_hash": "legacy-not-a-passlib-hash",
        "is_email_verified": True,
        "last_login_date": None,
        "total_login_days": 0,
        "current_streak": 0,
    }


def test_login_accepts_verified_supabase_token_with_legacy_password_hash(monkeypatch):
    from app.routers import auth

    conn = _Connection(_user_row())
    monkeypatch.setattr(auth, "get_db_connection", lambda: conn)

    token = jwt.encode(
        {"email": "user@example.com", "role": "authenticated", "aud": "authenticated"},
        "test-secret",
        algorithm="HS256",
    )

    result = auth._login_impl(
        SimpleNamespace(email="user@example.com", password="correct-in-supabase"),
        _request_with_bearer(token),
    )

    assert result["user_id"] == 42
    assert result["email"] == "user@example.com"
    assert result["access_token"]
    assert conn.committed is True


def test_login_falls_back_to_supabase_auth_user_endpoint(monkeypatch):
    from app.routers import auth

    conn = _Connection(_user_row())
    monkeypatch.setattr(auth, "get_db_connection", lambda: conn)
    monkeypatch.setattr(auth, "_SUPABASE_URL", "https://test.supabase.co")
    monkeypatch.setattr(auth, "_SUPABASE_ANON_KEY", "anon-test-key")
    monkeypatch.setattr(
        auth.jwt,
        "decode",
        lambda *_args, **_kwargs: (_ for _ in ()).throw(Exception("bad secret")),
    )

    class _Response:
        status_code = 200

        @staticmethod
        def json():
            return {
                "id": "supabase-uuid",
                "email": "user@example.com",
                "app_metadata": {},
                "user_metadata": {},
            }

    monkeypatch.setattr(auth.requests, "get", lambda *_args, **_kwargs: _Response())

    result = auth._login_impl(
        SimpleNamespace(email="user@example.com", password="correct-in-supabase"),
        _request_with_bearer("token-from-browser"),
    )

    assert result["user_id"] == 42
    assert result["email"] == "user@example.com"
    assert conn.committed is True


def test_login_without_token_rejects_legacy_password_hash_without_500(monkeypatch):
    from app.routers import auth

    monkeypatch.setattr(auth, "get_db_connection", lambda: _Connection(_user_row()))

    with pytest.raises(HTTPException) as exc:
        auth._login_impl(SimpleNamespace(email="user@example.com", password="wrong"))

    assert exc.value.status_code == 401
