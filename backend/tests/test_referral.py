"""
Tests for the referral system endpoints:
  POST /referral/generate   — สร้าง/คืน referral code
  POST /referral/redeem     — กรอกโค้ด รับ buff + gems
  GET  /referral/invitees   — ดูรายชื่อคนที่ใช้โค้ดเรา
  GET  /referral/status     — ดู code + สถานะ buff

ทดสอบผ่าน FastAPI TestClient + mock DB (ไม่ต่อ DB จริง)
"""
from datetime import datetime, timezone, timedelta
from unittest.mock import MagicMock, patch


# ─────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────

def _mock_conn():
    conn = MagicMock()
    cur = MagicMock()
    conn.cursor.return_value.__enter__.return_value = cur
    conn.cursor.return_value.__exit__.return_value = False
    return conn, cur


# ─────────────────────────────────────────────
# POST /referral/generate
# ─────────────────────────────────────────────

class TestGenerateReferralCode:
    def test_returns_existing_code_if_already_generated(self, app_client):
        """ถ้า user มี code อยู่แล้วต้องคืน code เดิม ไม่สร้างใหม่"""
        conn, cur = _mock_conn()
        cur.fetchone.return_value = {"code": "RICE-1234"}

        with patch("app.routers.referral.get_db_connection", return_value=conn):
            res = app_client.post("/referral/generate")

        assert res.status_code == 200
        assert res.json()["code"] == "RICE-1234"

    def test_creates_new_code_when_none_exists(self, app_client):
        """user ไม่มี code → สร้างใหม่ แล้ว INSERT"""
        conn, cur = _mock_conn()
        cur.fetchone.side_effect = [None, None]  # no existing code, unique check pass

        with patch("app.routers.referral.get_db_connection", return_value=conn):
            res = app_client.post("/referral/generate")

        assert res.status_code == 200
        code = res.json()["code"]
        assert isinstance(code, str)
        assert len(code) > 0
        # ต้องมีการ INSERT
        insert_calls = [c for c in cur.execute.call_args_list
                        if "INSERT INTO cleangoal.referral_codes" in str(c)]
        assert len(insert_calls) == 1

    def test_code_format_contains_prefix_and_digits(self, app_client):
        """format ของโค้ดต้องเป็น PREFIX-DDDD"""
        conn, cur = _mock_conn()
        cur.fetchone.side_effect = [None, None]

        with patch("app.routers.referral.get_db_connection", return_value=conn):
            res = app_client.post("/referral/generate")

        code = res.json()["code"]
        parts = code.split("-")
        assert len(parts) == 2, f"unexpected format: {code}"
        assert parts[1].isdigit() and len(parts[1]) == 4


# ─────────────────────────────────────────────
# POST /referral/redeem
# ─────────────────────────────────────────────

class TestRedeemReferralCode:
    def _base_user_row(self, days_old=0):
        created = datetime.now(timezone.utc) - timedelta(days=days_old)
        return {"created_at": created}

    def test_happy_path_awards_gems_and_buff(self, app_client):
        """user ใหม่ (0 วัน) กรอกโค้ดถูก → ได้ gems + buff"""
        conn, cur = _mock_conn()
        cur.fetchone.side_effect = [
            self._base_user_row(days_old=0),    # users.created_at
            {"user_id": 99},                    # referral_codes
            None,                               # no existing redemption
        ]

        with patch("app.routers.referral.get_db_connection", return_value=conn):
            res = app_client.post("/referral/redeem", json={"code": "RICE-0001"})

        assert res.status_code == 200
        body = res.json()
        assert body["ok"] is True
        assert body["buff_days"] == 7
        assert body["invitee_gems"] > 0
        assert body["inviter_gems_awarded"] > 0
        conn.commit.assert_called_once()

    def test_account_too_old_returns_403(self, app_client):
        """บัญชีอายุ > 7 วัน ต้องได้ 403"""
        conn, cur = _mock_conn()
        cur.fetchone.side_effect = [self._base_user_row(days_old=10)]

        with patch("app.routers.referral.get_db_connection", return_value=conn):
            res = app_client.post("/referral/redeem", json={"code": "RICE-0001"})

        assert res.status_code == 403
        assert "7" in res.json()["detail"]

    def test_invalid_code_returns_404(self, app_client):
        """โค้ดไม่มีในระบบ → 404"""
        conn, cur = _mock_conn()
        cur.fetchone.side_effect = [
            self._base_user_row(days_old=1),  # user ok
            None,                             # code not found
        ]

        with patch("app.routers.referral.get_db_connection", return_value=conn):
            res = app_client.post("/referral/redeem", json={"code": "FAKE-9999"})

        assert res.status_code == 404

    def test_self_redeem_returns_400(self, app_client):
        """user ID 42 พยายาม redeem โค้ดของตัวเอง (user_id=42) → 400"""
        conn, cur = _mock_conn()
        cur.fetchone.side_effect = [
            self._base_user_row(days_old=1),
            {"user_id": 42},   # same as test user (user_id=42 in conftest)
        ]

        with patch("app.routers.referral.get_db_connection", return_value=conn):
            res = app_client.post("/referral/redeem", json={"code": "RICE-0042"})

        assert res.status_code == 400
        assert "own" in res.json()["detail"].lower()

    def test_duplicate_redeem_returns_409(self, app_client):
        """user เคย redeem แล้ว → 409"""
        conn, cur = _mock_conn()
        cur.fetchone.side_effect = [
            self._base_user_row(days_old=1),
            {"user_id": 99},
            {"redemption_id": 5},  # already redeemed
        ]

        with patch("app.routers.referral.get_db_connection", return_value=conn):
            res = app_client.post("/referral/redeem", json={"code": "RICE-0001"})

        assert res.status_code == 409

    def test_missing_code_field_returns_400(self, app_client):
        """ไม่ส่ง code → 400"""
        conn, cur = _mock_conn()
        with patch("app.routers.referral.get_db_connection", return_value=conn):
            res = app_client.post("/referral/redeem", json={})

        assert res.status_code == 400

    def test_rollback_on_db_error(self, app_client):
        """ถ้า DB ล้ม ต้อง rollback"""
        conn, cur = _mock_conn()
        cur.fetchone.side_effect = Exception("DB down")

        with patch("app.routers.referral.get_db_connection", return_value=conn):
            res = app_client.post("/referral/redeem", json={"code": "RICE-0001"})

        assert res.status_code == 500
        conn.rollback.assert_called_once()


# ─────────────────────────────────────────────
# GET /referral/invitees
# ─────────────────────────────────────────────

class TestGetReferralInvitees:
    def test_returns_list_of_redeemers(self, app_client):
        """คืน list ของคนที่ใช้โค้ด"""
        conn, cur = _mock_conn()
        cur.fetchall.return_value = [
            {"user_id": 10, "redeemed_at": "2026-05-01T10:00:00+00:00"},
            {"user_id": 20, "redeemed_at": "2026-05-02T10:00:00+00:00"},
        ]

        with patch("app.routers.referral.get_db_connection", return_value=conn):
            res = app_client.get("/referral/invitees")

        assert res.status_code == 200
        body = res.json()
        assert len(body) == 2
        assert body[0]["user_id"] == 10

    def test_returns_empty_list_if_no_invitees(self, app_client):
        """ยังไม่มีใช้โค้ด → คืน []"""
        conn, cur = _mock_conn()
        cur.fetchall.return_value = []

        with patch("app.routers.referral.get_db_connection", return_value=conn):
            res = app_client.get("/referral/invitees")

        assert res.status_code == 200
        assert res.json() == []


# ─────────────────────────────────────────────
# GET /referral/status
# ─────────────────────────────────────────────

class TestGetReferralStatus:
    def test_returns_code_and_active_buff(self, app_client):
        """คืน code + buff active"""
        conn, cur = _mock_conn()
        future_exp = datetime.now(timezone.utc) + timedelta(days=5)
        cur.fetchone.side_effect = [
            {"code": "MEAL-5678"},
            {"gem_buff_multiplier": 2, "gem_buff_expires_at": future_exp},
        ]

        with patch("app.routers.referral.get_db_connection", return_value=conn):
            res = app_client.get("/referral/status")

        assert res.status_code == 200
        body = res.json()
        assert body["code"] == "MEAL-5678"
        assert body["buff_active"] is True
        assert body["gem_buff_multiplier"] == 2

    def test_buff_inactive_when_expired(self, app_client):
        """buff หมดอายุแล้ว → buff_active = False"""
        conn, cur = _mock_conn()
        past_exp = datetime.now(timezone.utc) - timedelta(days=1)
        cur.fetchone.side_effect = [
            {"code": "MEAL-5678"},
            {"gem_buff_multiplier": 2, "gem_buff_expires_at": past_exp},
        ]

        with patch("app.routers.referral.get_db_connection", return_value=conn):
            res = app_client.get("/referral/status")

        assert res.status_code == 200
        assert res.json()["buff_active"] is False

    def test_no_code_yet_returns_null(self, app_client):
        """ยังไม่เคย generate → code = null"""
        conn, cur = _mock_conn()
        cur.fetchone.side_effect = [None, None]

        with patch("app.routers.referral.get_db_connection", return_value=conn):
            res = app_client.get("/referral/status")

        assert res.status_code == 200
        assert res.json()["code"] is None

    def test_requires_auth(self, unauth_client):
        """ไม่มี token → 401"""
        res = unauth_client.get("/referral/status")
        assert res.status_code == 401
