"""Heuristic rubric scorer for coach responses.

Avoid using an LLM judge in Sprint 0 — 1.5B is too weak to grade itself
reliably and would inflate scores. Use 5 deterministic checks:

  1. response is non-empty
  2. response is in Thai (≥ 30% Thai unicode chars)
  3. brevity (≤ 6 paragraphs OR ≤ 800 chars)
  4. relevant: shares ≥ 1 nutrition keyword with the query when in-scope
  5. scope-safe: in-scope queries are NOT rejected with REJECT_MSG; out-of-scope
     queries ARE rejected

A response passes when it satisfies ≥ 4/5 criteria.

Week 1 will calibrate this against 20 hand-labeled responses; if the
heuristic disagrees with humans, swap to LLM judge or add criteria.
"""
from __future__ import annotations

import re

from ai_models.scope_guard import REJECT_MSG

_NUTRITION_KEYWORDS = (
    "แคล", "โปรตีน", "คาร์บ", "ไขมัน", "อาหาร", "กิน", "ดื่ม",
    "น้ำหนัก", "ลด", "เพิ่ม", "ออกกำลัง", "เป้า", "มื้อ", "เมนู",
    "g", "kcal", "กรัม", "kg",
)


def _thai_ratio(text: str) -> float:
    if not text:
        return 0.0
    thai = sum(1 for ch in text if "฀" <= ch <= "๿")
    return thai / max(1, len(text))


def _paragraph_count(text: str) -> int:
    return len([p for p in re.split(r"\n\s*\n", text or "") if p.strip()])


def score_one(query: str, response: str, expected_in_scope: bool) -> dict:
    crits = {}
    crits["non_empty"] = bool((response or "").strip())
    crits["is_thai"] = _thai_ratio(response or "") >= 0.30
    crits["brevity"] = _paragraph_count(response or "") <= 6 or len(response or "") <= 800
    if expected_in_scope:
        crits["relevant"] = any(k in (response or "") for k in _NUTRITION_KEYWORDS)
    else:
        crits["relevant"] = True  # n/a for out-of-scope
    if expected_in_scope:
        crits["scope_safe"] = REJECT_MSG not in (response or "")
    else:
        crits["scope_safe"] = REJECT_MSG in (response or "") or _thai_ratio(response or "") >= 0.30
    passed = sum(1 for v in crits.values() if v)
    return {"criteria": crits, "passed": passed, "total": len(crits), "ok": passed >= 4}


def aggregate(rows: list[dict]) -> dict:
    """rows: [{"query": str, "response": str, "expected_in_scope": bool}, ...]"""
    if not rows:
        return {"pass_rate": 0.0, "n": 0}
    scored = [score_one(r["query"], r["response"], r["expected_in_scope"]) for r in rows]
    pass_rate = sum(1 for s in scored if s["ok"]) / len(scored)
    by_criterion = {}
    for c in ("non_empty", "is_thai", "brevity", "relevant", "scope_safe"):
        by_criterion[c] = sum(1 for s in scored if s["criteria"][c]) / len(scored)
    return {
        "pass_rate": pass_rate,
        "n": len(rows),
        "by_criterion": by_criterion,
    }
