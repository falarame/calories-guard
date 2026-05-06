"""
Run the Sprint 0 baseline eval.

Usage:
    cd backend
    python -m tests.eval.run_eval                          # all components
    python -m tests.eval.run_eval --component=extraction   # one component
    python -m tests.eval.run_eval --skip-llm               # skip Ollama-backed (offline)

Components hitting Ollama: estimate, coach. Others (extraction, scope) are
deterministic and run without a model.
"""
from __future__ import annotations

import argparse
import json
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent
DATASETS = ROOT / "datasets"
# Make backend imports work when invoked as a script.
sys.path.insert(0, str(ROOT.parent.parent))


def _read_jsonl(p: Path) -> list[dict]:
    return [json.loads(line) for line in p.read_text(encoding="utf-8").splitlines() if line.strip()]


def eval_extraction() -> dict:
    from ai_models.food_extraction import extract_foods
    from tests.eval.metrics.extraction import average_f1

    rows = []
    for ex in _read_jsonl(DATASETS / "extraction.jsonl"):
        result = extract_foods(ex["text"])
        predicted = [r["name"] for r in result]
        rows.append({"predicted": predicted, "expected": ex["expected"]})
    return average_f1(rows)


def eval_scope() -> dict:
    from ai_models.scope_guard import is_in_scope
    from tests.eval.metrics.scope import confusion

    rows = []
    for ex in _read_jsonl(DATASETS / "scope.jsonl"):
        pred = is_in_scope(ex["text"])
        rows.append({
            "predicted_in_scope": pred,
            "expected_in_scope": ex["expected_in_scope"],
        })
    return confusion(rows)


def eval_estimate() -> dict:
    from ai_models import llm_provider
    from ai_models.prompts import MEAL_ESTIMATE_SYSTEM_PROMPT
    from tests.eval.metrics.estimate import aggregate_mape

    rows = []
    failures = 0
    for ex in _read_jsonl(DATASETS / "estimate.jsonl"):
        try:
            result = llm_provider.generate_json(
                MEAL_ESTIMATE_SYSTEM_PROMPT,
                f"ชื่ออาหาร: {ex['name']}",
            )
            predicted = {
                k: float(result.get(k, 0) or 0)
                for k in ("calories", "protein", "carbs", "fat")
            }
        except Exception as e:
            failures += 1
            predicted = {k: 0.0 for k in ("calories", "protein", "carbs", "fat")}
        rows.append({"predicted": predicted, "expected": ex["expected"]})
    out = aggregate_mape(rows)
    out["llm_failures"] = failures
    return out


def eval_coach() -> dict:
    from ai_models import llm_provider
    from ai_models.prompts import COACH_SYSTEM_PROMPT
    from ai_models.scope_guard import REJECT_MSG, is_in_scope
    from tests.eval.metrics.coach_rubric import aggregate

    stub_system = COACH_SYSTEM_PROMPT.format(
        goal_type="ลดน้ำหนัก",
        target_weight_kg=60,
        current_weight_kg=70,
        height_cm=170,
        target_calories=1800,
        target_protein=90,
        target_carbs=200,
        target_fat=60,
        allergies="ไม่มี",
        weight_trend_message="แนวโน้มลด",
        nutrition_message="สมดุล",
        critical_issues="ไม่มี",
        frequent_foods="ข้าวผัด",
    )
    rows = []
    failures = 0
    for ex in _read_jsonl(DATASETS / "coach_queries.jsonl"):
        if not is_in_scope(ex["query"]):
            response = REJECT_MSG
        else:
            try:
                response = llm_provider.generate(stub_system, ex["query"])
            except Exception:
                failures += 1
                response = ""
        rows.append({
            "query": ex["query"],
            "response": response,
            "expected_in_scope": ex["expected_in_scope"],
        })
    out = aggregate(rows)
    out["llm_failures"] = failures
    return out


def _print_section(title: str, body: str) -> None:
    bar = "─" * 72
    print(f"\n{bar}\n{title}\n{bar}\n{body}")


def _format_extraction(result: dict) -> str:
    return (
        f"  n          : {result['n']}\n"
        f"  precision  : {result['precision']:.3f}\n"
        f"  recall     : {result['recall']:.3f}\n"
        f"  F1 score   : {result['f1']:.3f}\n"
        f"  → target   : F1 ≥ 0.85"
    )


def _format_estimate(result: dict) -> str:
    bm = result["by_macro"]
    return (
        f"  n              : {result['n']}\n"
        f"  llm failures   : {result.get('llm_failures', 0)}\n"
        f"  MAPE (mean)    : {result['mape_mean']:.1f}%\n"
        f"  MAPE calories  : {bm['calories']:.1f}%\n"
        f"  MAPE protein   : {bm['protein']:.1f}%\n"
        f"  MAPE carbs     : {bm['carbs']:.1f}%\n"
        f"  MAPE fat       : {bm['fat']:.1f}%\n"
        f"  → target       : MAPE ≤ 15%"
    )


def _format_scope(result: dict) -> str:
    inn = result["in_scope"]
    out = result["out_of_scope"]
    return (
        f"  n                 : {result['n']}\n"
        f"  in-scope  P / R   : {inn['precision']:.3f} / {inn['recall']:.3f}\n"
        f"  out-scope P / R   : {out['precision']:.3f} / {out['recall']:.3f}\n"
        f"  min P / min R     : {result['min_p']:.3f} / {result['min_r']:.3f}\n"
        f"  → target          : P,R ≥ 0.95 each"
    )


def _format_coach(result: dict) -> str:
    bc = result["by_criterion"]
    return (
        f"  n              : {result['n']}\n"
        f"  llm failures   : {result.get('llm_failures', 0)}\n"
        f"  pass rate      : {result['pass_rate']*100:.1f}%\n"
        f"  by criterion   :\n"
        f"    non_empty    : {bc['non_empty']*100:.1f}%\n"
        f"    is_thai      : {bc['is_thai']*100:.1f}%\n"
        f"    brevity      : {bc['brevity']*100:.1f}%\n"
        f"    relevant     : {bc['relevant']*100:.1f}%\n"
        f"    scope_safe   : {bc['scope_safe']*100:.1f}%\n"
        f"  → target       : pass rate ≥ 85%"
    )


def main() -> None:
    parser = argparse.ArgumentParser(description="Run AI eval baseline")
    parser.add_argument(
        "--component",
        choices=["all", "extraction", "estimate", "scope", "coach"],
        default="all",
    )
    parser.add_argument(
        "--skip-llm",
        action="store_true",
        help="Skip Ollama-backed components (estimate, coach). Useful when offline.",
    )
    args = parser.parse_args()

    summary = {}
    started = time.time()

    if args.component in ("all", "extraction"):
        r = eval_extraction()
        summary["extraction"] = r
        _print_section("Food Extraction (deterministic, no LLM)", _format_extraction(r))

    if args.component in ("all", "scope"):
        r = eval_scope()
        summary["scope"] = r
        _print_section("Scope Guard (deterministic, no LLM)", _format_scope(r))

    if not args.skip_llm and args.component in ("all", "estimate"):
        r = eval_estimate()
        summary["estimate"] = r
        _print_section("Meal Estimate (Ollama)", _format_estimate(r))

    if not args.skip_llm and args.component in ("all", "coach"):
        r = eval_coach()
        summary["coach"] = r
        _print_section("Coach Response (Ollama + rubric)", _format_coach(r))

    elapsed = time.time() - started
    print(f"\nElapsed: {elapsed:.1f}s")

    # Write a machine-readable summary.
    out_path = Path(__file__).resolve().parent.parent.parent / "logs" / "eval_last.json"
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"Summary written to {out_path}")


if __name__ == "__main__":
    main()
