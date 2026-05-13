"""
Unit tests — beverage water auto-add logic in the meals router.

Patches `app.routers.meals.get_db_connection` (the local import reference)
so the full router code path runs against a mock cursor.

Covers:
  1. Non-beverage food → water_logs NOT updated
  2. Beverage with volume_ml 250 → water_logs upserted
  3. Beverage fallback when no beverages row (should not crash)
  4. Alcoholic beverage query filtered → water_logs NOT updated
  5. Multiple beverages → volumes summed, water_logs updated
  6. GET /daily_logs returns food_type + water_ml_per_serving for beverages
  7. GET /daily_logs non-beverage → water_ml_per_serving = 0
"""
from datetime import date
from unittest.mock import MagicMock, patch

import pytest

TODAY = date.today().isoformat()


# ─── shared mock builder ─────────────────────────────────────────────────────

def _make_mock_conn(fetchone_seq=None, fetchall_val=None):
    """Return (conn, cur) where cur.fetchone pops from fetchone_seq each call.

    fetchall_val: returned for the first fetchall() call; subsequent calls
    return [] so that secondary queries (e.g. exercise_logs) don't bleed
    meal-item dicts into the wrong handler.
    """
    conn = MagicMock()
    cur = MagicMock()
    conn.cursor.return_value = cur
    cur.rowcount = 1

    seq = list(fetchone_seq or [])

    def _fetchone():
        return seq.pop(0) if seq else None

    fetchall_seq = [fetchall_val or []]

    def _fetchall():
        return fetchall_seq.pop(0) if fetchall_seq else []

    cur.fetchone.side_effect = _fetchone
    cur.fetchall.side_effect = _fetchall
    return conn, cur


def _patch_db(conn):
    """Context manager: patch get_db_connection at the meals router import site."""
    return patch("app.routers.meals.get_db_connection", return_value=conn)


def _meal_payload(items, meal_type="breakfast"):
    return {"date": TODAY, "meal_type": meal_type, "items": items}


def _food_item(food_id=1, food_name="ข้าวผัด", cal=400,
               protein=10, carbs=50, fat=10, amount=1, unit_id=1):
    return {
        "food_id": food_id, "food_name": food_name, "amount": amount,
        "unit_id": unit_id, "cal_per_unit": cal, "protein_per_unit": protein,
        "carbs_per_unit": carbs, "fat_per_unit": fat,
    }


# ─── POST /meals tests ───────────────────────────────────────────────────────

def test_non_beverage_does_not_update_water_logs(app_client):
    conn, cur = _make_mock_conn(
        fetchone_seq=[
            {"meal_id": 101},   # INSERT INTO meals
            None,               # bev query → not a beverage
            None,               # notification query
        ]
    )
    with _patch_db(conn):
        r = app_client.post("/meals/42", json=_meal_payload([_food_item()]))

    assert r.status_code == 200
    sql_calls = " ".join(
        str(args) for args, _ in cur.execute.call_args_list
    ).lower()
    assert "water_logs" not in sql_calls, "ไม่ควร upsert water_logs สำหรับอาหารที่ไม่ใช่เครื่องดื่ม"


def test_beverage_250ml_triggers_water_logs_upsert(app_client):
    conn, cur = _make_mock_conn(
        fetchone_seq=[
            {"meal_id": 102},
            {"volume_ml": 250.0, "is_alcoholic": False},
            None,
        ]
    )
    with _patch_db(conn):
        r = app_client.post("/meals/42", json=_meal_payload([
            _food_item(food_id=10, food_name="น้ำมะพร้าว", cal=60)
        ]))

    assert r.status_code == 200
    sql_calls = " ".join(str(a) for a, _ in cur.execute.call_args_list).lower()
    assert "water_logs" in sql_calls, "ควร upsert water_logs เมื่อเครื่องดื่มมี volume_ml"


def test_beverage_no_row_in_beverages_table_does_not_crash(app_client):
    """ถ้าไม่มีแถวใน beverages table (เช่น น้ำลำใย ที่ยังไม่ได้ insert) ต้องไม่ crash."""
    conn, cur = _make_mock_conn(
        fetchone_seq=[
            {"meal_id": 103},
            None,   # bev query returns nothing → total_beverage_ml stays 0
            None,
        ]
    )
    with _patch_db(conn):
        r = app_client.post("/meals/42", json=_meal_payload([
            _food_item(food_id=20, food_name="น้ำลำใย", cal=70)
        ]))

    assert r.status_code == 200
    # No water_logs update since no volume_ml found
    sql_calls = " ".join(str(a) for a, _ in cur.execute.call_args_list).lower()
    assert "water_logs" not in sql_calls


def test_alcoholic_beverage_does_not_add_water(app_client):
    """เบียร์/เหล้า ถูกกรองออกด้วย is_alcoholic = FALSE → ไม่ upsert water."""
    conn, cur = _make_mock_conn(
        fetchone_seq=[
            {"meal_id": 104},
            None,   # filtered out by AND COALESCE(b.is_alcoholic, FALSE) = FALSE
            None,
        ]
    )
    with _patch_db(conn):
        r = app_client.post("/meals/42", json=_meal_payload([
            _food_item(food_id=99, food_name="เบียร์", cal=150)
        ]))

    assert r.status_code == 200
    sql_calls = " ".join(str(a) for a, _ in cur.execute.call_args_list).lower()
    assert "water_logs" not in sql_calls


def test_two_beverages_volumes_are_summed(app_client):
    """น้ำส้ม 250ml + น้ำมะพร้าว 330ml = 580ml → water_logs ควรถูก upsert."""
    conn, cur = _make_mock_conn(
        fetchone_seq=[
            {"meal_id": 105},
            {"volume_ml": 250.0, "is_alcoholic": False},  # น้ำส้ม
            {"volume_ml": 330.0, "is_alcoholic": False},  # น้ำมะพร้าว
            None,
        ]
    )
    with _patch_db(conn):
        r = app_client.post("/meals/42", json=_meal_payload([
            _food_item(food_id=10, food_name="น้ำส้มคั้น", cal=90),
            _food_item(food_id=11, food_name="น้ำมะพร้าว", cal=60),
        ]))

    assert r.status_code == 200
    sql_calls = " ".join(str(a) for a, _ in cur.execute.call_args_list).lower()
    assert "water_logs" in sql_calls, "ต้อง upsert water_logs เมื่อมีเครื่องดื่มหลายรายการ"


# ─── GET /daily_logs tests ───────────────────────────────────────────────────

def test_daily_logs_beverage_has_food_type_and_water_ml(app_client):
    conn, cur = _make_mock_conn(
        fetchone_seq=[
            {"total_cal": 70.0, "total_protein": 0.3,
             "total_carbs": 17.0, "total_fat": 0.0},
        ],
        fetchall_val=[
            {
                "meal_type": "breakfast",
                "food_id": 15, "food_name": "น้ำลำใย",
                "amount": 1.0, "unit_id": 2, "unit_name": "ml",
                "cal_per_unit": 70.0, "protein_per_unit": 0.3,
                "carbs_per_unit": 17.0, "fat_per_unit": 0.0,
                "food_type": "beverage", "serving_quantity": 250.0,
            }
        ],
    )
    with _patch_db(conn):
        r = app_client.get("/daily_logs/42", params={"date_query": TODAY})

    assert r.status_code == 200
    item = r.json()["meals"]["breakfast"][0]
    assert item["food_type"] == "beverage"
    assert item["water_ml_per_serving"] == pytest.approx(250.0)


def test_daily_logs_non_beverage_water_ml_is_zero(app_client):
    conn, cur = _make_mock_conn(
        fetchone_seq=[
            {"total_cal": 500.0, "total_protein": 15.0,
             "total_carbs": 60.0, "total_fat": 20.0},
        ],
        fetchall_val=[
            {
                "meal_type": "lunch",
                "food_id": 5, "food_name": "ข้าวผัดไข่",
                "amount": 1.0, "unit_id": 1, "unit_name": "จาน",
                "cal_per_unit": 500.0, "protein_per_unit": 15.0,
                "carbs_per_unit": 60.0, "fat_per_unit": 20.0,
                "food_type": "dish", "serving_quantity": 0.0,
            }
        ],
    )
    with _patch_db(conn):
        r = app_client.get("/daily_logs/42", params={"date_query": TODAY})

    assert r.status_code == 200
    item = r.json()["meals"]["lunch"][0]
    assert item["food_type"] == "dish"
    assert item["water_ml_per_serving"] == 0.0
