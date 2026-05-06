"""
Pure-Python nutrition gap analysis. No pandas — `collections.Counter` and
plain dict comprehensions are fast enough for 7-day windows and avoid an
import that wasn't needed.
"""
from __future__ import annotations

from collections import Counter
from typing import Iterable

_MACROS: tuple[tuple[str, str], ...] = (
    ("protein", "โปรตีน"),
    ("carbs", "คาร์บ"),
    ("fat", "ไขมัน"),
    ("calories", "พลังงาน"),
)

_GAP_THRESHOLD_PCT = 20.0  # ±20 % from target = flag as critical


def _avg(logs: list[dict], key: str) -> float:
    if not logs:
        return 0.0
    return sum(float(d.get(key, 0) or 0) for d in logs) / len(logs)


def analyze_nutrition_gap(target: dict, recent_logs: list[dict]) -> dict:
    """Compare recent macro intake against the user's daily targets.

    Args:
        target:  dict with keys target_calories, target_protein, target_carbs, target_fat
        recent_logs: list of per-day dicts with keys calories/protein/carbs/fat

    Returns:
        {
          "status": "no_data" | "balanced" | "deficit" | "surplus" | "mixed",
          "message": str,
          "critical_issues": list[str],
          "averages": dict[str, float],
        }
    """
    if not recent_logs:
        return {
            "status": "no_data",
            "message": "ยังไม่มีข้อมูลโภชนาการในระบบ",
            "critical_issues": [],
            "averages": {k: 0.0 for k, _ in _MACROS},
        }

    averages = {macro: round(_avg(recent_logs, macro), 1) for macro, _ in _MACROS}
    issues: list[str] = []
    has_deficit = False
    has_surplus = False

    for macro, label in _MACROS:
        target_value = float(target.get(f"target_{macro}", 0) or 0)
        if target_value <= 0:
            continue
        actual = averages[macro]
        gap_pct = (actual - target_value) / target_value * 100.0
        if gap_pct < -_GAP_THRESHOLD_PCT:
            issues.append(f"{label}ต่ำกว่าเป้า {abs(int(gap_pct))}%")
            has_deficit = True
        elif gap_pct > _GAP_THRESHOLD_PCT:
            issues.append(f"{label}เกินเป้า {int(gap_pct)}%")
            has_surplus = True

    if not issues:
        status = "balanced"
        message = "โภชนาการสมดุลดี"
    elif has_deficit and has_surplus:
        status = "mixed"
        message = "; ".join(issues)
    elif has_deficit:
        status = "deficit"
        message = "; ".join(issues)
    else:
        status = "surplus"
        message = "; ".join(issues)

    return {
        "status": status,
        "message": message,
        "critical_issues": issues,
        "averages": averages,
    }


def find_frequent_foods(recent_foods: Iterable[dict], top_n: int = 5) -> list[dict]:
    """Top-N most-eaten foods over the recent_foods window."""
    counter: Counter[str] = Counter()
    for row in recent_foods:
        name = (row.get("food_name") or "").strip()
        if name:
            counter[name] += 1
    return [{"food_name": name, "count": count} for name, count in counter.most_common(top_n)]
