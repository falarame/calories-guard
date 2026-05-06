"""F1 score for food extraction.

Compare the set of food names predicted by ai_models.food_extraction.extract_foods
against the hand-labeled expected set. Names are normalized (strip + lowercase)
before set comparison.
"""
from __future__ import annotations

from typing import Iterable


def _normalize(name: str) -> str:
    return (name or "").strip().lower()


def precision_recall_f1(
    predicted: Iterable[str],
    expected: Iterable[str],
) -> tuple[float, float, float]:
    pred = {_normalize(n) for n in predicted if n}
    truth = {_normalize(n) for n in expected if n}
    if not pred and not truth:
        return 1.0, 1.0, 1.0
    if not pred:
        return 0.0, 0.0, 0.0
    tp = len(pred & truth)
    p = tp / max(1, len(pred))
    r = tp / max(1, len(truth))
    f1 = (2 * p * r) / (p + r) if (p + r) > 0 else 0.0
    return p, r, f1


def average_f1(rows: list[dict]) -> dict:
    """rows: [{"predicted": [...], "expected": [...]}, ...] → averages."""
    if not rows:
        return {"precision": 0.0, "recall": 0.0, "f1": 0.0, "n": 0}
    ps, rs, fs = [], [], []
    for row in rows:
        p, r, f = precision_recall_f1(row["predicted"], row["expected"])
        ps.append(p); rs.append(r); fs.append(f)
    return {
        "precision": sum(ps) / len(ps),
        "recall": sum(rs) / len(rs),
        "f1": sum(fs) / len(fs),
        "n": len(rows),
    }
