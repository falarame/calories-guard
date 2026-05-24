
from fastapi import APIRouter, HTTPException, Depends
from psycopg2.extras import RealDictCursor

from database import get_db_connection
from auth.dependencies import get_current_user
from app.core.dependencies import check_ownership
from app.models.schemas import RecipeReview, AllergyUpdate

router = APIRouter()


def _get_recipe_id_for_food(cur, food_id: int) -> int:
    """Resolve the internal recipe_id while keeping public APIs food_id-based."""
    cur.execute(
        """
        SELECT recipe_id
        FROM recipes
        WHERE food_id = %s AND deleted_at IS NULL
        """,
        (food_id,),
    )
    row = cur.fetchone()
    if not row:
        raise HTTPException(status_code=404, detail="Recipe not found")
    return row["recipe_id"]


# --- Favorites ---

@router.get("/recipes/{food_id}/favorite/{user_id}")
def get_favorite_status(food_id: int, user_id: int, current_user: dict = Depends(get_current_user)):
    check_ownership(current_user, user_id)
    conn = get_db_connection()
    try:
        cur = conn.cursor(cursor_factory=RealDictCursor)
        cur.execute("SELECT 1 FROM user_favorites WHERE user_id = %s AND food_id = %s", (user_id, food_id))
        return {"is_favorite": cur.fetchone() is not None}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        if conn:
            conn.close()


@router.post("/recipes/{food_id}/favorite/{user_id}")
def toggle_favorite(food_id: int, user_id: int, current_user: dict = Depends(get_current_user)):
    check_ownership(current_user, user_id)
    conn = get_db_connection()
    try:
        cur = conn.cursor(cursor_factory=RealDictCursor)
        cur.execute("SELECT 1 FROM user_favorites WHERE user_id = %s AND food_id = %s", (user_id, food_id))
        exists = cur.fetchone() is not None
        if exists:
            cur.execute("DELETE FROM user_favorites WHERE user_id = %s AND food_id = %s", (user_id, food_id))
            is_favorite = False
        else:
            cur.execute("INSERT INTO user_favorites (user_id, food_id) VALUES (%s, %s)", (user_id, food_id))
            is_favorite = True
        conn.commit()
        return {"is_favorite": is_favorite}
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        if conn:
            conn.close()


@router.get("/users/{user_id}/favorites")
def get_user_favorites(user_id: int, current_user: dict = Depends(get_current_user)):
    check_ownership(current_user, user_id)
    conn = get_db_connection()
    try:
        cur = conn.cursor(cursor_factory=RealDictCursor)
        cur.execute("""
            SELECT f.food_id, f.food_name, f.calories, f.protein, f.carbs, f.fat,
                   f.image_url, uf.created_at AS favorited_at
            FROM user_favorites uf
            JOIN foods f ON f.food_id = uf.food_id
            WHERE uf.user_id = %s ORDER BY uf.created_at DESC
        """, (user_id,))
        return cur.fetchall()
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        if conn:
            conn.close()


# --- Reviews ---

@router.get("/recipes/{food_id}/reviews")
def get_recipe_reviews(food_id: int):
    conn = get_db_connection()
    try:
        cur = conn.cursor(cursor_factory=RealDictCursor)
        recipe_id = _get_recipe_id_for_food(cur, food_id)
        cur.execute("""
            WITH review_stats AS (
                SELECT recipe_id,
                    COUNT(*) AS review_count,
                    ROUND(AVG(rating)::numeric, 1) AS avg_rating,
                    COUNT(*) FILTER (WHERE rating = 5) AS five_star,
                    COUNT(*) FILTER (WHERE rating = 4) AS four_star,
                    COUNT(*) FILTER (WHERE rating = 3) AS three_star,
                    COUNT(*) FILTER (WHERE rating = 2) AS two_star,
                    COUNT(*) FILTER (WHERE rating = 1) AS one_star
                FROM recipe_reviews WHERE recipe_id = %s GROUP BY recipe_id
            )
            SELECT rr.review_id, rr.user_id, u.username, rr.rating, rr.comment, rr.created_at,
                   rs.review_count, rs.avg_rating,
                   rs.five_star, rs.four_star, rs.three_star, rs.two_star, rs.one_star
            FROM recipe_reviews rr
            JOIN users u ON u.user_id = rr.user_id
            LEFT JOIN review_stats rs ON rs.recipe_id = rr.recipe_id
            WHERE rr.recipe_id = %s ORDER BY rr.created_at DESC
        """, (recipe_id, recipe_id))
        rows = cur.fetchall()
        if not rows:
            return {"reviews": [], "review_count": 0, "avg_rating": None, "rating_distribution": {}}
        stats = rows[0]
        return {
            "reviews": [
                {"review_id": r["review_id"], "user_id": r["user_id"],
                 "username": r["username"], "rating": r["rating"],
                 "comment": r["comment"],
                 "created_at": r["created_at"].isoformat() if r["created_at"] else None}
                for r in rows
            ],
            "review_count": stats["review_count"],
            "avg_rating": float(stats["avg_rating"]) if stats["avg_rating"] else None,
            "rating_distribution": {
                "5": stats["five_star"], "4": stats["four_star"],
                "3": stats["three_star"], "2": stats["two_star"], "1": stats["one_star"]
            },
        }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        if conn:
            conn.close()


@router.post("/recipes/{food_id}/review")
def upsert_recipe_review(food_id: int, review: RecipeReview):
    if not (1 <= review.rating <= 5):
        raise HTTPException(status_code=400, detail="Rating must be between 1 and 5")
    conn = get_db_connection()
    try:
        cur = conn.cursor(cursor_factory=RealDictCursor)
        recipe_id = _get_recipe_id_for_food(cur, food_id)
        cur.execute(
            """
            INSERT INTO recipe_reviews (recipe_id, user_id, rating, comment)
            VALUES (%s, %s, %s, %s)
            ON CONFLICT (recipe_id, user_id)
            DO UPDATE SET
                rating = EXCLUDED.rating,
                comment = EXCLUDED.comment,
                created_at = NOW()
            RETURNING review_id
            """,
            (recipe_id, review.user_id, review.rating, review.comment),
        )
        review_id = cur.fetchone()["review_id"]
        conn.commit()
        return {"message": "Review saved", "review_id": review_id}
    except HTTPException:
        raise
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        if conn:
            conn.close()


# --- Allergies ---

@router.get("/allergy_flags")
def get_allergy_flags():
    conn = get_db_connection()
    try:
        cur = conn.cursor(cursor_factory=RealDictCursor)
        cur.execute("SELECT flag_id, name, description FROM allergy_flags ORDER BY flag_id ASC")
        return cur.fetchall()
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        if conn:
            conn.close()


@router.get("/users/{user_id}/allergies")
def get_user_allergies(user_id: int, current_user: dict = Depends(get_current_user)):
    check_ownership(current_user, user_id)
    conn = get_db_connection()
    try:
        cur = conn.cursor(cursor_factory=RealDictCursor)
        cur.execute("""
            SELECT af.flag_id, af.name, af.description
            FROM user_allergy_preferences uap
            JOIN allergy_flags af ON af.flag_id = uap.flag_id
            WHERE uap.user_id = %s ORDER BY af.flag_id
        """, (user_id,))
        rows = cur.fetchall()
        return {"flag_ids": [r["flag_id"] for r in rows], "flags": [dict(r) for r in rows]}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        if conn:
            conn.close()


@router.post("/users/{user_id}/allergies")
def set_user_allergies(user_id: int, body: AllergyUpdate, current_user: dict = Depends(get_current_user)):
    check_ownership(current_user, user_id)
    conn = get_db_connection()
    try:
        cur = conn.cursor()
        cur.execute("DELETE FROM user_allergy_preferences WHERE user_id = %s", (user_id,))
        for flag_id in body.flag_ids:
            cur.execute("""
                INSERT INTO user_allergy_preferences (user_id, flag_id, preference_type)
                VALUES (%s, %s, 'allergy') ON CONFLICT (user_id, flag_id) DO NOTHING
            """, (user_id, flag_id))
        conn.commit()
        return {"message": "Allergies saved", "flag_ids": body.flag_ids}
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        if conn:
            conn.close()


# --- Leaderboard ---

_BADGE_WEIGHTS: dict[str, int] = {
    "streak_3": 1, "streak_7": 3, "streak_14": 5,
    "streak_30": 10, "streak_60": 20, "streak_90": 30, "streak_365": 100,
    "first_tier_1": 2, "first_tier_2": 5, "first_tier_3": 10, "first_tier_4": 20,
}


def _badge_score(badges: list) -> int:
    return sum(_BADGE_WEIGHTS.get(b, 0) for b in (badges or []))


def _fetch_leaderboard(cur, limit: int, sort_by: str = "xp") -> list:
    """Fetch and rank leaderboard rows.
    sort_by='xp'     -> weekly_xp (current week only) -> tier_level -> badge_score -> created_at ASC -> user_id
    sort_by='streak' -> current_streak -> total_login_days -> weekly_xp -> badge_score -> user_id

    Lazy weekly reset: เฉพาะแถวที่ weekly_xp_week == สัปดาห์ปัจจุบัน (Asia/Bangkok)
    ถึงนับเป็น weekly_xp ที่แสดง — กันค่าค้างของสัปดาห์ก่อนโผล่ขึ้น leaderboard
    """
    from datetime import datetime, timezone, timedelta
    _bkk = timezone(timedelta(hours=7))
    _now_bkk = datetime.now(_bkk)
    _iso_year, _iso_week, _ = _now_bkk.isocalendar()
    current_week = f"{_iso_year}-W{_iso_week:02d}"

    cur.execute("""
        SELECT u.user_id,
               COALESCE(u.username, 'ผู้ใช้')  AS username,
               COALESCE(u.current_streak, 0)    AS current_streak,
               COALESCE(u.total_login_days, 0)  AS total_login_days,
               u.avatar_url,
               u.created_at,
               COALESCE(g.tama_points, 0)       AS tama_points,
               CASE
                   WHEN g.weekly_xp_week = %s THEN COALESCE(g.weekly_xp, 0)
                   ELSE 0
               END                              AS weekly_xp,
               COALESCE(g.tier_level, 0)        AS tier_level,
               COALESCE(g.claimed_badges, '{}') AS claimed_badges
        FROM cleangoal.users u
        LEFT JOIN cleangoal.user_gamification g ON g.user_id = u.user_id
        WHERE u.deleted_at IS NULL
    """, (current_week,))
    rows = [dict(r) for r in cur.fetchall()]

    for row in rows:
        row["badge_score"] = _badge_score(row.get("claimed_badges") or [])
        # weekly_xp ตอนนี้เป็น 0 ถ้าไม่ใช่สัปดาห์ปัจจุบัน — ไม่ fallback ไป tama_points
        row["leaderboard_xp"] = int(row.get("weekly_xp") or 0)

    if sort_by == "streak":
        rows.sort(key=lambda r: (
            -r["current_streak"],
            -r["total_login_days"],
            -r["leaderboard_xp"],
            -r["badge_score"],
            r["user_id"],
        ))
    else:  # xp
        rows.sort(key=lambda r: (
            -r["leaderboard_xp"],
            -r["tier_level"],
            -r["badge_score"],
            (r["created_at"] or r["user_id"]),  # older account = smaller datetime = higher rank
            r["user_id"],
        ))
    result = []
    for i, row in enumerate(rows[:limit]):
        row["rank"] = i + 1
        result.append(row)
    return result


@router.get("/leaderboard")
def get_leaderboard(limit: int = 50):
    return get_global_leaderboard(limit)


@router.get("/leaderboard/global")
def get_global_leaderboard(limit: int = 50):
    conn = get_db_connection()
    try:
        cur = conn.cursor(cursor_factory=RealDictCursor)
        return _fetch_leaderboard(cur, limit, sort_by="xp")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        if conn:
            conn.close()


@router.get("/leaderboard/streak")
def get_streak_leaderboard(limit: int = 50):
    conn = get_db_connection()
    try:
        cur = conn.cursor(cursor_factory=RealDictCursor)
        return _fetch_leaderboard(cur, limit, sort_by="streak")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        if conn:
            conn.close()
