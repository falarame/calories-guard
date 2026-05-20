"""
Community / chat / referral routes — auth + ownership + idempotency tests.

Focus matches the rest of the suite: routing, input validation, auth guard.
DB state is mocked through the shared `mock_db` / `app_client` fixtures.

These tests don't exercise Supabase Realtime or the Postgres triggers — those
are validated by the migration SQL itself when run against a Supabase branch.
"""
import pytest
from unittest.mock import MagicMock


@pytest.fixture
def community_db(monkeypatch):
    """Patch get_db_connection at the community router's import site so handlers
    receive a mock connection. The shared `mock_db` fixture patches the
    `database` module, but routers do `from database import get_db_connection`
    which binds a separate name at import time — that's the reference handlers
    actually call."""
    mock_conn = MagicMock()
    mock_cur = MagicMock()
    mock_conn.cursor.return_value = mock_cur

    from app.routers import community as community_module
    monkeypatch.setattr(community_module, "get_db_connection", lambda: mock_conn)
    return mock_conn, mock_cur


# ──────────────────────────────────────────────────────────────────────────
# Schema validation — referral_code passes through UserRegister
# ──────────────────────────────────────────────────────────────────────────

def test_user_register_accepts_referral_code():
    from app.models.schemas import UserRegister

    body = UserRegister(
        email="newuser@example.com",
        password="Whatever1!",
        username="newuser",
        referral_code="CG7Q4MX2",
    )
    assert body.referral_code == "CG7Q4MX2"


def test_user_register_referral_code_optional():
    from app.models.schemas import UserRegister

    body = UserRegister(email="x@y.com", password="Whatever1!", username="x")
    assert body.referral_code is None


# ──────────────────────────────────────────────────────────────────────────
# Referral preview endpoint is public (no auth required)
# ──────────────────────────────────────────────────────────────────────────

def test_referral_preview_rejects_short_value(unauth_client):
    r = unauth_client.get("/referral/preview/abc")
    assert r.status_code == 400


def test_referral_preview_not_found_returns_404(app_client, community_db):
    _, cur = community_db
    # token lookup → None, code lookup → None
    cur.fetchone.side_effect = [None, None]
    r = app_client.get("/referral/preview/DOESNOTEXIST")
    assert r.status_code == 404


# ──────────────────────────────────────────────────────────────────────────
# /referral/me requires auth
# ──────────────────────────────────────────────────────────────────────────

def test_referral_me_requires_auth(unauth_client):
    r = unauth_client.get("/referral/me")
    assert r.status_code in (401, 403)


def test_referral_me_returns_summary(app_client, community_db):
    _, cur = community_db
    # Sequence: SELECT code (existing) → counts → counts → counts → totals
    cur.fetchone.side_effect = [
        {"code": "ABCD1234"},      # existing code
        {"n": 0},                  # total_invites
        {"n": 0},                  # accepted
        {"n": 0},                  # rewarded
        {"gems": 0, "xp": 0},      # totals
    ]
    r = app_client.get("/referral/me")
    assert r.status_code == 200
    body = r.json()
    assert body["code"] == "ABCD1234"
    assert body["share_url"].endswith("/invite/ABCD1234")
    assert body["deep_link"] == "com.caloriesguard.app://invite/ABCD1234"
    assert body["total_invites"] == 0


# ──────────────────────────────────────────────────────────────────────────
# Friendship: self-friend rejected, valid path
# ──────────────────────────────────────────────────────────────────────────

def test_friend_request_self_rejected(app_client):
    # fake_user.user_id == 42 (per conftest)
    r = app_client.post("/friends/request", json={"user_id": 42})
    assert r.status_code == 400


def test_friend_request_unknown_user_404(app_client, community_db):
    _, cur = community_db
    cur.fetchone.return_value = None
    r = app_client.post("/friends/request", json={"user_id": 999})
    assert r.status_code == 404


# ──────────────────────────────────────────────────────────────────────────
# Conversations: self-DM rejected
# ──────────────────────────────────────────────────────────────────────────

def test_dm_with_self_rejected(app_client):
    r = app_client.post("/conversations/dm", json={"user_id": 42})
    assert r.status_code == 400


def test_create_group_requires_min_members(app_client):
    # member_user_ids = [] → empty after dedupe with self
    r = app_client.post("/conversations/group", json={"name": "ทีมสุขภาพ", "member_user_ids": []})
    assert r.status_code == 422  # Pydantic min_length=1


# ──────────────────────────────────────────────────────────────────────────
# Messages: non-member receives 403 from list endpoint
# ──────────────────────────────────────────────────────────────────────────

def test_list_messages_non_member_403(app_client, community_db):
    _, cur = community_db
    cur.fetchone.return_value = None  # _assert_member returns None → 403
    r = app_client.get("/conversations/123/messages")
    assert r.status_code == 403


def test_send_message_empty_body_400(app_client):
    # Without auth-membership check we still reject empty body upstream
    r = app_client.post(
        "/conversations/123/messages",
        json={"kind": "text"},
    )
    assert r.status_code == 400


# ──────────────────────────────────────────────────────────────────────────
# Presence
# ──────────────────────────────────────────────────────────────────────────

def test_presence_heartbeat_writes(app_client, community_db):
    _, cur = community_db
    cur.fetchone.return_value = None
    r = app_client.post("/presence/heartbeat", json={"status": "online"})
    assert r.status_code == 200
    assert r.json()["status"] == "online"


def test_presence_query_rejects_too_many_users(app_client):
    ids = ",".join(str(i) for i in range(250))
    r = app_client.get(f"/presence?user_ids={ids}")
    assert r.status_code == 400


# ──────────────────────────────────────────────────────────────────────────
# Referral reward grant — idempotency / no-op cases
# ──────────────────────────────────────────────────────────────────────────

def test_grant_returns_none_when_no_pending_code(monkeypatch):
    """Direct unit test of the service; no FastAPI involved."""
    from app.services import referral_service

    fake_cur = MagicMock()
    fake_cur.fetchone.return_value = {"pending_referral_code": None}
    fake_conn = MagicMock()
    fake_conn.cursor.return_value = fake_cur

    result = referral_service.grant_referral_rewards_for_user(fake_conn, 42)
    assert result is None


def test_grant_clears_invalid_code(monkeypatch):
    from app.services import referral_service

    fake_cur = MagicMock()
    # First: pending_referral_code = 'BADCODE'
    # Then: token lookup → None
    # Then: code lookup → None
    fake_cur.fetchone.side_effect = [
        {"pending_referral_code": "BADCODE"},
        None,                                # token not found
        None,                                # code not found
    ]
    fake_conn = MagicMock()
    fake_conn.cursor.return_value = fake_cur

    result = referral_service.grant_referral_rewards_for_user(fake_conn, 42)
    assert result is None
    # Must clear the bad pending code to avoid infinite retries
    clear_calls = [c for c in fake_cur.execute.call_args_list
                   if "pending_referral_code = NULL" in (c.args[0] if c.args else "")]
    assert len(clear_calls) == 1
