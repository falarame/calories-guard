"""
NutritionAnalysisAgent — extracts foods from Thai text, sums macros from DB,
falls back to LLM JSON estimates for unknown dishes (auto-saved to temp_food
for admin review).

Used by:
- POST /api/meals/estimate (single-call meal parsing for the Flutter
  ai_meal_estimate_sheet)
"""
from __future__ import annotations

import logging
from typing import Any, Optional

from psycopg2.extras import RealDictCursor

from database import get_db_connection

from ai_models import llm_provider
from ai_models.food_extraction import extract_foods
from ai_models.prompts import MEAL_ESTIMATE_SYSTEM_PROMPT

logger = logging.getLogger(__name__)


class NutritionAnalysisAgent:
    def _extract_foods(self, msg: str) -> list[dict[str, Any]]:
        return extract_foods(msg)

    def _lookup_macros(self, food_id: int) -> Optional[dict[str, float]]:
        conn = get_db_connection()
        if not conn:
            return None
        try:
            cur = conn.cursor(cursor_factory=RealDictCursor)
            cur.execute(
                "SELECT calories, protein, carbs, fat FROM foods WHERE food_id = %s",
                (food_id,),
            )
            row = cur.fetchone()
            if not row:
                return None
            return {
                "calories": float(row["calories"] or 0),
                "protein": float(row["protein"] or 0),
                "carbs":   float(row["carbs"] or 0),
                "fat":     float(row["fat"] or 0),
            }
        finally:
            conn.close()

    def _estimate_with_llm(self, name: str) -> Optional[dict[str, Any]]:
        if not llm_provider.is_configured():
            return None
        try:
            return llm_provider.generate_json(
                MEAL_ESTIMATE_SYSTEM_PROMPT,
                f"ชื่ออาหาร: {name}",
            )
        except llm_provider.LLMError as e:
            logger.warning("LLM estimate failed for %s: %s", name, e)
            return None

    def _auto_add_temp_food(self, user_id: int, name: str, est: dict[str, Any]) -> None:
        conn = get_db_connection()
        if not conn:
            return
        try:
            cur = conn.cursor()
            cur.execute(
                """
                INSERT INTO temp_food
                    (food_name, calories, protein, carbs, fat, user_id, updated_at)
                VALUES (%s, %s, %s, %s, %s, %s, NOW())
                """,
                (
                    name,
                    float(est.get("calories") or 0),
                    float(est.get("protein") or 0),
                    float(est.get("carbs") or 0),
                    float(est.get("fat") or 0),
                    user_id,
                ),
            )
            conn.commit()
        except Exception as e:
            logger.warning("temp_food insert failed for %s: %s", name, e)
        finally:
            conn.close()

    def _analyze_foods(
        self,
        mentions: list[dict[str, Any]],
        _restaurants: list[Any],
        user_id: int,
    ) -> dict[str, Any]:
        items: list[dict[str, Any]] = []
        total = {"calories": 0.0, "protein": 0.0, "carbs": 0.0, "fat": 0.0}
        allergy_warnings: list[str] = []

        for mention in mentions:
            macros = self._lookup_macros(mention["food_id"]) if mention["food_id"] else None
            source = "db"
            if macros is None:
                est = self._estimate_with_llm(mention["name"])
                if est:
                    macros = {
                        "calories": float(est.get("calories") or 0),
                        "protein": float(est.get("protein") or 0),
                        "carbs":   float(est.get("carbs") or 0),
                        "fat":     float(est.get("fat") or 0),
                    }
                    source = "llm"
                    self._auto_add_temp_food(user_id, mention["name"], est)
                else:
                    macros = {"calories": 0, "protein": 0, "carbs": 0, "fat": 0}
                    source = "unknown"

            qty = float(mention.get("quantity") or 1.0)
            entry = {
                "name": mention["name"],
                "qty": qty,
                "unit": mention.get("unit") or "",
                "food_id": mention.get("food_id"),
                "calories": round(macros["calories"] * qty, 1),
                "protein":  round(macros["protein"]  * qty, 1),
                "carbs":    round(macros["carbs"]    * qty, 1),
                "fat":      round(macros["fat"]      * qty, 1),
                "source": source,
            }
            for k in ("calories", "protein", "carbs", "fat"):
                total[k] += entry[k]
            items.append(entry)

        return {
            "items": items,
            "total": {k: round(v, 1) for k, v in total.items()},
            "allergy_warnings": allergy_warnings,
        }
