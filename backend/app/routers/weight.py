from datetime import date, timedelta

from fastapi import APIRouter, HTTPException, Depends
from psycopg2.extras import RealDictCursor

from database import get_db_connection
from auth.dependencies import get_current_user
from app.core.dependencies import check_ownership
from app.models.schemas import WeightLogEntry
from app.services.nutrition_service import _check_1700_calorie_warning

router = APIRouter()


@router.post("/weight_logs/{user_id}")
def add_weight_log(user_id: int, entry: WeightLogEntry, current_user: dict = Depends(get_current_user)):
    check_ownership(current_user, user_id)
    conn = get_db_connection()
    try:
        cur = conn.cursor()
        target_date = entry.recorded_date or date.today()
        cur.execute(
            """
            UPDATE weight_logs
            SET weight_kg = %s
            WHERE user_id = %s AND recorded_date = %s
            """,
            (entry.weight_kg, user_id, target_date),
        )
        if cur.rowcount == 0:
            cur.execute(
                """
                INSERT INTO weight_logs (user_id, weight_kg, recorded_date)
                VALUES (%s, %s, %s)
                """,
                (user_id, entry.weight_kg, target_date),
            )
        cur.execute("""
            UPDATE users SET current_weight_kg = %s, updated_at = NOW() WHERE user_id = %s
        """, (entry.weight_kg, user_id))
        conn.commit()
        return {
            "message": "บันทึกน้ำหนักสำเร็จ",
            "recorded_date": target_date.isoformat(),
            "weight_kg": entry.weight_kg,
        }
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        if conn:
            conn.close()


@router.get("/users/{user_id}/weight_logs")
def get_weight_logs(user_id: int, current_user: dict = Depends(get_current_user)):
    check_ownership(current_user, user_id)
    conn = get_db_connection()
    try:
        cur = conn.cursor(cursor_factory=RealDictCursor)
        cur.execute("""
            SELECT recorded_date::text AS date, weight_kg AS weight
            FROM weight_logs WHERE user_id = %s
            ORDER BY recorded_date DESC LIMIT 30
        """, (user_id,))
        return [dict(r) for r in cur.fetchall()]
    finally:
        if conn:
            conn.close()


@router.get("/users/{user_id}/goal_progress")
def get_goal_progress(user_id: int, current_user: dict = Depends(get_current_user)):
    check_ownership(current_user, user_id)
    conn = get_db_connection()
    try:
        _check_1700_calorie_warning(user_id, conn)
        cur = conn.cursor(cursor_factory=RealDictCursor)
        cur.execute("""
            SELECT current_weight_kg, target_weight_kg, goal_type,
                   goal_start_date, goal_target_date, target_calories
            FROM users WHERE user_id = %s
        """, (user_id,))
        user = cur.fetchone()
        if not user:
            raise HTTPException(status_code=404, detail="User not found")

        current = float(user["current_weight_kg"] or 0)
        target = float(user["target_weight_kg"] or 0)

        start_weight = None
        if user.get("goal_start_date"):
            cur.execute("""
                SELECT weight_kg FROM weight_logs
                WHERE user_id = %s AND recorded_date >= %s
                ORDER BY recorded_date ASC LIMIT 1
            """, (user_id, user["goal_start_date"]))
            row = cur.fetchone()
            if row:
                start_weight = float(row["weight_kg"])

        if start_weight is None:
            cur.execute("""
                SELECT weight_kg FROM weight_logs
                WHERE user_id = %s ORDER BY recorded_date ASC LIMIT 1
            """, (user_id,))
            row = cur.fetchone()
            start_weight = float(row["weight_kg"]) if row else current

        goal_type = (user.get("goal_type") or "").lower()
        total = 0.0
        done = 0.0
        moving_toward_goal = True

        if goal_type == "lose_weight":
            total = start_weight - target
            done = start_weight - current
            moving_toward_goal = current <= start_weight
        elif goal_type == "gain_muscle":
            total = target - start_weight
            done = current - start_weight
            moving_toward_goal = current >= start_weight
        elif goal_type == "maintain_weight":
            diff = abs(current - target)
            progress_pct = round(max(0.0, min(100.0, (1.0 - (diff / max(target, 1.0))) * 100)), 1)
            remaining_kg = round(diff, 2)
            moving_toward_goal = diff <= abs(start_weight - target)
            total = 0.0
            done = 0.0
        else:
            total = abs(target - start_weight)
            done = abs(current - start_weight)

        if goal_type != "maintain_weight":
            if total <= 0:
                progress_pct = 100.0 if abs(current - target) <= 0.1 else 0.0
            else:
                progress_pct = round(max(0.0, min(100.0, (done / total) * 100)), 1)
            remaining_kg = round(abs(target - current), 2)

        estimated_days = None
        cur.execute("""
            SELECT recorded_date, weight_kg FROM weight_logs
            WHERE user_id = %s ORDER BY recorded_date DESC LIMIT 14
        """, (user_id,))
        recent = cur.fetchall()
        if len(recent) >= 2:
            newest = recent[0]
            oldest = recent[-1]
            day_gap = (newest["recorded_date"] - oldest["recorded_date"]).days
            newest_w = float(newest["weight_kg"])
            oldest_w = float(oldest["weight_kg"])
            if goal_type == "lose_weight":
                directional_change = oldest_w - newest_w
            elif goal_type == "gain_muscle":
                directional_change = newest_w - oldest_w
            else:
                directional_change = abs(newest_w - oldest_w)
            if day_gap > 0 and directional_change > 0 and remaining_kg > 0 and moving_toward_goal:
                rate = directional_change / day_gap
                estimated_days = int(remaining_kg / rate)

        today = date.today()
        monday = today - timedelta(days=today.weekday())
        cur.execute("""
            SELECT COALESCE(SUM(total_calories_intake), 0) AS weekly_intake
            FROM daily_summaries
            WHERE user_id = %s AND date_record >= %s AND date_record <= %s
        """, (user_id, monday, monday + timedelta(days=6)))
        row = cur.fetchone()
        weekly_intake = int(row["weekly_intake"]) if row else 0

        return {
            "current_weight": current, "target_weight": target,
            "start_weight": start_weight, "progress_pct": progress_pct,
            "remaining_kg": remaining_kg, "goal_type": user.get("goal_type"),
            "moving_toward_goal": moving_toward_goal,
            "goal_start_date": str(user["goal_start_date"]) if user.get("goal_start_date") else None,
            "goal_target_date": str(user["goal_target_date"]) if user.get("goal_target_date") else None,
            "estimated_days": estimated_days, "weekly_intake": weekly_intake,
        }
    finally:
        if conn:
            conn.close()


@router.get("/weight_status/{user_id}")
def get_weight_status(user_id: int, current_user: dict = Depends(get_current_user)):
    check_ownership(current_user, user_id)
    conn = get_db_connection()
    try:
        cur = conn.cursor(cursor_factory=RealDictCursor)
        cur.execute("""
            SELECT recorded_date, weight_kg FROM weight_logs
            WHERE user_id = %s ORDER BY recorded_date DESC LIMIT 1
        """, (user_id,))
        last_log = cur.fetchone()
        cur.execute("SELECT current_weight_kg FROM users WHERE user_id = %s", (user_id,))
        user_row = cur.fetchone()
        current_weight = user_row['current_weight_kg'] if user_row else None
        if not last_log:
            return {"requires_update": True, "days_passed": None, "last_weight": current_weight}
        last_date = last_log['recorded_date']
        days_passed = (date.today() - last_date).days
        return {
            "requires_update": days_passed >= 14,
            "days_passed": days_passed,
            "last_recorded_date": last_date,
            "last_weight": last_log['weight_kg']
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        if conn:
            conn.close()


@router.get("/progress_summary/{user_id}")
def get_progress_summary(user_id: int, current_user: dict = Depends(get_current_user)):
    check_ownership(current_user, user_id)
    conn = get_db_connection()
    try:
        _check_1700_calorie_warning(user_id, conn)
        cur = conn.cursor(cursor_factory=RealDictCursor)
        cur.execute("""
            SELECT current_weight_kg, target_weight_kg, goal_type, goal_start_date
            FROM users WHERE user_id = %s
        """, (user_id,))
        user_row = cur.fetchone()
        if not user_row:
            raise HTTPException(status_code=404, detail="User not found")

        current_w = float(user_row['current_weight_kg'] or 0)
        target_w = float(user_row['target_weight_kg'] or 0)
        goal_type = user_row['goal_type']

        cur.execute("""
            SELECT weight_kg FROM weight_logs
            WHERE user_id = %s ORDER BY recorded_date ASC LIMIT 1
        """, (user_id,))
        first_log = cur.fetchone()
        start_w = current_w
        if first_log:
            start_w = float(first_log['weight_kg'])
        else:
            if goal_type == 'lose_weight':
                start_w = target_w + 5.0 if start_w < target_w + 5 else start_w
            elif goal_type == 'gain_muscle':
                start_w = target_w - 5.0 if start_w > target_w - 5 else start_w

        progress_percent = 0.0
        if goal_type == 'lose_weight' and start_w > target_w:
            total_to_lose = start_w - target_w
            lost = start_w - current_w
            progress_percent = max(0.0, min(1.0, lost / total_to_lose))
        elif goal_type == 'gain_muscle' and target_w > start_w:
            total_to_gain = target_w - start_w
            gained = current_w - start_w
            progress_percent = max(0.0, min(1.0, gained / total_to_gain))
        elif goal_type == 'maintain_weight':
            diff = abs(current_w - target_w)
            progress_percent = max(0.0, 1.0 - (diff / max(target_w, 1.0)))

        return {
            "start_weight_kg": start_w, "current_weight_kg": current_w,
            "target_weight_kg": target_w, "progress_percent": progress_percent
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        if conn:
            conn.close()
