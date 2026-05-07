"""Exercise / activity calorie logs — persisted to exercise_logs (v10 migration)."""

from datetime import date

from fastapi import APIRouter, Depends, HTTPException
from psycopg2.extras import RealDictCursor

from database import get_db_connection
from auth.dependencies import get_current_user
from app.core.dependencies import check_ownership
from app.models.schemas import ExerciseLogCreate

router = APIRouter()


@router.get("/exercise_logs/{user_id}")
def list_exercise_logs(
    user_id: int,
    date_record: date,
    current_user: dict = Depends(get_current_user),
):
    check_ownership(current_user, user_id)
    conn = get_db_connection()
    try:
        cur = conn.cursor(cursor_factory=RealDictCursor)
        cur.execute(
            """
            SELECT log_id, date_record, activity_name, duration_minutes,
                   calories_burned, intensity, note, created_at
            FROM exercise_logs
            WHERE user_id = %s AND date_record = %s
            ORDER BY log_id ASC
            """,
            (user_id, date_record),
        )
        rows = cur.fetchall()
        return {
            "date_record": str(date_record),
            "items": [
                {
                    "log_id": r["log_id"],
                    "activity_name": r["activity_name"],
                    "duration_minutes": int(r["duration_minutes"] or 0),
                    "calories_burned": float(r["calories_burned"] or 0),
                    "intensity": r["intensity"] or "moderate",
                    "note": r["note"],
                }
                for r in rows
            ],
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        if conn:
            conn.close()


@router.post("/exercise_logs/{user_id}")
def create_exercise_log(
    user_id: int,
    entry: ExerciseLogCreate,
    current_user: dict = Depends(get_current_user),
):
    check_ownership(current_user, user_id)
    if entry.calories_burned < 0:
        raise HTTPException(status_code=400, detail="calories_burned must be >= 0")
    if entry.duration_minutes < 0:
        raise HTTPException(status_code=400, detail="duration_minutes must be >= 0")

    conn = get_db_connection()
    try:
        cur = conn.cursor(cursor_factory=RealDictCursor)

        # Replace prior Samsung Health aggregate for this day (single sync row).
        if entry.activity_name.strip().startswith("Samsung Health"):
            cur.execute(
                """
                DELETE FROM exercise_logs
                WHERE user_id = %s AND date_record = %s
                  AND activity_name LIKE 'Samsung Health%%'
                """,
                (user_id, entry.date_record),
            )

        cur.execute(
            """
            INSERT INTO exercise_logs (
                user_id, date_record, activity_name, duration_minutes,
                calories_burned, intensity, note
            )
            VALUES (%s, %s, %s, %s, %s, %s, %s)
            RETURNING log_id
            """,
            (
                user_id,
                entry.date_record,
                entry.activity_name.strip()[:100],
                entry.duration_minutes,
                entry.calories_burned,
                entry.intensity or "moderate",
                entry.note,
            ),
        )
        row = cur.fetchone()
        conn.commit()
        log_id = int(row["log_id"]) if row else 0
        return {"log_id": log_id, "message": "ok"}
    except HTTPException:
        raise
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        if conn:
            conn.close()


@router.delete("/exercise_logs/{user_id}/{log_id}")
def delete_exercise_log(
    user_id: int,
    log_id: int,
    current_user: dict = Depends(get_current_user),
):
    check_ownership(current_user, user_id)
    conn = get_db_connection()
    try:
        cur = conn.cursor()
        cur.execute(
            """
            DELETE FROM exercise_logs
            WHERE log_id = %s AND user_id = %s
            """,
            (log_id, user_id),
        )
        deleted = cur.rowcount
        conn.commit()
        if deleted == 0:
            raise HTTPException(status_code=404, detail="Log not found")
        return {"message": "deleted"}
    except HTTPException:
        raise
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        if conn:
            conn.close()
