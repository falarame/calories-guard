"""
Shared pytest fixtures for backend tests.

Uses FastAPI dependency overrides to bypass real DB + Supabase Auth.
Tests focus on routing, input validation, and auth guards — not DB behavior.
"""
import os
import sys
from unittest.mock import MagicMock

import pytest

# Make sure backend/ is importable
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, ROOT)

# Set required env vars BEFORE importing app
os.environ.setdefault("DB_MODE", "local")
os.environ.setdefault("ALLOWED_ORIGINS", "*")
os.environ.setdefault("SUPABASE_JWT_SECRET", "test-secret")
os.environ.setdefault("SUPABASE_URL", "https://test.supabase.co")
os.environ.setdefault("SUPABASE_ANON_KEY", "test-key")


@pytest.fixture
def anyio_backend():
    """Run async tests on asyncio only; CI does not install trio."""
    return "asyncio"


@pytest.fixture
def mock_db(monkeypatch):
    """Replace get_db_connection with a MagicMock that returns a fake cursor."""
    mock_conn = MagicMock()
    mock_cur = MagicMock()
    mock_conn.cursor.return_value = mock_cur

    def fake_get_conn():
        return mock_conn

    # Patch at every import site
    import database
    monkeypatch.setattr(database, "get_db_connection", fake_get_conn)

    return mock_conn, mock_cur


@pytest.fixture
def app_client(mock_db):
    """
    FastAPI TestClient with mocked DB + auth.
    Auth dependencies are overridden to return a default test user.
    """
    from fastapi.testclient import TestClient

    # Stub _init_missing_tables so it doesn't try to hit a real DB on import
    import database
    _orig = database.get_db_connection
    database.get_db_connection = lambda: None

    from main import app

    database.get_db_connection = _orig

    from auth.dependencies import get_current_user, get_current_admin

    def _fake_user():
        return {"sub": "uuid-test", "email": "test@example.com", "user_id": 42, "role": "authenticated"}

    def _fake_admin():
        return {"sub": "uuid-admin", "email": "admin@example.com", "user_id": 1, "role": "admin"}

    app.dependency_overrides[get_current_user] = _fake_user
    app.dependency_overrides[get_current_admin] = _fake_admin

    yield TestClient(app)

    app.dependency_overrides.clear()


@pytest.fixture
def unauth_client():
    """TestClient with no auth overrides — for testing 401 behavior."""
    from fastapi.testclient import TestClient

    import database
    _orig = database.get_db_connection
    database.get_db_connection = lambda: None
    from main import app
    database.get_db_connection = _orig

    return TestClient(app)
