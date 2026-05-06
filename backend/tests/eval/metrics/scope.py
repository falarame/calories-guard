"""Precision + recall for the scope guard binary classifier."""
from __future__ import annotations


def confusion(rows: list[dict]) -> dict:
    """rows: [{"predicted_in_scope": bool, "expected_in_scope": bool}, ...]"""
    tp = fp = tn = fn = 0
    for r in rows:
        pred = bool(r["predicted_in_scope"])
        truth = bool(r["expected_in_scope"])
        if pred and truth:
            tp += 1
        elif pred and not truth:
            fp += 1
        elif not pred and not truth:
            tn += 1
        else:
            fn += 1
    in_p = tp / max(1, tp + fp)
    in_r = tp / max(1, tp + fn)
    out_p = tn / max(1, tn + fn)
    out_r = tn / max(1, tn + fp)
    return {
        "n": len(rows),
        "in_scope": {"precision": in_p, "recall": in_r, "tp": tp, "fp": fp, "fn": fn},
        "out_of_scope": {"precision": out_p, "recall": out_r, "tn": tn, "fn": fn, "fp": fp},
        "min_p": min(in_p, out_p),
        "min_r": min(in_r, out_r),
    }
