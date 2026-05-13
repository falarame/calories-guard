"""
Integration-test fixtures.

These tests talk to a real Postgres (local docker-compose or a throwaway
Supabase branch). They are skipped unless you run:

    pytest -m integration

Environment knobs:
    INTEGRATION_DB_URL — postgres connection string (required)
        e.g. postgresql://postgres:postgres@localhost:5433/cleangoal_test
    Falls back to the usual DB_HOST/DB_NAME/... vars the app already uses
    if INTEGRATION_DB_URL is unset — which means `DB_MODE=local` + a
    running local Postgres Just Works.

Each test gets a *transaction-per-test* so nothing leaks between runs.
If setup can't reach a DB, the whole file is skipped (not failed), so
CI jobs without a DB service still go green on unit-only runs.
"""
from __future__ import annotations

import uuid
import pytest


def _can_connect() -> bool:
    try:
        from database import get_db_connection
        conn = get_db_connection()
        if conn is None:
            return False
        conn.close()
        return True
    except Exception:
        return False


# Skip the entire integration suite if no DB is reachable.
pytestmark = pytest.mark.skipif(
    not _can_connect(),
    reason="No Postgres reachable; set DB_HOST/DB_NAME/... or run docker-compose up db",
)


@pytest.fixture
def live_db():
    """Yield a real connection. Rolled back at teardown for isolation."""
    from database import get_db_connection
    conn = get_db_connection()
    if conn is None:
        pytest.skip("DB connection unavailable mid-test")
    try:
        conn.autocommit = False
        yield conn
    finally:
        try:
            conn.rollback()
        finally:
            conn.close()


@pytest.fixture
def test_user_id(live_db):
    """Insert a throwaway user visible to app connections, then clean it up."""
    username = f"e2e_{uuid.uuid4().hex[:8]}"
    email = f"{username}@test.local"
    cur = live_db.cursor()
    cur.execute(
        """
        INSERT INTO users (username, email, password_hash, role_id, gender,
                           birth_date, height_cm, current_weight_kg,
                           activity_level, goal_type, target_calories)
        VALUES (%s, %s, 'x', 2, 'male', DATE '1990-01-01', 170, 65,
                'moderately_active', 'maintain_weight', 2000)
        RETURNING user_id
        """,
        (username, email),
    )
    uid = cur.fetchone()[0]
    live_db.commit()
    try:
        yield uid
    finally:
        cur.execute("DELETE FROM users WHERE user_id = %s", (uid,))
        live_db.commit()


@pytest.fixture
def test_unit_id(live_db):
    """Return an existing unit_id that satisfies detail_items.unit_id FK."""
    cur = live_db.cursor()
    cur.execute("SELECT unit_id FROM units ORDER BY unit_id LIMIT 1")
    row = cur.fetchone()
    if not row:
        pytest.skip("No units available for integration meal item test")
    return row[0]
