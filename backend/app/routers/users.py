from datetime import date, datetime, timezone
import json

from fastapi import APIRouter, HTTPException, Depends
from fastapi.responses import Response
from psycopg2.extras import RealDictCursor

from database import get_db_connection
from auth.dependencies import get_current_user
from app.core.dependencies import check_ownership
from app.models.schemas import FcmTokenUpdate, NotificationPrefsUpdate, UserRegionUpdate, UserUpdate
from app.services.nutrition_service import (
    _compute_target_calories, _compute_target_macros,
)

router = APIRouter()


def _json_default(o):
    """JSON encoder fallback for rows coming out of psycopg2 RealDictCursor."""
    if isinstance(o, (date, datetime)):
        return o.isoformat()
    # psycopg2 Decimal / memoryview etc. — stringify as last resort
    try:
        return float(o)
    except (TypeError, ValueError):
        return str(o)


# Tables owned by a user_id whose rows must ship with the PDPA export.
# Order matters only for readability; the cleanup job relies on ON DELETE
# CASCADE (see v15_e migration rationale) for the eventual hard-delete.
_EXPORT_TABLES = [
    ("meals", "user_id"),
    ("daily_summaries", "user_id"),
    ("detail_items", "meal_id"),  # indirect; filtered via meals join below
    ("weight_logs", "user_id"),
    ("water_logs", "user_id"),
    ("exercise_logs", "user_id"),
    ("notifications", "user_id"),
    ("user_allergy_preferences", "user_id"),
    ("user_favorites", "user_id"),
    ("user_meal_plans", "user_id"),
    ("temp_food", "user_id"),
    ("food_regional_name_submissions", "user_id"),
]


@router.put("/users/{user_id}")
def update_user(user_id: int, user_update: UserUpdate, current_user: dict = Depends(get_current_user)):
    check_ownership(current_user, user_id)
    conn = get_db_connection()
    try:
        cur = conn.cursor(cursor_factory=RealDictCursor)
        user_fields = []
        user_values = []
        if user_update.username:
            user_fields.append("username=%s")
            user_values.append(user_update.username)
        if user_update.goal_type:
            user_fields.append("goal_type=%s")
            user_values.append(user_update.goal_type)
        if user_update.target_weight_kg:
            user_fields.append("target_weight_kg=%s")
            user_values.append(user_update.target_weight_kg)
        if user_update.target_calories:
            user_fields.append("target_calories=%s")
            user_values.append(user_update.target_calories)
        if user_update.target_protein is not None:
            user_fields.append("target_protein=%s")
            user_values.append(user_update.target_protein)
        if user_update.target_carbs is not None:
            user_fields.append("target_carbs=%s")
            user_values.append(user_update.target_carbs)
        if user_update.target_fat is not None:
            user_fields.append("target_fat=%s")
            user_values.append(user_update.target_fat)
        if user_update.activity_level:
            user_fields.append("activity_level=%s")
            user_values.append(user_update.activity_level)
        if user_update.gender:
            user_fields.append("gender=%s")
            user_values.append(user_update.gender)
        if user_update.birth_date:
            user_fields.append("birth_date=%s")
            user_values.append(user_update.birth_date)
        if user_update.height_cm:
            user_fields.append("height_cm=%s")
            user_values.append(user_update.height_cm)
        if user_update.current_weight_kg:
            user_fields.append("current_weight_kg=%s")
            user_values.append(user_update.current_weight_kg)
        if user_update.goal_target_date:
            user_fields.append("goal_target_date=%s")
            user_values.append(user_update.goal_target_date)
        if user_update.avatar_url is not None:
            user_fields.append("avatar_url=%s")
            user_values.append(user_update.avatar_url)

        if user_fields:
            user_values.append(user_id)
            cur.execute(f"UPDATE users SET {', '.join(user_fields)} WHERE user_id = %s", tuple(user_values))

        cur.execute("SELECT * FROM users WHERE user_id = %s", (user_id,))
        row = cur.fetchone()
        if row:
            if user_update.target_calories is None:
                computed = _compute_target_calories(dict(row))
                cur.execute("UPDATE users SET target_calories = %s WHERE user_id = %s", (computed, user_id))
                row = {**row, 'target_calories': computed}
            if (user_update.target_protein is None
                    and user_update.target_carbs is None
                    and user_update.target_fat is None):
                p, c, f = _compute_target_macros(dict(row))
                cur.execute(
                    "UPDATE users SET target_protein = %s, target_carbs = %s, target_fat = %s WHERE user_id = %s",
                    (p, c, f, user_id),
                )

        if user_update.current_weight_kg is not None:
            cur.execute(
                """
                UPDATE weight_logs
                SET weight_kg = %s
                WHERE user_id = %s AND recorded_date = CURRENT_DATE
                """,
                (user_update.current_weight_kg, user_id),
            )
            if cur.rowcount == 0:
                cur.execute(
                    """
                    INSERT INTO weight_logs (user_id, weight_kg, recorded_date)
                    VALUES (%s, %s, CURRENT_DATE)
                    """,
                    (user_id, user_update.current_weight_kg),
                )

        conn.commit()
        return {"message": "Update successful"}
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        if conn:
            conn.close()


@router.get("/users/{user_id}")
def get_user_profile(user_id: int, current_user: dict = Depends(get_current_user)):
    check_ownership(current_user, user_id)
    conn = get_db_connection()
    try:
        cur = conn.cursor(cursor_factory=RealDictCursor)
        cur.execute("SELECT * FROM users WHERE user_id = %s AND deleted_at IS NULL", (user_id,))
        user = cur.fetchone()
        if not user:
            raise HTTPException(status_code=404, detail="User not found")

        target_cal = user.get('target_calories')
        if target_cal is None:
            target_cal = _compute_target_calories(dict(user))
            cur.execute("UPDATE users SET target_calories = %s WHERE user_id = %s", (target_cal, user_id))
            conn.commit()
            user = {**user, 'target_calories': target_cal}

        if user.get('target_protein') is None or user.get('target_carbs') is None or user.get('target_fat') is None:
            tp, tc, tf = _compute_target_macros(dict(user))
            cur.execute("UPDATE users SET target_protein = %s, target_carbs = %s, target_fat = %s WHERE user_id = %s", (tp, tc, tf, user_id))
            conn.commit()
            user = {**user, 'target_protein': tp, 'target_carbs': tc, 'target_fat': tf}

        out = dict(user)
        out['target_calories'] = int(out['target_calories']) if out.get('target_calories') is not None else _compute_target_calories(out)
        tp, tc, tf = _compute_target_macros(out)
        out['target_protein'] = int(out['target_protein']) if out.get('target_protein') is not None else tp
        out['target_carbs'] = int(out['target_carbs']) if out.get('target_carbs') is not None else tc
        out['target_fat'] = int(out['target_fat']) if out.get('target_fat') is not None else tf
        out['current_streak'] = int(out['current_streak']) if out.get('current_streak') is not None else 0
        out['total_login_days'] = int(out['total_login_days']) if out.get('total_login_days') is not None else 0
        if out.get('last_login_date') and hasattr(out['last_login_date'], 'isoformat'):
            out['last_login_date'] = out['last_login_date'].isoformat() if out['last_login_date'] else None
        if out.get('birth_date') and hasattr(out['birth_date'], 'isoformat'):
            out['birth_date'] = out['birth_date'].isoformat()[:10] if out['birth_date'] else None
        if out.get('goal_start_date') and hasattr(out['goal_start_date'], 'isoformat'):
            out['goal_start_date'] = out['goal_start_date'].isoformat()[:10] if out['goal_start_date'] else None
        if out.get('goal_target_date') and hasattr(out['goal_target_date'], 'isoformat'):
            out['goal_target_date'] = out['goal_target_date'].isoformat()[:10] if out['goal_target_date'] else None
        return out
    finally:
        if conn:
            conn.close()


@router.get("/users/{user_id}/region")
def get_user_region(user_id: int, current_user: dict = Depends(get_current_user)):
    check_ownership(current_user, user_id)
    conn = get_db_connection()
    try:
        cur = conn.cursor(cursor_factory=RealDictCursor)
        cur.execute(
            """
            SELECT region::text AS region, region_source
            FROM users
            WHERE user_id = %s AND deleted_at IS NULL
            """,
            (user_id,),
        )
        row = cur.fetchone()
        if not row:
            raise HTTPException(status_code=404, detail="User not found")
        return row
    finally:
        if conn:
            conn.close()


@router.put("/users/{user_id}/region")
def update_user_region(
    user_id: int,
    payload: UserRegionUpdate,
    current_user: dict = Depends(get_current_user),
):
    check_ownership(current_user, user_id)
    conn = get_db_connection()
    try:
        cur = conn.cursor(cursor_factory=RealDictCursor)
        region = payload.region.value if payload.region else None
        region_source = "manual" if region else "unset"
        cur.execute(
            """
            UPDATE users
            SET region = %s::thai_region,
                region_source = %s
            WHERE user_id = %s AND deleted_at IS NULL
            RETURNING region::text AS region, region_source
            """,
            (region, region_source, user_id),
        )
        row = cur.fetchone()
        if not row:
            raise HTTPException(status_code=404, detail="User not found")
        conn.commit()
        return row
    except HTTPException:
        raise
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        if conn:
            conn.close()


@router.delete("/users/{user_id}")
def delete_user(user_id: int, current_user: dict = Depends(get_current_user)):
    """PDPA soft-delete. Sets users.deleted_at = now().

    The row stays for 30 days for support/audit + to survive accidental
    taps. backend/scripts/cleanup.py hard-deletes rows whose `deleted_at`
    is older than that, and FK `ON DELETE CASCADE` cleans the children.

    Follow-up on the token side: the client MUST call
    `supabase.auth.signOut()` after a successful 204.
    """
    check_ownership(current_user, user_id)
    conn = get_db_connection()
    try:
        cur = conn.cursor()
        cur.execute(
            "UPDATE users SET deleted_at = NOW() "
            "WHERE user_id = %s AND deleted_at IS NULL",
            (user_id,),
        )
        if cur.rowcount == 0:
            # Either no such user, or already tombstoned. Either way we
            # don't want to leak the distinction back to the caller.
            conn.rollback()
            raise HTTPException(status_code=404, detail="User not found or already deleted")
        conn.commit()
        return {"message": "Account scheduled for deletion", "retention_days": 30}
    except HTTPException:
        raise
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        if conn:
            conn.close()


@router.get("/users/{user_id}/export")
def export_user_data(user_id: int, current_user: dict = Depends(get_current_user)):
    """PDPA Art. 30 data export.

    Returns a JSON attachment containing every row owned by this user
    across the tables in `_EXPORT_TABLES`, plus the user profile itself.
    Shape is table-keyed: `{"users": {...}, "meals": [...], ...}`.

    Not paginated — Thai beta dataset per-user is small (< 10 MB even
    after a year). If that stops being true, switch to streaming NDJSON.
    """
    check_ownership(current_user, user_id)
    conn = get_db_connection()
    try:
        cur = conn.cursor(cursor_factory=RealDictCursor)

        cur.execute("SELECT * FROM users WHERE user_id = %s", (user_id,))
        user_row = cur.fetchone()
        if not user_row:
            raise HTTPException(status_code=404, detail="User not found")

        bundle: dict = {
            "export_version": 1,
            "exported_at": datetime.now(timezone.utc).isoformat(),
            "user_id": user_id,
            "users": dict(user_row),
        }

        for table, col in _EXPORT_TABLES:
            if table == "detail_items":
                # detail_items → meals → user_id
                cur.execute(
                    "SELECT d.* FROM detail_items d "
                    "JOIN meals m ON m.meal_id = d.meal_id "
                    "WHERE m.user_id = %s",
                    (user_id,),
                )
            else:
                cur.execute(f"SELECT * FROM {table} WHERE {col} = %s", (user_id,))
            rows = cur.fetchall()
            bundle[table] = [dict(r) for r in rows]

        body = json.dumps(bundle, default=_json_default, ensure_ascii=False)
        headers = {
            "Content-Disposition": f'attachment; filename="calories_guard_export_{user_id}.json"',
        }
        return Response(content=body, media_type="application/json; charset=utf-8", headers=headers)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        if conn:
            conn.close()


@router.get("/users/{user_id}/lifecycle_check")
def lifecycle_check(user_id: int, current_user: dict = Depends(get_current_user)):
    check_ownership(current_user, user_id)
    conn = get_db_connection()
    if not conn:
        raise HTTPException(status_code=503, detail="DB unavailable")
    try:
        cur = conn.cursor(cursor_factory=RealDictCursor)
        today = date.today()
        cur.execute("""
            SELECT birth_date, goal_start_date, goal_target_date,
                   current_weight_kg, target_weight_kg, target_calories,
                   last_tdee_recalc_date, created_at, activity_level,
                   gender, height_cm
            FROM users WHERE user_id = %s
        """, (user_id,))
        user = cur.fetchone()
        if not user:
            raise HTTPException(status_code=404, detail="User not found")

        cur.execute("SELECT MAX(recorded_date) AS last_date FROM weight_logs WHERE user_id = %s", (user_id,))
        wrow = cur.fetchone()
        last_weight_date = wrow["last_date"] if wrow else None
        if last_weight_date and hasattr(last_weight_date, 'date'):
            last_weight_date = last_weight_date.date()
        days_since_weight = (today - last_weight_date).days if last_weight_date else 9999
        weight_overdue = days_since_weight >= 14

        is_birthday = False
        tdee_needs_update = False
        if user["birth_date"]:
            bday = user["birth_date"]
            is_birthday = (bday.month == today.month and bday.day == today.day)
            birthday_this_year = date(today.year, bday.month, bday.day)
            last_recalc = user["last_tdee_recalc_date"]
            if birthday_this_year <= today:
                if last_recalc is None or last_recalc < birthday_this_year:
                    tdee_needs_update = True

        monthly_summary = False
        created = user.get("created_at")
        if created:
            days_since_join = (today - created.date()).days if hasattr(created, 'date') else 0
            monthly_summary = (days_since_join > 0 and days_since_join % 30 == 0)

        goal_days_left = None
        on_track = None
        if user["goal_target_date"] and user["goal_start_date"]:
            gtd = user["goal_target_date"]
            gsd = user["goal_start_date"]
            if hasattr(gtd, 'date'):
                gtd = gtd.date()
            if hasattr(gsd, 'date'):
                gsd = gsd.date()
            goal_days_left = (gtd - today).days
            total_days = (gtd - gsd).days
            days_elapsed = (today - gsd).days
            if total_days > 0 and user["current_weight_kg"] and user["target_weight_kg"]:
                start_w = float(user["current_weight_kg"])
                target_w = float(user["target_weight_kg"])
                expected_loss_pct = days_elapsed / total_days
                expected_weight = start_w + (target_w - start_w) * expected_loss_pct
                on_track = float(user["current_weight_kg"]) <= expected_weight + 0.5

        return {
            "user_id": user_id,
            "today": today.isoformat(),
            "weight_overdue": weight_overdue,
            "days_since_weight": days_since_weight if days_since_weight != 9999 else None,
            "is_birthday": is_birthday,
            "tdee_needs_update": tdee_needs_update,
            "monthly_summary": monthly_summary,
            "goal_days_left": goal_days_left,
            "on_track": on_track,
        }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        if conn:
            conn.close()


@router.put("/users/{user_id}/fcm_token")
def upsert_fcm_token(
    user_id: int,
    body: FcmTokenUpdate,
    current_user: dict = Depends(get_current_user),
):
    """Store or refresh the device FCM token for this user.

    Called by the Flutter client on login and on token refresh. The
    server-side re-engagement cron picks tokens from this column.
    """
    check_ownership(current_user, user_id)
    token = (body.fcm_token or "").strip()
    if not token:
        raise HTTPException(status_code=400, detail="fcm_token must not be empty")
    conn = get_db_connection()
    if not conn:
        raise HTTPException(status_code=503, detail="DB unavailable")
    try:
        cur = conn.cursor()
        cur.execute(
            "UPDATE users SET fcm_token = %s, fcm_token_updated_at = NOW() "
            "WHERE user_id = %s AND deleted_at IS NULL",
            (token, user_id),
        )
        if cur.rowcount == 0:
            conn.rollback()
            raise HTTPException(status_code=404, detail="User not found")
        conn.commit()
        return {"message": "FCM token updated"}
    except HTTPException:
        raise
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        if conn:
            conn.close()


@router.delete("/users/{user_id}/fcm_token")
def clear_fcm_token(
    user_id: int,
    current_user: dict = Depends(get_current_user),
):
    """Clear the device FCM token. Called on logout / account deletion."""
    check_ownership(current_user, user_id)
    conn = get_db_connection()
    if not conn:
        raise HTTPException(status_code=503, detail="DB unavailable")
    try:
        cur = conn.cursor()
        cur.execute(
            "UPDATE users SET fcm_token = NULL, fcm_token_updated_at = NOW() "
            "WHERE user_id = %s",
            (user_id,),
        )
        conn.commit()
        return {"message": "FCM token cleared"}
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        if conn:
            conn.close()


@router.get("/users/{user_id}/notification_prefs")
def get_notification_prefs(
    user_id: int,
    current_user: dict = Depends(get_current_user),
):
    """Return the stored notification_prefs JSONB for this user."""
    check_ownership(current_user, user_id)
    conn = get_db_connection()
    if not conn:
        raise HTTPException(status_code=503, detail="DB unavailable")
    try:
        cur = conn.cursor(cursor_factory=RealDictCursor)
        cur.execute(
            "SELECT notification_prefs FROM users WHERE user_id = %s AND deleted_at IS NULL",
            (user_id,),
        )
        row = cur.fetchone()
        if not row:
            raise HTTPException(status_code=404, detail="User not found")
        prefs = row["notification_prefs"] or {}

        # Feature 3 – Adaptive Timing: compute 7-day rolling average log time
        # per meal type, subtract 30 min to get the suggested reminder time.
        suggested_meal_times: dict = {}
        try:
            cur.execute("""
                SELECT meal_type::text,
                       ROUND(AVG(
                           EXTRACT(HOUR FROM (meal_time AT TIME ZONE 'Asia/Bangkok')) * 60
                           + EXTRACT(MINUTE FROM (meal_time AT TIME ZONE 'Asia/Bangkok'))
                       ))::int AS avg_min
                FROM meals
                WHERE user_id = %s
                  AND (meal_time AT TIME ZONE 'Asia/Bangkok')::date
                      >= CURRENT_DATE - INTERVAL '7 days'
                  AND meal_type IN ('breakfast', 'lunch', 'dinner')
                GROUP BY meal_type
            """, (user_id,))
            for r in cur.fetchall():
                avg_min = int(r["avg_min"] or 0)
                if avg_min <= 0:
                    continue
                # Buffer Zone: remind 15 min AFTER typical log time
                # (user has finished eating and is ready to open the app)
                suggest_min = min(avg_min + 15, 23 * 60 + 59)
                hm = (suggest_min // 60) * 100 + (suggest_min % 60)
                meal_key = {"breakfast": "breakfastHm", "lunch": "lunchHm",
                            "dinner": "dinnerHm"}.get(r["meal_type"])
                if meal_key:
                    suggested_meal_times[meal_key] = hm
        except Exception:
            pass  # non-critical; omit field on error

        return {
            "user_id": user_id,
            "notification_prefs": prefs,
            "suggested_meal_times": suggested_meal_times,
        }
    finally:
        if conn:
            conn.close()


@router.put("/users/{user_id}/notification_prefs")
def update_notification_prefs(
    user_id: int,
    body: NotificationPrefsUpdate,
    current_user: dict = Depends(get_current_user),
):
    """Upsert the notification_prefs JSONB.  Merges with existing prefs so
    callers can do partial updates without clobbering unrelated fields."""
    check_ownership(current_user, user_id)
    conn = get_db_connection()
    if not conn:
        raise HTTPException(status_code=503, detail="DB unavailable")
    try:
        cur = conn.cursor(cursor_factory=RealDictCursor)
        # Build only the fields that were actually provided
        patch: dict = {}
        if body.enabled is not None:
            patch["enabled"] = body.enabled
        if body.categories is not None:
            patch["categories"] = body.categories
        if body.quiet_hours is not None:
            patch["quietHours"] = body.quiet_hours
        if body.meal_times is not None:
            patch["mealTimes"] = body.meal_times
        if body.water_times_hh is not None:
            patch["waterTimesHH"] = body.water_times_hh
        if body.weigh_in_day is not None:
            patch["weighInDay"] = body.weigh_in_day

        if not patch:
            return {"message": "No changes"}

        # Merge into existing JSONB column (|| operator)
        cur.execute(
            """
            UPDATE users
            SET notification_prefs = COALESCE(notification_prefs, '{}'::jsonb) || %s::jsonb
            WHERE user_id = %s AND deleted_at IS NULL
            RETURNING notification_prefs
            """,
            (json.dumps(patch), user_id),
        )
        row = cur.fetchone()
        if not row:
            conn.rollback()
            raise HTTPException(status_code=404, detail="User not found")
        conn.commit()
        return {"user_id": user_id, "notification_prefs": row["notification_prefs"]}
    except HTTPException:
        raise
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        if conn:
            conn.close()


@router.post("/users/{user_id}/recalc_tdee")
def recalc_tdee(user_id: int, current_user: dict = Depends(get_current_user)):
    check_ownership(current_user, user_id)
    conn = get_db_connection()
    if not conn:
        raise HTTPException(status_code=503, detail="DB unavailable")
    try:
        cur = conn.cursor(cursor_factory=RealDictCursor)
        cur.execute("""
            SELECT gender, birth_date, height_cm, current_weight_kg,
                   target_weight_kg, activity_level, goal_type,
                   goal_start_date, goal_target_date
            FROM users WHERE user_id = %s
        """, (user_id,))
        u = cur.fetchone()
        if not u:
            raise HTTPException(status_code=404, detail="User not found")
        if not all([u["gender"], u["birth_date"], u["height_cm"], u["current_weight_kg"]]):
            raise HTTPException(status_code=400, detail="Insufficient user data for TDEE")

        today = date.today()
        age = today.year - u["birth_date"].year - (
            (today.month, today.day) < (u["birth_date"].month, u["birth_date"].day))
        w = float(u["current_weight_kg"])
        h = float(u["height_cm"])
        if u["gender"] == "male":
            bmr = 10 * w + 6.25 * h - 5 * age + 5
        else:
            bmr = 10 * w + 6.25 * h - 5 * age - 161
        activity_multipliers = {
            "sedentary": 1.2, "lightly_active": 1.375,
            "moderately_active": 1.55, "very_active": 1.725, "extra_active": 1.9
        }
        multiplier = activity_multipliers.get(u["activity_level"] or "sedentary", 1.2)
        tdee = bmr * multiplier
        new_target = _compute_target_calories(dict(u))
        macro_user = {**dict(u), "target_calories": new_target}
        target_protein, target_carbs, target_fat = _compute_target_macros(macro_user)
        cur.execute("""
            UPDATE users
            SET target_calories = %s,
                target_protein = %s,
                target_carbs = %s,
                target_fat = %s,
                last_tdee_recalc_date = %s
            WHERE user_id = %s
            RETURNING target_calories
        """, (new_target, target_protein, target_carbs, target_fat, today, user_id))
        conn.commit()
        saved = cur.fetchone()
        return {
            "user_id": user_id,
            "age": age,
            "bmr": round(bmr),
            "tdee": round(tdee),
            "target_protein": target_protein,
            "target_carbs": target_carbs,
            "target_fat": target_fat,
            "new_target_calories": saved["target_calories"],
            "recalc_date": today.isoformat(),
        }
    except HTTPException:
        raise
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        if conn:
            conn.close()


@router.get("/users/{user_id}/tama-points")
def get_tama_points(user_id: int):
    """Fetch tama_points + tier_level for a user."""
    conn = None
    try:
        conn = get_db_connection()
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                """
                SELECT tama_points, tier_level, claimed_badges,
                       COALESCE(gems, 0) AS gems
                FROM cleangoal.user_gamification
                WHERE user_id = %s
                """,
                (user_id,),
            )
            row = cur.fetchone()
        if row:
            points = int(row.get("tama_points") or 0)
            return {
                "tama_points": points,
                "weekly_xp": points,
                "tier_level": int(row.get("tier_level") or 0),
                "claimed_badges": row.get("claimed_badges") or [],
                "gems": int(row.get("gems") or 0),
            }
        return {"tama_points": 0, "weekly_xp": 0, "tier_level": 0, "claimed_badges": [], "gems": 0}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        if conn:
            conn.close()


@router.patch("/users/{user_id}/tama-points")
def sync_tama_points(user_id: int, payload: dict):
    """Upsert tama_points + tier_level + claimed_badges into user_gamification."""
    points  = int(payload.get("tama_points", payload.get("weekly_xp", 0)))
    tier    = int(payload.get("tier_level", 0))
    badges  = payload.get("claimed_badges")  # list[str] or None
    gems    = payload.get("gems")            # int or None
    conn = None
    try:
        conn = get_db_connection()
        with conn.cursor() as cur:
            if badges is not None and gems is not None:
                cur.execute(
                    """
                    INSERT INTO cleangoal.user_gamification
                        (user_id, tama_points, tier_level, claimed_badges, gems, gems_updated_at, updated_at)
                    VALUES (%s, %s, %s, %s, %s, NOW(), NOW())
                    ON CONFLICT (user_id) DO UPDATE
                      SET tama_points    = EXCLUDED.tama_points,
                          tier_level     = EXCLUDED.tier_level,
                          claimed_badges = EXCLUDED.claimed_badges,
                          gems           = EXCLUDED.gems,
                          gems_updated_at = NOW(),
                          updated_at     = NOW()
                    """,
                    (user_id, points, tier, badges, int(gems)),
                )
            elif badges is not None:
                cur.execute(
                    """
                    INSERT INTO cleangoal.user_gamification (user_id, tama_points, tier_level, claimed_badges, updated_at)
                    VALUES (%s, %s, %s, %s, NOW())
                    ON CONFLICT (user_id) DO UPDATE
                      SET tama_points    = EXCLUDED.tama_points,
                          tier_level     = EXCLUDED.tier_level,
                          claimed_badges = EXCLUDED.claimed_badges,
                          updated_at     = NOW()
                    """,
                    (user_id, points, tier, badges),
                )
            elif gems is not None:
                cur.execute(
                    """
                    INSERT INTO cleangoal.user_gamification (user_id, tama_points, tier_level, gems, gems_updated_at, updated_at)
                    VALUES (%s, %s, %s, %s, NOW(), NOW())
                    ON CONFLICT (user_id) DO UPDATE
                      SET tama_points     = EXCLUDED.tama_points,
                          tier_level      = EXCLUDED.tier_level,
                          gems            = EXCLUDED.gems,
                          gems_updated_at = NOW(),
                          updated_at      = NOW()
                    """,
                    (user_id, points, tier, int(gems)),
                )
            else:
                cur.execute(
                    """
                    INSERT INTO cleangoal.user_gamification (user_id, tama_points, tier_level, updated_at)
                    VALUES (%s, %s, %s, NOW())
                    ON CONFLICT (user_id) DO UPDATE
                      SET tama_points = EXCLUDED.tama_points,
                          tier_level  = EXCLUDED.tier_level,
                          updated_at  = NOW()
                    """,
                    (user_id, points, tier),
                )
        conn.commit()
        return {"ok": True}
    except Exception as e:
        if conn:
            conn.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        if conn:
            conn.close()


@router.get("/users/{user_id}/food-frequency")
def get_food_frequency(user_id: int):
    """Return how many times the user has eaten each food_id, sorted descending."""
    conn = None
    try:
        conn = get_db_connection()
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                """
                SELECT d.food_id, COUNT(*) AS count
                FROM cleangoal.detail_items d
                JOIN cleangoal.meals m ON m.meal_id = d.meal_id
                WHERE m.user_id = %s
                  AND d.food_id IS NOT NULL
                GROUP BY d.food_id
                ORDER BY count DESC
                """,
                (user_id,),
            )
            rows = cur.fetchall()
        return [{"food_id": r["food_id"], "count": int(r["count"])} for r in rows]
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        if conn:
            conn.close()
