"""
Tests for the updated leaderboard system:
  GET /leaderboard/global  — XP board + tiebreaker chain
  GET /leaderboard/streak  — Streak board + tiebreaker chain
  _badge_score             — badge weighted scoring (unit test)
  _fetch_leaderboard       — sort ordering logic (unit test)

หลักการทดสอบ:
  - Tiebreaker XP:     weekly_xp → tier_level → badge_score → created_at ASC → user_id
  - Tiebreaker Streak: current_streak → total_login_days → weekly_xp → badge_score → user_id
"""
from datetime import datetime, timezone
from unittest.mock import MagicMock, patch


# ─────────────────────────────────────────────
# Unit tests: _badge_score
# ─────────────────────────────────────────────

class TestBadgeScore:
    def _score(self, badges):
        from app.routers.social import _badge_score
        return _badge_score(badges)

    def test_empty_badges_returns_zero(self):
        assert self._score([]) == 0

    def test_none_badges_returns_zero(self):
        assert self._score(None) == 0

    def test_unknown_badge_contributes_zero(self):
        assert self._score(["mystery_badge"]) == 0

    def test_streak_7_badge_weight(self):
        assert self._score(["streak_7"]) == 3

    def test_streak_365_badge_weight(self):
        assert self._score(["streak_365"]) == 100

    def test_multiple_badges_sum_correctly(self):
        # streak_7(3) + streak_30(10) + first_tier_2(5) = 18
        assert self._score(["streak_7", "streak_30", "first_tier_2"]) == 18

    def test_duplicate_badges_counted_twice(self):
        # streak_7 = 3 each
        assert self._score(["streak_7", "streak_7"]) == 6


# ─────────────────────────────────────────────
# Unit tests: _fetch_leaderboard sort order
# ─────────────────────────────────────────────

_EARLY = datetime(2023, 1, 1, tzinfo=timezone.utc)
_LATE  = datetime(2025, 6, 1, tzinfo=timezone.utc)


def _make_row(**kw):
    defaults = dict(
        user_id=1, username="user1", avatar_url=None,
        tama_points=0, weekly_xp=0, tier_level=0,
        claimed_badges=[], current_streak=0,
        total_login_days=0, created_at=_EARLY,
    )
    defaults.update(kw)
    return defaults


class TestFetchLeaderboardXP:
    def _run(self, rows):
        from app.routers.social import _fetch_leaderboard
        cur = MagicMock()
        cur.fetchall.return_value = rows
        return _fetch_leaderboard(cur, limit=50, sort_by="xp")

    def test_higher_weekly_xp_ranks_first(self):
        rows = [
            _make_row(user_id=1, weekly_xp=100),
            _make_row(user_id=2, weekly_xp=500),
        ]
        result = self._run(rows)
        assert result[0]["user_id"] == 2
        assert result[1]["user_id"] == 1

    def test_tiebreak_by_tier_level(self):
        rows = [
            _make_row(user_id=1, tama_points=200, tier_level=1),
            _make_row(user_id=2, tama_points=200, tier_level=3),
        ]
        result = self._run(rows)
        assert result[0]["user_id"] == 2  # higher tier wins

    def test_tiebreak_by_badge_score(self):
        rows = [
            _make_row(user_id=1, tama_points=200, tier_level=2, claimed_badges=["streak_7"]),   # badge=3
            _make_row(user_id=2, tama_points=200, tier_level=2, claimed_badges=["streak_365"]), # badge=100
        ]
        result = self._run(rows)
        assert result[0]["user_id"] == 2

    def test_tiebreak_by_created_at_older_wins(self):
        rows = [
            _make_row(user_id=1, tama_points=200, tier_level=1, claimed_badges=[], created_at=_LATE),
            _make_row(user_id=2, tama_points=200, tier_level=1, claimed_badges=[], created_at=_EARLY),
        ]
        result = self._run(rows)
        assert result[0]["user_id"] == 2  # older account ranks higher

    def test_tiebreak_final_by_user_id(self):
        rows = [
            _make_row(user_id=5, tama_points=100, tier_level=0, claimed_badges=[], created_at=_EARLY),
            _make_row(user_id=3, tama_points=100, tier_level=0, claimed_badges=[], created_at=_EARLY),
        ]
        result = self._run(rows)
        assert result[0]["user_id"] == 3  # lower user_id first

    def test_rank_field_assigned_correctly(self):
        rows = [
            _make_row(user_id=1, weekly_xp=300),
            _make_row(user_id=2, weekly_xp=200),
            _make_row(user_id=3, weekly_xp=100),
        ]
        result = self._run(rows)
        assert result[0]["rank"] == 1
        assert result[1]["rank"] == 2
        assert result[2]["rank"] == 3

    def test_limit_respected(self):
        rows = [_make_row(user_id=i, tama_points=i) for i in range(20)]
        from app.routers.social import _fetch_leaderboard
        cur = MagicMock()
        cur.fetchall.return_value = rows
        result = _fetch_leaderboard(cur, limit=5, sort_by="xp")
        assert len(result) == 5


class TestFetchLeaderboardStreak:
    def _run(self, rows):
        from app.routers.social import _fetch_leaderboard
        cur = MagicMock()
        cur.fetchall.return_value = rows
        return _fetch_leaderboard(cur, limit=50, sort_by="streak")

    def test_higher_streak_ranks_first(self):
        rows = [
            _make_row(user_id=1, current_streak=5),
            _make_row(user_id=2, current_streak=30),
        ]
        result = self._run(rows)
        assert result[0]["user_id"] == 2

    def test_tiebreak_by_total_login_days(self):
        rows = [
            _make_row(user_id=1, current_streak=10, total_login_days=50),
            _make_row(user_id=2, current_streak=10, total_login_days=100),
        ]
        result = self._run(rows)
        assert result[0]["user_id"] == 2

    def test_tiebreak_by_weekly_xp(self):
        rows = [
            _make_row(user_id=1, current_streak=10, total_login_days=50, weekly_xp=100),
            _make_row(user_id=2, current_streak=10, total_login_days=50, weekly_xp=500),
        ]
        result = self._run(rows)
        assert result[0]["user_id"] == 2

    def test_tiebreak_by_badge_score(self):
        rows = [
            _make_row(user_id=1, current_streak=10, total_login_days=50,
                      tama_points=100, claimed_badges=[]),
            _make_row(user_id=2, current_streak=10, total_login_days=50,
                      tama_points=100, claimed_badges=["streak_365"]),
        ]
        result = self._run(rows)
        assert result[0]["user_id"] == 2

    def test_tiebreak_final_by_user_id(self):
        rows = [
            _make_row(user_id=9, current_streak=5, total_login_days=10, tama_points=50, claimed_badges=[]),
            _make_row(user_id=2, current_streak=5, total_login_days=10, tama_points=50, claimed_badges=[]),
        ]
        result = self._run(rows)
        assert result[0]["user_id"] == 2


# ─────────────────────────────────────────────
# Integration tests: HTTP endpoints
# ─────────────────────────────────────────────

def _mock_conn_with_rows(rows):
    conn = MagicMock()
    cur = MagicMock()
    cur.fetchall.return_value = rows
    conn.cursor.return_value = cur
    return conn


class TestLeaderboardEndpoints:
    def test_global_returns_200(self, app_client):
        conn = _mock_conn_with_rows([])
        with patch("app.routers.social.get_db_connection", return_value=conn):
            res = app_client.get("/leaderboard/global")
        assert res.status_code == 200
        assert isinstance(res.json(), list)

    def test_streak_returns_200(self, app_client):
        conn = _mock_conn_with_rows([])
        with patch("app.routers.social.get_db_connection", return_value=conn):
            res = app_client.get("/leaderboard/streak")
        assert res.status_code == 200
        assert isinstance(res.json(), list)

    def test_global_returns_ranked_users(self, app_client):
        rows = [
            _make_row(user_id=1, username="alice", weekly_xp=500),
            _make_row(user_id=2, username="bob", weekly_xp=100),
        ]
        conn = _mock_conn_with_rows(rows)
        with patch("app.routers.social.get_db_connection", return_value=conn):
            res = app_client.get("/leaderboard/global")

        body = res.json()
        assert body[0]["username"] == "alice"
        assert body[0]["rank"] == 1
        assert body[1]["username"] == "bob"
        assert body[1]["rank"] == 2

    def test_streak_sorted_by_current_streak(self, app_client):
        rows = [
            _make_row(user_id=1, username="alice", current_streak=5),
            _make_row(user_id=2, username="bob",   current_streak=30),
        ]
        conn = _mock_conn_with_rows(rows)
        with patch("app.routers.social.get_db_connection", return_value=conn):
            res = app_client.get("/leaderboard/streak")

        body = res.json()
        assert body[0]["username"] == "bob"

    def test_friends_endpoint_no_longer_exists(self, app_client):
        """Friends leaderboard ถูกลบออกแล้ว → 404 หรือ 405"""
        res = app_client.get("/leaderboard/friends/42")
        assert res.status_code in (404, 405, 422)
