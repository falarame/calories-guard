from datetime import date
from typing import Optional

from fastapi import APIRouter, HTTPException, Depends
from psycopg2.extras import RealDictCursor

from database import get_db_connection
from auth.dependencies import get_current_user
from app.core.dependencies import check_ownership
from app.models.schemas import WaterLogUpdate

router = APIRouter()


@router.get("/water_logs/{user_id}")
def get_water_log(user_id: int, current_user: dict = Depends(get_current_user), date_record: Optional[str] = None):
    check_ownership(current_user, user_id)
    try:
        target_date = date.fromisoformat(date_record) if date_record else date.today()
    except ValueError:
        raise HTTPException(status_code=400, detail="date_record must be YYYY-MM-DD")
    conn = get_db_connection()
    try:
        cur = conn.cursor(cursor_factory=RealDictCursor)
        cur.execute("""
            SELECT amount_ml, date_record FROM water_logs
            WHERE user_id = %s AND date_record = %s
        """, (user_id, target_date))
        row = cur.fetchone()
        return {"date_record": target_date.isoformat(), "amount_ml": int(row["amount_ml"]) if row else 0}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        if conn:
            conn.close()


@router.post("/water_logs/{user_id}")
def upsert_water_log(user_id: int, entry: WaterLogUpdate, current_user: dict = Depends(get_current_user)):
    check_ownership(current_user, user_id)
    if entry.amount_ml < 0:
        raise HTTPException(status_code=400, detail="amount_ml must be >= 0")
    target_date = entry.date_record or date.today()
    conn = get_db_connection()
    try:
        cur = conn.cursor(cursor_factory=RealDictCursor)
        glasses = max(0, round(entry.amount_ml / 250))
        cur.execute("""
            INSERT INTO water_logs (user_id, date_record, amount_ml, glasses)
            VALUES (%s, %s, %s, %s)
            ON CONFLICT (user_id, date_record)
            DO UPDATE SET amount_ml = EXCLUDED.amount_ml,
                          glasses   = EXCLUDED.glasses,
                          updated_at = NOW()
            RETURNING amount_ml
        """, (user_id, target_date, entry.amount_ml, glasses))
        saved = cur.fetchone()["amount_ml"]
        conn.commit()
        return {"date_record": target_date.isoformat(), "amount_ml": saved}
    except HTTPException:
        raise
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        if conn:
            conn.close()
