"""
Single-shot coach pipeline:
  scope guard → fetch user context → ML insights → prompt → Ollama
"""
from __future__ import annotations

import logging
from typing import Any, Optional

from psycopg2.extras import RealDictCursor

from database import get_db_connection

from ai_models import llm_provider
from ai_models.food_analyzer import analyze_nutrition_gap, find_frequent_foods
from ai_models.prompts import COACH_SYSTEM_PROMPT
from ai_models.scope_guard import REJECT_MSG, is_in_scope
from ai_models.weight_trend_model import analyze_trend

logger = logging.getLogger(__name__)


class CoachAgent:
    """Stateless — safe to instantiate once at import time and reuse."""

    def fetch_user_context(self, user_id: int) -> Optional[dict[str, Any]]:
        conn = get_db_connection()
        if not conn:
            return None
        try:
            cur = conn.cursor(cursor_factory=RealDictCursor)
            cur.execute(
                """
                SELECT username, gender, birth_date, height_cm, current_weight_kg,
                       goal_type, target_weight_kg, target_calories,
                       target_protein, target_carbs, target_fat, activity_level
                FROM users WHERE user_id = %s
                """,
                (user_id,),
            )
            profile = cur.fetchone()
            if not profile:
                return None

            cur.execute(
                """
                SELECT recorded_date AS date, weight_kg AS weight
                FROM weight_logs
                WHERE user_id = %s
                ORDER BY recorded_date DESC LIMIT 30
                """,
                (user_id,),
            )
            weight_logs = cur.fetchall()

            cur.execute(
                """
                SELECT date_record AS date,
                       total_calories_intake AS calories,
                       total_protein AS protein,
                       total_carbs   AS carbs,
                       total_fat     AS fat
                FROM daily_summaries
                WHERE user_id = %s
                ORDER BY date_record DESC LIMIT 7
                """,
                (user_id,),
            )
            daily_summaries = cur.fetchall()

            cur.execute(
                """
                SELECT d.food_name, d.amount, d.cal_per_unit, d.created_at
                FROM detail_items d
                JOIN meals m ON d.meal_id = m.meal_id
                WHERE m.user_id = %s
                  AND m.created_at >= NOW() - INTERVAL '3 days'
                """,
                (user_id,),
            )
            recent_foods = cur.fetchall()

            try:
                cur.execute(
                    """
                    SELECT f.name FROM user_allergy_preferences uap
                    JOIN allergy_flags f ON uap.flag_id = f.flag_id
                    WHERE uap.user_id = %s
                    """,
                    (user_id,),
                )
                allergies = [r["name"] for r in cur.fetchall()]
            except Exception:
                allergies = []

            return {
                "profile": dict(profile),
                "weight_logs": [dict(w) for w in weight_logs],
                "daily_summaries": [dict(d) for d in daily_summaries],
                "recent_foods": [dict(f) for f in recent_foods],
                "allergies": allergies,
            }
        finally:
            conn.close()

    def generate_response(self, user_id: int, user_message: str) -> str:
        if not is_in_scope(user_message):
            return REJECT_MSG

        context = self.fetch_user_context(user_id)
        if not context:
            return "ขออภัยครับ ไม่พบข้อมูลโปรไฟล์ของคุณในระบบ"

        profile = context["profile"]

        weight_trend = analyze_trend(
            weight_logs=list(reversed(context["weight_logs"])),
            target_weight=float(profile.get("target_weight_kg") or 0),
        )

        target = {
            "target_calories": profile.get("target_calories") or 2000,
            "target_protein": profile.get("target_protein") or 150,
            "target_carbs": profile.get("target_carbs") or 200,
            "target_fat": profile.get("target_fat") or 60,
        }
        nutrition = analyze_nutrition_gap(target, context["daily_summaries"])
        frequent = find_frequent_foods(context["recent_foods"])

        system_prompt = COACH_SYSTEM_PROMPT.format(
            goal_type=profile.get("goal_type") or "ไม่ระบุ",
            target_weight_kg=profile.get("target_weight_kg") or "-",
            current_weight_kg=profile.get("current_weight_kg") or "-",
            height_cm=profile.get("height_cm") or "-",
            target_calories=target["target_calories"],
            target_protein=target["target_protein"],
            target_carbs=target["target_carbs"],
            target_fat=target["target_fat"],
            allergies=", ".join(context["allergies"]) or "ไม่มี",
            weight_trend_message=weight_trend["message"],
            nutrition_message=nutrition["message"],
            critical_issues=", ".join(nutrition["critical_issues"]) or "ไม่มี",
            frequent_foods=", ".join(f["food_name"] for f in frequent) or "ไม่มี",
        )

        if not llm_provider.is_configured():
            return (
                "[System: LLM provider not configured. Mock Response]\n"
                f"แนวโน้ม{weight_trend['trend']} — {nutrition['message']}"
            )

        try:
            return llm_provider.generate(
                system_prompt,
                f"ผู้ใช้ถามว่า: {user_message}",
            )
        except llm_provider.LLMTimeout:
            return "ขออภัยครับ ระบบ AI ตอบช้าเกินไป กรุณาลองใหม่อีกครั้ง"
        except llm_provider.LLMUnavailable as e:
            logger.warning("Ollama unavailable: %s", e)
            return "ขออภัยครับ ระบบ AI ใช้ไม่ได้ชั่วคราว กรุณาลองใหม่ในอีกสักครู่"
        except llm_provider.LLMError as e:
            logger.error("LLM error: %s", e)
            return "ขออภัยครับ ระบบ AI มีปัญหาในการประมวลผล"
