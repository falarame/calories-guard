"""MAPE (mean absolute percentage error) for meal estimate macros.

For each (predicted, expected) pair across calories/protein/carbs/fat,
compute |pred-truth|/max(truth,1) * 100, then average. Lower is better.
"""
from __future__ import annotations


_MACROS = ("calories", "protein", "carbs", "fat")


def mape_one(predicted: dict, expected: dict) -> dict:
    """Returns per-macro percent errors and the mean across macros."""
    out = {}
    errs = []
    for k in _MACROS:
        truth = float(expected.get(k, 0) or 0)
        pred = float(predicted.get(k, 0) or 0)
        denom = max(abs(truth), 1.0)
        err = abs(pred - truth) / denom * 100.0
        out[k] = err
        errs.append(err)
    out["mean"] = sum(errs) / len(errs)
    return out


def aggregate_mape(rows: list[dict]) -> dict:
    """rows: [{"predicted": {...}, "expected": {...}}, ...]"""
    if not rows:
        return {"mape_mean": 0.0, "n": 0, "by_macro": {k: 0.0 for k in _MACROS}}
    by_macro = {k: [] for k in _MACROS}
    means = []
    for row in rows:
        m = mape_one(row["predicted"], row["expected"])
        for k in _MACROS:
            by_macro[k].append(m[k])
        means.append(m["mean"])
    return {
        "mape_mean": sum(means) / len(means),
        "n": len(rows),
        "by_macro": {k: sum(v) / len(v) for k, v in by_macro.items()},
    }
