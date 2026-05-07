from datetime import date, datetime, timedelta
from typing import Optional

from fastapi import APIRouter, HTTPException, Depends
from psycopg2.extras import RealDictCursor

from database import get_db_connection
from auth.dependencies import get_current_user
from app.core.dependencies import check_ownership
from app.core.observability import track, note_failure
from app.models.schemas import DailyLogUpdate
from app.services.nutrition_service import (
    _compute_target_calories, _meal_type_to_enum,
)
from app.services.nutrition_safety_service import evaluate_and_persist_calorie_safety

router = APIRouter()


@router.post("/meals/{user_id}")
def add_meal(user_id: int, log: DailyLogUpdate, current_user: dict = Depends(get_current_user)):
    check_ownership(current_user, user_id)
    # SLO-critical path: #14 dashboard groups success/latency by this op
    with track("meal.create", "POST /meals",
               user_id=user_id, meal_type=log.meal_type, items=len(log.items)):
        return _add_meal_impl(user_id, log)


def _add_meal_impl(user_id: int, log: DailyLogUpdate):
    conn = get_db_connection()
    try:
        cur = conn.cursor(cursor_factory=RealDictCursor)
        meal_type_db = _meal_type_to_enum(log.meal_type)
        total_cal = sum(item.cal_per_unit * item.amount for item in log.items)
        meal_ts = datetime.combine(log.date, datetime.min.time().replace(hour=12, minute=0, second=0))

        cur.execute("""
            INSERT INTO meals (user_id, meal_type, meal_time, total_amount)
            VALUES (%s, %s, %s, %s)
            RETURNING meal_id
        """, (user_id, meal_type_db, meal_ts, total_cal))
        meal_id = cur.fetchone()['meal_id']

        total_beverage_ml = 0
        for item in log.items:
            cur.execute("""
                INSERT INTO detail_items (meal_id, food_id, food_name, amount, unit_id,
                    cal_per_unit, protein_per_unit, carbs_per_unit, fat_per_unit)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
            """, (meal_id, item.food_id, item.food_name, item.amount, item.unit_id,
                  item.cal_per_unit, item.protein_per_unit, item.carbs_per_unit, item.fat_per_unit))

            # ตรวจว่าเป็นเครื่องดื่มไม่มีแอลกอฮอล์
            if item.food_id:
                cur.execute("""
                    SELECT
                        COALESCE(
                            b.volume_ml,
                            CASE WHEN lower(u.name) LIKE '%ml%' THEN f.serving_quantity ELSE NULL END
                        ) AS volume_ml,
                        COALESCE(b.is_alcoholic, FALSE) AS is_alcoholic
                    FROM foods f
                    LEFT JOIN beverages b ON b.food_id = f.food_id
                    LEFT JOIN units u ON u.unit_id = f.serving_unit_id
                    WHERE f.food_id = %s
                      AND f.food_type = 'beverage'
                      AND COALESCE(b.is_alcoholic, FALSE) = FALSE
                """, (item.food_id,))
                bev = cur.fetchone()
                if bev and bev['volume_ml']:
                    total_beverage_ml += float(bev['volume_ml']) * float(item.amount)

        # แปลง ml เป็นแก้ว (1 แก้ว = 250ml) แล้ว upsert water_logs
        if total_beverage_ml > 0:
            extra_glasses = max(1, round(total_beverage_ml / 250))  # int, min 1
            extra_ml = int(total_beverage_ml)
            cur.execute("""
                INSERT INTO water_logs (user_id, date_record, glasses, amount_ml)
                VALUES (%s, %s, %s, %s)
                ON CONFLICT (user_id, date_record)
                DO UPDATE SET
                    glasses   = LEAST(water_logs.glasses + EXCLUDED.glasses, 30),
                    amount_ml = water_logs.amount_ml + EXCLUDED.amount_ml
            """, (user_id, log.date, extra_glasses, extra_ml))

        conn.commit()

        nutrition_safety = []

        # Push calorie warning notification
        try:
            cur2 = conn.cursor(cursor_factory=RealDictCursor)
            cur2.execute("""
                SELECT ds.total_calories_intake, u.target_calories
                FROM daily_summaries ds
                JOIN users u ON u.user_id = ds.user_id
                WHERE ds.user_id = %s AND ds.date_record = %s
            """, (user_id, log.date))
            row = cur2.fetchone()
            if row:
                total_intake = float(row['total_calories_intake'] or 0)
                target = float(row['target_calories'] or 2000)
                if target > 0 and total_intake > target:
                    over = int(total_intake - target)
                    cur2.execute("""
                        INSERT INTO notifications (user_id, title, message, type)
                        SELECT %s, %s, %s, 'warning'
                        WHERE NOT EXISTS (
                            SELECT 1 FROM notifications
                            WHERE user_id = %s AND type = 'warning'
                              AND DATE(created_at) = CURRENT_DATE
                        )
                    """, (user_id,
                          'แคลอรี่เกินเป้าหมายแล้ว!',
                          f'วันนี้คุณรับแคลอรี่ไปแล้ว {int(total_intake)} kcal เกินเป้าหมายมา {over} kcal',
                          user_id))
                elif target > 0 and total_intake >= target * 0.9:
                    cur2.execute("""
                        INSERT INTO notifications (user_id, title, message, type)
                        SELECT %s, %s, %s, 'tip'
                        WHERE NOT EXISTS (
                            SELECT 1 FROM notifications
                            WHERE user_id = %s AND type = 'tip'
                              AND DATE(created_at) = CURRENT_DATE
                        )
                    """, (user_id,
                          'ใกล้ถึงเป้าหมายแล้ว',
                          f'วันนี้คุณรับแคลอรี่ {int(total_intake)} kcal ใกล้ถึงเป้าแล้ว มื้อหน้าเลือกเบาๆ นะ',
                          user_id))
            nutrition_safety = evaluate_and_persist_calorie_safety(
                conn,
                user_id,
                log.date,
            )
            conn.commit()
        except Exception:
            pass

        return {
            "message": "Meal recorded successfully",
            "nutrition_safety": nutrition_safety,
        }
    except Exception as e:
        conn.rollback()
        note_failure("meals.add_meal", e, user_id=user_id)
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        if conn:
            conn.close()


@router.get("/daily_summary/{user_id}")
def get_daily_summary(user_id: int, date_record: date, current_user: dict = Depends(get_current_user)):
    check_ownership(current_user, user_id)
    conn = get_db_connection()
    try:
        cur = conn.cursor(cursor_factory=RealDictCursor)
        cur.execute("SELECT * FROM users WHERE user_id = %s", (user_id,))
        user_row = cur.fetchone()
        if user_row and user_row.get('target_calories') is not None:
            target_cal = int(user_row['target_calories'])
        else:
            target_cal = _compute_target_calories(dict(user_row)) if user_row else 2000

        cur.execute("""
            SELECT total_calories_intake FROM daily_summaries
            WHERE user_id = %s AND date_record = %s
        """, (user_id, date_record))
        row = cur.fetchone()
        total_cal_val = int(row['total_calories_intake']) if row and row['total_calories_intake'] else 0

        cur.execute("""
            SELECT COALESCE(SUM(di.amount * di.cal_per_unit), 0) AS total_cal,
                   COALESCE(SUM(di.amount * di.protein_per_unit), 0) AS total_protein,
                   COALESCE(SUM(di.amount * di.carbs_per_unit), 0) AS total_carbs,
                   COALESCE(SUM(di.amount * di.fat_per_unit), 0) AS total_fat
            FROM meals m
            JOIN detail_items di ON di.meal_id = m.meal_id
            WHERE m.user_id = %s AND DATE(m.meal_time) = %s
        """, (user_id, date_record))
        macro = cur.fetchone()
        computed_cal = float(macro['total_cal']) if macro else 0
        if computed_cal > 0 or total_cal_val == 0:
            total_cal_val = int(computed_cal)
        total_prot = float(macro['total_protein']) if macro else 0
        total_carb = float(macro['total_carbs']) if macro else 0
        total_fat = float(macro['total_fat']) if macro else 0

        summary = {
            "total_calories_intake": total_cal_val, "total_protein": total_prot,
            "total_carbs": total_carb, "total_fat": total_fat,
            "target_calories": target_cal,
        }

        cur.execute("""
            SELECT m.meal_type, STRING_AGG(di.food_name, ', ') AS menu_names
            FROM meals m
            JOIN detail_items di ON di.meal_id = m.meal_id
            WHERE m.user_id = %s AND DATE(m.meal_time) = %s
            GROUP BY m.meal_type
        """, (user_id, date_record))
        menu_rows = cur.fetchall()
        summary['meals'] = {row['meal_type']: (row['menu_names'] or '') for row in menu_rows}
        return summary
    finally:
        if conn:
            conn.close()


@router.get("/meals/{user_id}/detail")
def get_meal_detail(user_id: int, date_record: date, meal_type: str, current_user: dict = Depends(get_current_user)):
    check_ownership(current_user, user_id)
    conn = get_db_connection()
    try:
        cur = conn.cursor(cursor_factory=RealDictCursor)
        cur.execute("""
            SELECT
                di.meal_id, di.food_name, di.amount,
                COALESCE(di.cal_per_unit, 0) AS cal_per_unit,
                COALESCE(di.protein_per_unit, 0) AS protein_per_unit,
                COALESCE(di.carbs_per_unit, 0) AS carbs_per_unit,
                COALESCE(di.fat_per_unit, 0) AS fat_per_unit,
                ROUND((COALESCE(di.amount,1) * COALESCE(di.cal_per_unit,0))::numeric, 1) AS total_cal,
                ROUND((COALESCE(di.amount,1) * COALESCE(di.protein_per_unit,0))::numeric, 1) AS total_protein,
                ROUND((COALESCE(di.amount,1) * COALESCE(di.carbs_per_unit,0))::numeric, 1) AS total_carbs,
                ROUND((COALESCE(di.amount,1) * COALESCE(di.fat_per_unit,0))::numeric, 1) AS total_fat,
                COALESCE(f.image_url,
                    (SELECT image_url FROM foods WHERE LOWER(food_name) = LOWER(di.food_name) LIMIT 1),
                    '') AS image_url
            FROM meals m
            JOIN detail_items di ON di.meal_id = m.meal_id
            LEFT JOIN foods f ON f.food_id = di.food_id
            WHERE m.user_id = %s AND DATE(m.meal_time) = %s AND m.meal_type::text = %s
            ORDER BY di.meal_id
        """, (user_id, date_record, meal_type))
        items = [dict(r) for r in cur.fetchall()]

        total_cal = sum(float(i['total_cal'] or 0) for i in items)
        total_protein = sum(float(i['total_protein'] or 0) for i in items)
        total_carbs = sum(float(i['total_carbs'] or 0) for i in items)
        total_fat = sum(float(i['total_fat'] or 0) for i in items)
        return {
            "meal_type": meal_type, "date_record": str(date_record), "items": items,
            "summary": {
                "total_cal": round(total_cal, 1), "total_protein": round(total_protein, 1),
                "total_carbs": round(total_carbs, 1), "total_fat": round(total_fat, 1),
            }
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        if conn:
            conn.close()


@router.get("/daily_logs/{user_id}/calendar")
def get_calendar_logs(user_id: int, month: int, year: int, current_user: dict = Depends(get_current_user)):
    check_ownership(current_user, user_id)
    conn = get_db_connection()
    try:
        cur = conn.cursor(cursor_factory=RealDictCursor)
        cur.execute("""
            SELECT date_record as date, total_calories_intake as calories
            FROM daily_summaries
            WHERE user_id = %s
              AND EXTRACT(MONTH FROM date_record) = %s
              AND EXTRACT(YEAR FROM date_record) = %s
        """, (user_id, month, year))
        return cur.fetchall()
    finally:
        if conn:
            conn.close()


@router.get("/daily_logs/{user_id}/weekly")
def get_weekly_logs(user_id: int, current_user: dict = Depends(get_current_user), week_start: Optional[str] = None):
    check_ownership(current_user, user_id)
    conn = get_db_connection()
    try:
        cur = conn.cursor(cursor_factory=RealDictCursor)
        if week_start:
            try:
                monday = datetime.strptime(week_start, "%Y-%m-%d").date()
            except ValueError:
                monday = date.today()
                while monday.weekday() != 0:
                    monday -= timedelta(days=1)
        else:
            monday = date.today()
            while monday.weekday() != 0:
                monday -= timedelta(days=1)
        sunday = monday + timedelta(days=6)

        cur.execute("""
            SELECT DATE(m.meal_time) AS d,
                   COALESCE(SUM(di.amount * di.cal_per_unit), 0) AS total_cal,
                   COALESCE(SUM(di.amount * di.protein_per_unit), 0) AS total_protein,
                   COALESCE(SUM(di.amount * di.carbs_per_unit), 0) AS total_carbs,
                   COALESCE(SUM(di.amount * di.fat_per_unit), 0) AS total_fat
            FROM meals m
            JOIN detail_items di ON di.meal_id = m.meal_id
            WHERE m.user_id = %s AND DATE(m.meal_time) >= %s AND DATE(m.meal_time) <= %s
            GROUP BY DATE(m.meal_time)
        """, (user_id, monday, sunday))
        macro_rows = {row["d"]: row for row in cur.fetchall()}

        result = []
        for i in range(7):
            d = monday + timedelta(days=i)
            macro = macro_rows.get(d)
            result.append({
                "date": d.isoformat(),
                "calories": int(macro["total_cal"]) if macro else 0,
                "protein": float(macro["total_protein"]) if macro else 0,
                "carbs": float(macro["total_carbs"]) if macro else 0,
                "fat": float(macro["total_fat"]) if macro else 0,
            })
        return result
    finally:
        if conn:
            conn.close()


@router.get("/daily_logs/{user_id}")
def get_daily_log_by_date(user_id: int, date_query: date, current_user: dict = Depends(get_current_user)):
    check_ownership(current_user, user_id)
    conn = get_db_connection()
    try:
        cur = conn.cursor(cursor_factory=RealDictCursor)
        cur.execute("""
            SELECT COALESCE(SUM(di.amount * di.cal_per_unit), 0) AS total_cal,
                   COALESCE(SUM(di.amount * di.protein_per_unit), 0) AS total_protein,
                   COALESCE(SUM(di.amount * di.carbs_per_unit), 0) AS total_carbs,
                   COALESCE(SUM(di.amount * di.fat_per_unit), 0) AS total_fat
            FROM meals m
            JOIN detail_items di ON di.meal_id = m.meal_id
            WHERE m.user_id = %s AND DATE(m.meal_time) = %s
        """, (user_id, date_query))
        macro = cur.fetchone()
        total_cal = int(macro['total_cal']) if macro else 0

        cur.execute("""
            SELECT m.meal_type, di.food_id, di.food_name, di.amount, di.unit_id,
                   u.name AS unit_name,
                   di.cal_per_unit, di.protein_per_unit, di.carbs_per_unit, di.fat_per_unit
            FROM meals m
            JOIN detail_items di ON di.meal_id = m.meal_id
            LEFT JOIN units u ON u.unit_id = di.unit_id
            WHERE m.user_id = %s AND DATE(m.meal_time) = %s
            ORDER BY m.meal_type, di.item_id
        """, (user_id, date_query))
        items = cur.fetchall()
        meals_map = {"breakfast": [], "lunch": [], "dinner": [], "snack": []}
        for item in items:
            meal_type = item["meal_type"]
            if meal_type in meals_map:
                meals_map[meal_type].append({
                    "food_id": item["food_id"],
                    "food_name": item["food_name"],
                    "amount": float(item["amount"]) if item["amount"] else 1.0,
                    "unit_id": item["unit_id"],
                    "unit_name": item["unit_name"] or "กรัม (g)",
                    "cal_per_unit": float(item["cal_per_unit"]) if item["cal_per_unit"] else 0,
                    "protein_per_unit": float(item["protein_per_unit"]) if item["protein_per_unit"] else 0,
                    "carbs_per_unit": float(item["carbs_per_unit"]) if item["carbs_per_unit"] else 0,
                    "fat_per_unit": float(item["fat_per_unit"]) if item["fat_per_unit"] else 0,
                })
        return {
            "calories": total_cal,
            "protein": int(macro["total_protein"]) if macro else 0,
            "carbs": int(macro["total_carbs"]) if macro else 0,
            "fat": int(macro["total_fat"]) if macro else 0,
            "meals": meals_map,
        }
    finally:
        if conn:
            conn.close()


@router.delete("/meals/clear/{user_id}")
def clear_meal_type(user_id: int, date_record: date, meal_type: str, current_user: dict = Depends(get_current_user)):
    check_ownership(current_user, user_id)
    conn = get_db_connection()
    try:
        cur = conn.cursor(cursor_factory=RealDictCursor)
        meal_type_db = _meal_type_to_enum(meal_type)
        cur.execute("""
            DELETE FROM meals
            WHERE user_id = %s AND DATE(meal_time) = %s AND meal_type = %s
        """, (user_id, date_record, meal_type_db))

        cur.execute("""
            SELECT COALESCE(SUM(di.amount * di.cal_per_unit), 0) AS total_cal
            FROM meals m
            JOIN detail_items di ON di.meal_id = m.meal_id
            WHERE m.user_id = %s AND DATE(m.meal_time) = %s
        """, (user_id, date_record))
        row = cur.fetchone()
        new_cal = float(row['total_cal']) if row else 0

        cur.execute("""
            UPDATE daily_summaries SET total_calories_intake = %s
            WHERE user_id = %s AND date_record = %s
        """, (new_cal, user_id, date_record))
        if cur.rowcount == 0 and new_cal == 0:
            cur.execute("DELETE FROM daily_summaries WHERE user_id = %s AND date_record = %s", (user_id, date_record))

        conn.commit()
        return {"message": f"Cleared {meal_type} successfully"}
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        if conn:
            conn.close()
