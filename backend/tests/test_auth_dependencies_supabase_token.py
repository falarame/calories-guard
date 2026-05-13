import pytest
from fastapi.security import HTTPAuthorizationCredentials
from jose import JWTError


class _Cursor:
    def execute(self, *_args, **_kwargs):
        return None

    def fetchone(self):
        return {"user_id": 103, "role_id": 1}


class _Connection:
    def cursor(self, **_kwargs):
        return _Cursor()

    def close(self):
        return None


def test_decode_token_falls_back_to_supabase_auth_api(monkeypatch):
    from auth import dependencies

    monkeypatch.setattr(dependencies, "_SUPABASE_URL", "https://test.supabase.co")
    monkeypatch.setattr(dependencies, "_SUPABASE_ANON_KEY", "anon-test-key")
    monkeypatch.setattr(
        dependencies.jwt,
        "decode",
        lambda *_args, **_kwargs: (_ for _ in ()).throw(JWTError("ES256")),
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

    monkeypatch.setattr(
        dependencies.requests, "get", lambda *_args, **_kwargs: _Response()
    )

    payload = dependencies._decode_token("supabase-es256-token")

    assert payload["sub"] == "supabase-uuid"
    assert payload["email"] == "user@example.com"


@pytest.mark.anyio
async def test_current_admin_maps_supabase_email_to_db_role(monkeypatch):
    from auth import dependencies

    monkeypatch.setattr(
        dependencies,
        "_decode_token",
        lambda _token: {
            "sub": "supabase-uuid",
            "email": "admin@example.com",
            "role": "authenticated",
            "app_metadata": {},
            "user_metadata": {},
        },
    )
    monkeypatch.setattr(dependencies, "get_db_connection", lambda: _Connection())

    user = await dependencies.get_current_admin(
        HTTPAuthorizationCredentials(scheme="Bearer", credentials="token")
    )

    assert user["user_id"] == 103
    assert user["role_id"] == 1
