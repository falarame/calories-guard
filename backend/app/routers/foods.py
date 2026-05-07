import json
import logging

from fastapi import APIRouter, HTTPException, Depends
from psycopg2.extras import RealDictCursor, Json

from database import get_db_connection
from auth.dependencies import get_current_admin
from app.models.schemas import FoodCreate, FoodAutoAdd, RegionalNameSubmission
from ai_models import llm_provider
from ai_models.prompts import RECIPE_SYSTEM_PROMPT as _RECIPE_SYSTEM_PROMPT

logger = logging.getLogger(__name__)
router = APIRouter()


def _parse_ai_recipe(raw: str) -> dict:
    """Best-effort JSON extraction — some LLMs wrap output in ```json fences."""
    text = raw.strip()
    if text.startswith("```"):
        text = text.strip("`")
        if text.lower().startswith("json"):
            text = text[4:]
    start = text.find("{")
    end = text.rfind("}")
    if start == -1 or end == -1:
        raise ValueError("LLM did not return JSON")
    return json.loads(text[start : end + 1])


@router.get("/foods")
def read_foods(user_id: int | None = None):
    conn = get_db_connection()
    try:
        cur = conn.cursor(cursor_factory=RealDictCursor)
        region = _resolve_user_region(cur, user_id) if user_id else None
        cur.execute("""
            SELECT f.*,
                   u.name AS serving_unit,
                   COALESCE(frn.name_th, f.food_name) AS display_name,
                   frn.name_th AS regional_name,
                   COALESCE(
                       array_agg(faf.flag_id) FILTER (WHERE faf.flag_id IS NOT NULL),
                       '{}'
                   ) AS allergy_flag_ids
            FROM foods f
            LEFT JOIN units u ON u.unit_id = f.serving_unit_id
            LEFT JOIN food_regional_names frn
                   ON frn.food_id = f.food_id
                  AND frn.region = %s::thai_region
                  AND frn.is_primary
                  AND frn.deleted_at IS NULL
            LEFT JOIN food_allergy_flags faf ON faf.food_id = f.food_id
            WHERE f.deleted_at IS NULL
            GROUP BY f.food_id, u.name, frn.name_th
            ORDER BY f.food_id ASC
        """, (region,))
        rows = cur.fetchall()
        result = []
        for row in rows:
            r = dict(row)
            r['allergy_flag_ids'] = list(r['allergy_flag_ids']) if r['allergy_flag_ids'] else []
            result.append(r)
        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        if conn:
            conn.close()


@router.post("/foods")
def create_food(food: FoodCreate, current_user: dict = Depends(get_current_admin)):
    conn = get_db_connection()
    try:
        cur = conn.cursor(cursor_factory=RealDictCursor)
        cur.execute("""
            INSERT INTO foods (food_name, calories, protein, carbs, fat, image_url)
            VALUES (%s, %s, %s, %s, %s, %s)
            RETURNING food_id
        """, (food.food_name, food.calories, food.protein, food.carbs, food.fat, food.image_url))
        new_id = cur.fetchone()['food_id']
        conn.commit()
        return {"message": "Food added", "food_id": new_id}
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        if conn:
            conn.close()


@router.post("/foods/auto-add")
def user_auto_add_food(req: FoodAutoAdd):
    conn = get_db_connection()
    try:
        cur = conn.cursor(cursor_factory=RealDictCursor)
        cur.execute(
            """
            INSERT INTO temp_food (food_name, calories, protein, carbs, fat, user_id)
            VALUES (%s, %s, %s, %s, %s, %s)
            RETURNING tf_id
            """,
            (req.food_name, req.calories or 0, req.protein or 0,
             req.carbs or 0, req.fat or 0, req.user_id),
        )
        new_tf_id = cur.fetchone()["tf_id"]
        conn.commit()
        return {"message": "บันทึกเมนูด่วนสำเร็จ รอ admin ตรวจสอบ", "tf_id": new_tf_id}
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        if conn:
            conn.close()


@router.get("/recommended-food")
def get_recommended_food(user_id: int | None = None):
    """Top-N foods, optionally annotated with the caller's regional display_name.

    `user_id` is optional; when set we resolve users.region and join the
    primary regional alias for that region so the caller can show
    "ข้าวปุ้น" instead of canonical "ขนมจีนน้ำยา" for an Isan user.
    Falls back to canonical food_name when no region is set or no alias exists.
    """
    conn = get_db_connection()
    try:
        cur = conn.cursor(cursor_factory=RealDictCursor)
        region = _resolve_user_region(cur, user_id) if user_id else None
        cur.execute(
            """
            SELECT f.*,
                   COALESCE(frn.name_th, f.food_name) AS display_name,
                   frn.name_th AS regional_name
            FROM foods f
            LEFT JOIN food_regional_names frn
                   ON frn.food_id = f.food_id
                  AND frn.region = %s::thai_region
                  AND frn.is_primary
                  AND frn.deleted_at IS NULL
            WHERE f.deleted_at IS NULL
            ORDER BY f.food_id ASC
            LIMIT 20
            """,
            (region,),
        )
        return cur.fetchall()
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        if conn:
            conn.close()


def _resolve_user_region(cur, user_id: int) -> str | None:
    """Look up users.region; return None if user has no preference set."""
    cur.execute(
        "SELECT region::text AS region FROM users "
        "WHERE user_id = %s AND deleted_at IS NULL",
        (user_id,),
    )
    row = cur.fetchone()
    return row["region"] if row else None


@router.get("/foods/search")
def search_foods(q: str = "", user_id: int | None = None, limit: int = 20):
    """Search foods by canonical name OR by any regional alias.

    Behaviour:
      - Matches `foods.food_name` (ILIKE) OR
        `food_regional_names.name_th` (ILIKE) — so Isan users typing
        "ข้าวปุ้น" hit the canonical "ขนมจีนน้ำยา" row.
      - Returns each food with `display_name` set to the caller's
        regional primary alias when available, else the canonical name.
      - Boosts results that match the user's region to the top.
    """
    q = (q or "").strip()
    if not q:
        return []
    pattern = f"%{q}%"
    conn = get_db_connection()
    try:
        cur = conn.cursor(cursor_factory=RealDictCursor)
        region = _resolve_user_region(cur, user_id) if user_id else None
        cur.execute(
            """
            SELECT f.*,
                   COALESCE(frn_user.name_th, f.food_name) AS display_name,
                   frn_user.name_th  AS regional_name,
                   CASE WHEN frn_match.region = %s::thai_region THEN 1 ELSE 0 END
                       AS match_user_region
            FROM foods f
            LEFT JOIN food_regional_names frn_user
                   ON frn_user.food_id = f.food_id
                  AND frn_user.region = %s::thai_region
                  AND frn_user.is_primary
                  AND frn_user.deleted_at IS NULL
            LEFT JOIN food_regional_names frn_match
                   ON frn_match.food_id = f.food_id
                  AND frn_match.deleted_at IS NULL
                  AND frn_match.name_th ILIKE %s
            WHERE f.deleted_at IS NULL
              AND (
                    f.food_name ILIKE %s
                 OR frn_match.variant_id IS NOT NULL
              )
            GROUP BY f.food_id, frn_user.name_th, frn_match.region
            ORDER BY match_user_region DESC, f.food_name ASC
            LIMIT %s
            """,
            (region, region, pattern, pattern, limit),
        )
        return cur.fetchall()
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        if conn:
            conn.close()


@router.get("/foods/{food_id}/regional-names")
def list_food_regional_names(food_id: int):
    """All approved regional aliases for a single food (read-only)."""
    conn = get_db_connection()
    try:
        cur = conn.cursor(cursor_factory=RealDictCursor)
        cur.execute(
            """
            SELECT variant_id, region::text AS region, name_th, is_primary,
                   created_at, updated_at
            FROM food_regional_names
            WHERE food_id = %s AND deleted_at IS NULL
            ORDER BY region, is_primary DESC, name_th
            """,
            (food_id,),
        )
        return cur.fetchall()
    finally:
        if conn:
            conn.close()


@router.post("/foods/{food_id}/regional-names")
def submit_regional_name(food_id: int, payload: RegionalNameSubmission):
    """User submits a regional alias for a food → goes to admin review queue."""
    name = payload.name_th.strip()
    if not name:
        raise HTTPException(status_code=400, detail="name_th ห้ามว่าง")
    if payload.popularity is not None and not (1 <= payload.popularity <= 5):
        raise HTTPException(status_code=400, detail="popularity ต้องอยู่ระหว่าง 1-5")
    conn = get_db_connection()
    try:
        cur = conn.cursor(cursor_factory=RealDictCursor)
        cur.execute("SELECT 1 FROM foods WHERE food_id = %s AND deleted_at IS NULL", (food_id,))
        if not cur.fetchone():
            raise HTTPException(status_code=404, detail="ไม่พบเมนูนี้")
        cur.execute(
            """
            INSERT INTO food_regional_name_submissions
                (food_id, region, name_th, popularity, user_id)
            VALUES (%s, %s::thai_region, %s, %s, %s)
            RETURNING submission_id
            """,
            (food_id, payload.region.value, name, payload.popularity, payload.user_id),
        )
        new_id = cur.fetchone()["submission_id"]
        conn.commit()
        return {
            "message": "ส่งชื่อท้องถิ่นเรียบร้อย รอ admin ตรวจสอบ",
            "submission_id": new_id,
        }
    except HTTPException:
        raise
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        if conn:
            conn.close()


def _shape_recipe_response(
    row: dict,
    rel_steps: list | None = None,
    rel_ingredients: list | None = None,
    rel_tools: list | None = None,
    rel_tips: list | None = None,
    rel_reviews: list | None = None,
) -> dict:
    """Flatten DB row into the shape RecipeDetailScreen consumes."""
    # ── Steps ──
    if rel_steps:
        steps = [dict(s) for s in rel_steps]
    else:
        instructions = (row.get("instructions") or "").strip()
        instructions = instructions.replace("\\n", "\n")
        raw = [s.strip() for s in instructions.split("\n") if s.strip()]
        steps = [
            {
                "step_number": idx + 1,
                "title": f"ขั้นตอนที่ {idx + 1}",
                "instruction": s,
                "time_minutes": 0,
                "tips": "",
                "image_url": "",
            }
            for idx, s in enumerate(raw)
        ]

    # ── Ingredients ──
    if rel_ingredients:
        ingredients = [dict(i) for i in rel_ingredients]
    else:
        ingredients = []
        for ing in (row.get("ingredients_json") or []):
            if isinstance(ing, dict):
                ingredients.append({
                    "ingredient_name": ing.get("ingredient_name") or ing.get("name") or "",
                    "quantity": ing.get("quantity") or ing.get("amount"),
                    "unit": ing.get("unit") or "",
                    "is_optional": ing.get("is_optional", False),
                    "note": ing.get("note") or "",
                })

    # ── Tools ──
    if rel_tools:
        tools = [dict(t) for t in rel_tools]
    else:
        tools = []
        for t in (row.get("tools_json") or []):
            if isinstance(t, str):
                tools.append({"tool_name": t, "tool_emoji": "🔧"})
            elif isinstance(t, dict):
                tools.append({
                    "tool_name": t.get("tool_name") or t.get("name") or "",
                    "tool_emoji": t.get("tool_emoji") or "🔧",
                })

    # ── Tips ──
    if rel_tips:
        tips = [dict(t) for t in rel_tips]
    else:
        tips = []
        for tip in (row.get("tips_json") or []):
            if isinstance(tip, str):
                tips.append({"tip_text": tip})
            elif isinstance(tip, dict):
                tips.append({"tip_text": tip.get("tip_text") or tip.get("text") or ""})

    # ── Reviews ──
    reviews = []
    for rv in (rel_reviews or []):
        r = dict(rv)
        if r.get("created_at") and hasattr(r["created_at"], "isoformat"):
            r["created_at"] = r["created_at"].isoformat()
        reviews.append(r)

    return {
        **row,
        "ingredients": ingredients,
        "tools": tools,
        "tips": tips,
        "steps": steps,
        "reviews": reviews,
    }


@router.get("/recipes/{food_id}")
def get_recipe(food_id: int, user_id: int | None = None):
    """Return a recipe for the given food_id.

    If no recipe row exists yet, lazily generate one via the LLM and cache
    it into `recipes`. This trades the first viewer's latency (one LLM
    call, ~2-4 s) for a populated catalogue over time — no admin seeding
    required.
    """
    conn = get_db_connection()
    try:
        cur = conn.cursor(cursor_factory=RealDictCursor)
        region = _resolve_user_region(cur, user_id) if user_id else None
        cur.execute(
            """
            SELECT r.*, f.food_name, f.calories, f.protein, f.carbs, f.fat,
                   COALESCE(frn.name_th, f.food_name) AS display_name,
                   frn.name_th AS regional_name,
                   f.image_url as food_image_url
            FROM recipes r
            JOIN foods f ON r.food_id = f.food_id
            LEFT JOIN food_regional_names frn
                   ON frn.food_id = f.food_id
                  AND frn.region = %s::thai_region
                  AND frn.is_primary
                  AND frn.deleted_at IS NULL
            WHERE r.food_id = %s AND r.deleted_at IS NULL AND f.deleted_at IS NULL
            """,
            (region, food_id),
        )
        row = cur.fetchone()
        if row:
            recipe_id = row["recipe_id"]
            cur.execute(
                "SELECT step_number, title, instruction, time_minutes, tips, image_url "
                "FROM recipe_steps WHERE recipe_id = %s ORDER BY step_number",
                (recipe_id,),
            )
            rel_steps = cur.fetchall() or None
            cur.execute(
                """
                SELECT
                    ingredient_name, quantity, unit, is_optional, note,
                    food_ing_id, ingredient_id, calculated_grams,
                    calculated_calories, calculated_protein,
                    calculated_carbs, calculated_fat
                FROM cleangoal.v_recipe_ingredients_nutrition
                WHERE recipe_id = %s
                ORDER BY sort_order
                """,
                (recipe_id,),
            )
            rel_ingredients = cur.fetchall() or None
            cur.execute(
                "SELECT tool_name, tool_emoji FROM recipe_tools WHERE recipe_id = %s ORDER BY sort_order",
                (recipe_id,),
            )
            rel_tools = cur.fetchall() or None
            cur.execute(
                "SELECT tip_text FROM recipe_tips WHERE recipe_id = %s ORDER BY sort_order",
                (recipe_id,),
            )
            rel_tips = cur.fetchall() or None
            cur.execute(
                """
                SELECT rr.review_id, rr.user_id, u.username, rr.rating, rr.comment, rr.created_at
                FROM recipe_reviews rr
                JOIN users u ON u.user_id = rr.user_id
                WHERE rr.recipe_id = %s ORDER BY rr.created_at DESC
                """,
                (recipe_id,),
            )
            rel_reviews = cur.fetchall()
            return _shape_recipe_response(
                row,
                rel_steps=rel_steps,
                rel_ingredients=rel_ingredients,
                rel_tools=rel_tools,
                rel_tips=rel_tips,
                rel_reviews=rel_reviews,
            )

        # No recipe yet — fetch food metadata and ask the LLM.
        cur.execute(
            "SELECT food_id, food_name, calories, protein, carbs, fat, image_url "
            "FROM foods WHERE food_id = %s AND deleted_at IS NULL",
            (food_id,),
        )
        food = cur.fetchone()
        if not food:
            raise HTTPException(status_code=404, detail="Food not found")

        if not llm_provider.is_configured():
            raise HTTPException(
                status_code=503,
                detail="LLM is not configured — recipe cannot be generated",
            )

        try:
            raw = llm_provider.generate(
                _RECIPE_SYSTEM_PROMPT,
                f"ชื่อเมนู: {food['food_name']}",
            )
            ai = _parse_ai_recipe(raw)
        except Exception as e:
            logger.warning("recipe LLM generation failed for food_id=%s: %s", food_id, e)
            raise HTTPException(
                status_code=502,
                detail="ไม่สามารถสร้างสูตรอาหารได้ในตอนนี้ กรุณาลองใหม่",
            )

        cur.execute(
            """
            INSERT INTO recipes (
                food_id, description, instructions,
                prep_time_minutes, cooking_time_minutes, serving_people,
                ingredients_json, tools_json, tips_json, generated_by
            ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, 'ai')
            ON CONFLICT (food_id) DO UPDATE SET
                description = EXCLUDED.description,
                instructions = EXCLUDED.instructions,
                prep_time_minutes = EXCLUDED.prep_time_minutes,
                cooking_time_minutes = EXCLUDED.cooking_time_minutes,
                serving_people = EXCLUDED.serving_people,
                ingredients_json = EXCLUDED.ingredients_json,
                tools_json = EXCLUDED.tools_json,
                tips_json = EXCLUDED.tips_json,
                generated_by = 'ai'
            RETURNING *
            """,
            (
                food_id,
                ai.get("description") or "",
                ai.get("instructions") or "",
                int(ai.get("prep_time_minutes") or 0),
                int(ai.get("cooking_time_minutes") or 0),
                float(ai.get("serving_people") or 1),
                Json(ai.get("ingredients") or []),
                Json(ai.get("tools") or []),
                Json(ai.get("tips") or []),
            ),
        )
        new_row = cur.fetchone()
        conn.commit()

        merged = {
            **dict(new_row),
            "food_name": food["food_name"],
            "display_name": food["food_name"],
            "regional_name": None,
            "calories": food["calories"],
            "protein": food["protein"],
            "carbs": food["carbs"],
            "fat": food["fat"],
            "food_image_url": food["image_url"],
        }
        return _shape_recipe_response(merged)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        if conn:
            conn.close()


@router.put("/foods/{food_id}")
def update_food(food_id: int, food: FoodCreate, current_user: dict = Depends(get_current_admin)):
    conn = get_db_connection()
    try:
        cur = conn.cursor(cursor_factory=RealDictCursor)
        cur.execute("""
            UPDATE foods
            SET food_name = %s, calories = %s, protein = %s,
                carbs = %s, fat = %s, image_url = %s
            WHERE food_id = %s AND deleted_at IS NULL
        """, (food.food_name, food.calories, food.protein, food.carbs, food.fat, food.image_url, food_id))
        if cur.rowcount == 0:
            raise HTTPException(status_code=404, detail="ไม่พบเมนูนี้")
        conn.commit()
        return {"message": "Food updated successfully"}
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        if conn:
            conn.close()


@router.patch("/foods/{food_id}")
def patch_food(food_id: int, data: dict, current_user: dict = Depends(get_current_admin)):
    """Partial update — อัปเดตเฉพาะ field ที่ส่งมา (admin only)"""
    allowed = {"food_name", "calories", "protein", "carbs", "fat", "image_url"}
    fields = {k: v for k, v in data.items() if k in allowed}
    if not fields:
        raise HTTPException(status_code=400, detail="ไม่มี field ที่อัปเดตได้")
    conn = get_db_connection()
    try:
        cur = conn.cursor()
        set_clause = ", ".join(f"{k} = %s" for k in fields)
        cur.execute(
            f"UPDATE foods SET {set_clause} WHERE food_id = %s AND deleted_at IS NULL RETURNING food_id",
            [*fields.values(), food_id],
        )
        if not cur.fetchone():
            raise HTTPException(status_code=404, detail="ไม่พบเมนูนี้")
        conn.commit()
        return {"message": "อัปเดตสำเร็จ", "food_id": food_id}
    except HTTPException:
        raise
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        if conn:
            conn.close()


@router.delete("/foods/{food_id}/hard")
def hard_delete_food(food_id: int, current_user: dict = Depends(get_current_admin)):
    """Hard-delete a food and ALL related records permanently (admin only)."""
    conn = get_db_connection()
    try:
        cur = conn.cursor()
        # ตรวจว่ามี food นี้อยู่
        cur.execute("SELECT 1 FROM foods WHERE food_id = %s", (food_id,))
        if not cur.fetchone():
            raise HTTPException(status_code=404, detail="ไม่พบเมนูนี้")

        # 1. ลบ recipe children ก่อน
        cur.execute(
            """
            DELETE FROM recipe_reviews
             WHERE recipe_id IN (SELECT recipe_id FROM recipes WHERE food_id = %s)
            """, (food_id,))
        cur.execute(
            """
            DELETE FROM recipe_favorites
             WHERE recipe_id IN (SELECT recipe_id FROM recipes WHERE food_id = %s)
            """, (food_id,))
        cur.execute(
            """
            DELETE FROM recipe_ingredients
             WHERE recipe_id IN (SELECT recipe_id FROM recipes WHERE food_id = %s)
            """, (food_id,))
        cur.execute(
            """
            DELETE FROM recipe_steps
             WHERE recipe_id IN (SELECT recipe_id FROM recipes WHERE food_id = %s)
            """, (food_id,))
        cur.execute(
            """
            DELETE FROM recipe_tips
             WHERE recipe_id IN (SELECT recipe_id FROM recipes WHERE food_id = %s)
            """, (food_id,))
        cur.execute(
            """
            DELETE FROM recipe_tools
             WHERE recipe_id IN (SELECT recipe_id FROM recipes WHERE food_id = %s)
            """, (food_id,))

        # 2. ลบ recipes
        cur.execute("DELETE FROM recipes WHERE food_id = %s", (food_id,))

        # 3. ลบ food-related tables
        cur.execute("DELETE FROM food_allergy_flags WHERE food_id = %s", (food_id,))
        cur.execute("DELETE FROM food_regional_names WHERE food_id = %s", (food_id,))
        cur.execute("DELETE FROM food_regional_name_submissions WHERE food_id = %s", (food_id,))
        cur.execute("DELETE FROM food_regional_popularity WHERE food_id = %s", (food_id,))
        cur.execute("DELETE FROM beverages WHERE food_id = %s", (food_id,))
        cur.execute("DELETE FROM snacks WHERE food_id = %s", (food_id,))
        cur.execute("DELETE FROM user_favorites WHERE food_id = %s", (food_id,))
        cur.execute("DELETE FROM detail_items WHERE food_id = %s", (food_id,))

        # 4. ลบ food ตัวเอง
        cur.execute("DELETE FROM foods WHERE food_id = %s", (food_id,))

        conn.commit()
        return {"message": f"ลบเมนู food_id={food_id} และข้อมูลที่เกี่ยวข้องทั้งหมดออกจากระบบแล้ว"}
    except HTTPException:
        raise
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        if conn:
            conn.close()


@router.delete("/foods/{food_id}")
def delete_food(food_id: int, current_user: dict = Depends(get_current_admin)):
    """Soft-delete a food from the active catalogue (admin only)."""
    conn = get_db_connection()
    try:
        cur = conn.cursor()
        cur.execute(
            """
            UPDATE foods
               SET deleted_at = COALESCE(deleted_at, NOW()),
                   updated_at = NOW()
             WHERE food_id = %s
               AND deleted_at IS NULL
             RETURNING food_id
            """,
            (food_id,),
        )
        if not cur.fetchone():
            raise HTTPException(status_code=404, detail="ไม่พบเมนูนี้")
        conn.commit()
        return {"message": "ลบเมนูเรียบร้อย", "food_id": food_id}
    except HTTPException:
        raise
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        if conn:
            conn.close()
