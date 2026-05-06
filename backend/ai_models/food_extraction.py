"""
Thai food-name extraction.

Strategy:
  1. Tokenize the message (pythainlp if available, regex fallback).
  2. Build sliding 1- to 4-gram windows.
  3. Match against either:
       (a) the caller-supplied `db_food_names` list, OR
       (b) the live `foods` + `food_regional_names` tables, OR
       (c) a small built-in fallback list of common Thai dishes.
  4. Read a "qty + unit" hint from the surrounding text (1 จาน, ครึ่งถ้วย ...).

Anything not found in the lexicon is left for the LLM-estimate path in
`nutrition_analysis.NutritionAnalysisAgent`.
"""
from __future__ import annotations

import logging
import re
from typing import Any, Iterable, Optional

from psycopg2.extras import RealDictCursor

logger = logging.getLogger(__name__)


_QTY_WORDS: dict[str, float] = {
    "ครึ่ง": 0.5,
    "หนึ่ง": 1.0, "สอง": 2.0, "สาม": 3.0, "สี่": 4.0, "ห้า": 5.0,
    "หก": 6.0, "เจ็ด": 7.0, "แปด": 8.0, "เก้า": 9.0, "สิบ": 10.0,
}

_UNIT_WORDS: tuple[str, ...] = (
    "จาน", "ถ้วย", "ชาม", "ชิ้น", "แก้ว", "ขวด", "กล่อง", "ห่อ",
    "ลูก", "ฟอง", "ใบ", "ก้าน", "กรัม", "g", "ml", "มล",
)

_QTY_RE = re.compile(
    r"(?P<num>\d+(?:[.,]\d+)?|" + "|".join(_QTY_WORDS) + r")\s*"
    r"(?P<unit>" + "|".join(_UNIT_WORDS) + r")?",
)

# Common Thai dishes used when no DB or caller-supplied dictionary is given.
# Keep this short — the DB is the source of truth in production.
_FALLBACK_DISHES: tuple[str, ...] = (
    "ข้าวผัด", "ข้าวผัดกะเพรา", "ข้าวผัดหมู", "ข้าวกะเพรา", "ข้าวมันไก่",
    "ข้าวขาหมู", "ข้าวหมูแดง", "ข้าวเหนียว",
    "ผัดไทย", "ผัดซีอิ๊ว", "ผัดกะเพรา",
    "ส้มตำ", "ลาบ", "น้ำตก",
    "ต้มยำ", "ต้มยำกุ้ง", "ต้มข่า", "ต้มจืด",
    "แกงเขียวหวาน", "แกงเผ็ด", "แกงส้ม", "แกงมัสมั่น",
    "ก๋วยเตี๋ยว", "ก๋วยเตี๋ยวเรือ",
    "ขนมจีน", "ขนมจีนน้ำยา",
    "โจ๊ก", "ข้าวต้ม",
)


def _tokenize(text: str) -> list[str]:
    try:
        from pythainlp.tokenize import word_tokenize  # type: ignore

        return [t for t in word_tokenize(text, engine="newmm") if t.strip()]
    except Exception:
        return [t for t in re.split(r"[\s,]+", text) if t]


def _token_spans(text: str, tokens: list[str]) -> list[tuple[str, int, int]]:
    """Map token strings back to character spans in the original text."""
    spans: list[tuple[str, int, int]] = []
    cursor = 0
    lowered = text.lower()
    for token in tokens:
        if not token.strip():
            continue
        idx = lowered.find(token.lower(), cursor)
        if idx == -1:
            idx = lowered.find(token.lower())
        if idx == -1:
            continue
        end = idx + len(token)
        spans.append((token, idx, end))
        cursor = end
    return spans


def _ngram_spans(
    token_spans: list[tuple[str, int, int]],
    n_min: int = 1,
    n_max: int = 6,
) -> list[tuple[str, int, int]]:
    out: list[tuple[str, int, int]] = []
    max_n = min(n_max, len(token_spans))
    for n in range(n_max, n_min - 1, -1):
        if n > max_n:
            continue
        for i in range(len(token_spans) - n + 1):
            chunk = token_spans[i : i + n]
            out.append(("".join(t for t, _, _ in chunk), chunk[0][1], chunk[-1][2]))
    return out


def _parse_qty(near_text: str) -> tuple[float, str]:
    m = _QTY_RE.search(near_text)
    if not m:
        return 1.0, ""
    num_raw = m.group("num")
    unit = m.group("unit") or ""
    if num_raw in _QTY_WORDS:
        return _QTY_WORDS[num_raw], unit
    try:
        return float(num_raw.replace(",", ".")), unit
    except ValueError:
        return 1.0, unit


def _load_db_lexicon() -> dict[str, int]:
    """name (lowered) → food_id. Pulls foods + food_regional_names. Empty on failure."""
    try:
        from database import get_db_connection
    except Exception:
        return {}
    conn = get_db_connection()
    if not conn:
        return {}
    try:
        cur = conn.cursor(cursor_factory=RealDictCursor)
        lex: dict[str, int] = {}
        cur.execute("SELECT food_id, food_name FROM foods WHERE deleted_at IS NULL")
        for row in cur.fetchall():
            name = (row["food_name"] or "").strip().lower()
            if name:
                lex.setdefault(name, row["food_id"])
        try:
            cur.execute("SELECT food_id, name_th FROM food_regional_names")
            for row in cur.fetchall():
                name = (row["name_th"] or "").strip().lower()
                if name:
                    lex.setdefault(name, row["food_id"])
        except Exception as e:
            logger.debug("food_regional_names lookup skipped: %s", e)
        return lex
    except Exception as e:
        logger.debug("DB lexicon load failed: %s", e)
        return {}
    finally:
        try:
            conn.close()
        except Exception:
            pass


def extract_foods(
    text: str,
    *,
    db_food_names: Optional[Iterable[str]] = None,
    limit: Optional[int] = None,
) -> list[dict[str, Any]]:
    """Return food mentions found in `text` (longest-match-wins, no overlap).

    Args:
        text: free-form Thai/English message.
        db_food_names: caller-supplied dictionary. When given we skip the
            DB load — used by unit tests and as a hot path when callers
            already have a cached list.
        limit: max mentions to return.

    Returns:
        list of dicts with keys: name, food_id, quantity, unit, source, raw.
    """
    if not text or not text.strip():
        return []

    if db_food_names is not None:
        lex: dict[str, Optional[int]] = {
            n.strip().lower(): None for n in db_food_names if n and n.strip()
        }
        source_label = "dict"
    else:
        db_lex = _load_db_lexicon()
        if db_lex:
            # Union DB lexicon with fallback so common dishes still match
            # even if the local DB is missing rows.
            merged: dict[str, Optional[int]] = {k: v for k, v in db_lex.items()}
            for f in _FALLBACK_DISHES:
                merged.setdefault(f.lower(), None)
            lex = merged
            source_label = "dict"
        else:
            lex = {n.lower(): None for n in _FALLBACK_DISHES}
            source_label = "fallback"

    if not lex:
        return []

    tokens = _tokenize(text)
    token_spans = _token_spans(text, tokens)
    candidates = _ngram_spans(token_spans)

    # Add direct lexicon substring candidates as a safety net. PyThaiNLP is
    # good, but regional aliases and odd punctuation can still be segmented
    # differently from the DB name.
    text_lower = text.lower()
    for key in lex.keys():
        if len(key) < 2:
            continue
        idx = 0
        while True:
            found = text_lower.find(key, idx)
            if found == -1:
                break
            candidates.append((text[found : found + len(key)], found, found + len(key)))
            idx = found + len(key)

    used_spans: list[tuple[int, int]] = []  # (start, end) of consumed chars
    mentions: list[dict[str, Any]] = []

    def _overlaps(start: int, end: int) -> bool:
        for s, e in used_spans:
            if start < e and end > s:
                return True
        return False

    seen_candidates: set[tuple[str, int, int]] = set()
    ordered_candidates = sorted(
        candidates,
        key=lambda item: (-(item[2] - item[1]), item[1]),
    )

    for raw_candidate, found, end in ordered_candidates:
        key = raw_candidate.strip().lower()
        if len(key) < 2:
            continue
        candidate_id = (key, found, end)
        if candidate_id in seen_candidates:
            continue
        seen_candidates.add(candidate_id)
        if key not in lex or _overlaps(found, end):
            continue
        window = text[found : end + 12]
        qty, unit = _parse_qty(window)
        mentions.append(
            {
                "name": text[found:end],
                "food_id": lex[key],
                "quantity": qty,
                "unit": unit,
                "source": source_label,
                "raw": window.strip(),
            }
        )
        used_spans.append((found, end))
        if limit is not None and len(mentions) >= limit:
            mentions.sort(key=lambda m: text_lower.find(m["name"].lower()))
            return mentions

    # Order results by their position in the original text.
    mentions.sort(key=lambda m: text_lower.find(m["name"].lower()))
    return mentions
