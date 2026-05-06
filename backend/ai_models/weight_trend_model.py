"""
Linear-regression weight trend over the recent N days.

Slope is reported in kg/week (more interpretable than per-day) and bucketed
into trend labels for the coach prompt.
"""
from __future__ import annotations

from datetime import date, datetime
from typing import Iterable

import numpy as np
from sklearn.linear_model import LinearRegression

_MIN_POINTS = 3                   # below this we can't trust the slope
_STABLE_THRESHOLD_KG_PER_WEEK = 0.1  # |slope| under this = "คงที่"


def _to_ordinal(value) -> int:
    if isinstance(value, datetime):
        return value.toordinal()
    if isinstance(value, date):
        return value.toordinal()
    if isinstance(value, str):
        return datetime.fromisoformat(value).toordinal()
    raise TypeError(f"Unsupported date type: {type(value).__name__}")


def analyze_trend(weight_logs: Iterable[dict], target_weight: float) -> dict:
    """Fit a line through (date, weight) and return trend metadata.

    Args:
        weight_logs: chronological list of {"date": <date|str>, "weight": <float>}
        target_weight: user's target weight in kg (0 if unset)

    Returns:
        {
          "trend": "เพิ่ม" | "ลด" | "คงที่" | "unknown",
          "slope_per_week": float,
          "current": float | None,
          "target": float,
          "message": str,
        }
    """
    points = list(weight_logs or [])
    if len(points) < _MIN_POINTS:
        return {
            "trend": "unknown",
            "slope_per_week": 0.0,
            "current": float(points[-1]["weight"]) if points else None,
            "target": float(target_weight or 0),
            "message": "ข้อมูลน้ำหนักยังน้อยเกินไป กรุณาบันทึกอย่างน้อย 3 วัน",
        }

    xs = np.array([_to_ordinal(p["date"]) for p in points], dtype=float).reshape(-1, 1)
    ys = np.array([float(p["weight"]) for p in points], dtype=float)
    model = LinearRegression().fit(xs, ys)
    slope_per_day = float(model.coef_[0])
    slope_per_week = round(slope_per_day * 7.0, 3)

    if abs(slope_per_week) < _STABLE_THRESHOLD_KG_PER_WEEK:
        trend = "คงที่"
    elif slope_per_week > 0:
        trend = "เพิ่ม"
    else:
        trend = "ลด"

    current = float(points[-1]["weight"])
    target_value = float(target_weight or 0)

    if target_value <= 0:
        message = f"แนวโน้ม{trend} ({slope_per_week:+.2f} kg/สัปดาห์)"
    else:
        diff = current - target_value
        direction = "เกิน" if diff > 0 else "ต่ำกว่า"
        message = (
            f"แนวโน้ม{trend} ({slope_per_week:+.2f} kg/สัปดาห์) — "
            f"ตอนนี้{direction}เป้าหมาย {abs(diff):.1f} kg"
        )

    return {
        "trend": trend,
        "slope_per_week": slope_per_week,
        "current": current,
        "target": target_value,
        "message": message,
    }
