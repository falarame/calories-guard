"""
End-to-end meal flow against a real Postgres.

Covers task #8. Flow:
  1. Seed a throwaway user via live DB fixture.
  2. Override get_current_user so the FastAPI app treats that user as
     authenticated. This lets us exercise the real router + real SQL
     without faking a Supabase JWT.
  3. POST /meals/{uid} with two detail items → meal_id returned.
  4. GET /daily_summary/{uid} → totals match sum of items.
  5. GET /meals/{uid}/detail → items echo back.
  6. DELETE /meals/clear/{uid} → summary zeros out.

Skipped by default; run with `pytest -m integration`.
"""
from datetime import date

import pytest


pytestmark = pytest.mark.integration


@pytest.fixture
def client_as_user(test_user_id):
    from fastapi.testclient import TestClient
    from main import app
    from auth.dependencies import get_current_user

    def _override():
        return {
            "sub": f"uuid-{test_user_id}",
            "email": f"e2e{test_user_id}@test.local",
            "user_id": test_user_id,
            "role": "authenticated",
        }

    app.dependency_overrides[get_current_user] = _override
    try:
        yield TestClient(app), test_user_id
    finally:
        app.dependency_overrides.pop(get_current_user, None)


def test_meal_create_summary_delete_roundtrip(client_as_user, test_unit_id):
    client, uid = client_as_user
    today = date.today().isoformat()

    payload = {
        "date": today,
        "meal_type": "breakfast",
        "items": [
            {
                "food_id": None,
                "food_name": "ข้าวผัดไข่",
                "amount": 1,
                "unit_id": test_unit_id,
                "cal_per_unit": 500,
                "protein_per_unit": 15,
                "carbs_per_unit": 60,
                "fat_per_unit": 20,
            },
            {
                "food_id": None,
                "food_name": "นมสด",
                "amount": 1,
                "unit_id": test_unit_id,
                "cal_per_unit": 150,
                "protein_per_unit": 8,
                "carbs_per_unit": 12,
                "fat_per_unit": 8,
            },
        ],
    }

    # 1) create
    r = client.post(f"/meals/{uid}", json=payload)
    assert r.status_code == 200, r.text

    # 2) summary totals = 500 + 150 = 650
    r = client.get(f"/daily_summary/{uid}", params={"date_record": today})
    assert r.status_code == 200, r.text
    body = r.json()
    # total_calories_intake is recomputed by the DB trigger (see v8 migration)
    assert float(body.get("total_calories_intake") or 0) == pytest.approx(650.0)
    assert body.get("meals", {}).get("breakfast") == "ข้าวผัดไข่, นมสด"

    # 2b) posting the same meal/date replaces the meal atomically instead of
    # appending duplicate meal rows. Custom foods may have food_id=null.
    replacement_payload = {
        "date": today,
        "meal_type": "breakfast",
        "items": [
            {
                "food_id": None,
                "food_name": "โจ๊กหมู",
                "amount": 1,
                "unit_id": test_unit_id,
                "cal_per_unit": 320,
                "protein_per_unit": 18,
                "carbs_per_unit": 42,
                "fat_per_unit": 9,
            },
        ],
    }
    r = client.post(f"/meals/{uid}", json=replacement_payload)
    assert r.status_code == 200, r.text

    r = client.get(f"/daily_summary/{uid}", params={"date_record": today})
    assert r.status_code == 200, r.text
    body = r.json()
    assert float(body.get("total_calories_intake") or 0) == pytest.approx(320.0)
    assert body.get("meals", {}).get("breakfast") == "โจ๊กหมู"

    # 3) detail echoes items
    r = client.get(
        f"/meals/{uid}/detail",
        params={"date_record": today, "meal_type": "breakfast"},
    )
    assert r.status_code == 200
    names = [it["food_name"] for it in r.json().get("items", [])]
    assert names == ["โจ๊กหมู"]

    # 4) clear zeros out the summary
    r = client.delete(
        f"/meals/clear/{uid}",
        params={"date_record": today, "meal_type": "breakfast"},
    )
    assert r.status_code == 200

    r = client.get(f"/daily_summary/{uid}", params={"date_record": today})
    assert r.status_code == 200
    body = r.json()
    assert float(body.get("total_calories_intake") or 0) == pytest.approx(0.0)
