from typing import List

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
            "SELECT review_id FROM recipe_reviews WHERE recipe_id = %s AND user_id = %s",
            (recipe_id, review.user_id),
        )
        existing = cur.fetchone()
        if existing:
            cur.execute(
                "UPDATE recipe_reviews SET rating = %s, comment = %s, created_at = NOW() "
                "WHERE review_id = %s RETURNING review_id",
                (review.rating, review.comment, existing["review_id"]),
            )
        else:
            cur.execute(
                "INSERT INTO recipe_reviews (recipe_id, user_id, rating, comment) "
                "VALUES (%s, %s, %s, %s) RETURNING review_id",
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

@router.get("/leaderboard")
def get_leaderboard(limit: int = 50):
    conn = get_db_connection()
    try:
        cur = conn.cursor(cursor_factory=RealDictCursor)
        cur.execute("""
            SELECT u.user_id,
                   COALESCE(u.username, 'ผู้ใช้') AS username,
                   COALESCE(u.current_streak, 0)   AS current_streak,
                   COALESCE(u.total_login_days, 0)  AS total_login_days,
                   u.avatar_url,
                   COALESCE(g.tama_points, 0) AS tama_points,
                   COALESCE(g.tier_level, 0)  AS tier_level
            FROM cleangoal.users u
            LEFT JOIN cleangoal.user_gamification g ON g.user_id = u.user_id
            WHERE u.deleted_at IS NULL
              AND (u.current_streak > 0 OR u.total_login_days > 0 OR COALESCE(g.tama_points, 0) > 0)
            ORDER BY u.current_streak DESC, u.total_login_days DESC
            LIMIT %s
        """, (limit,))
        rows = cur.fetchall()
        result = []
        for i, row in enumerate(rows):
            entry = dict(row)
            entry['rank'] = i + 1
            result.append(entry)
        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        if conn:
            conn.close()
