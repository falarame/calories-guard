from datetime import date, datetime

import pytest

from app.services.nutrition_safety_service import (
    EnergyContext,
    classify_calorie_safety,
    compute_energy_context,
)


def _context(**overrides):
    values = {
        "user_id": 1,
        "date_record": date(2026, 5, 6),
        "total_intake": 1200.0,
        "has_food_log": True,
        "gender": "female",
        "bmr": 1350.0,
        "tdee": 2000.0,
        "target_calories": 1600.0,
        "min_safe_calories": 1350.0,
    }
    values.update(overrides)
    return EnergyContext(**values)


def _codes(findings):
    return [finding.code for finding in findings]


def test_compute_energy_context_uses_bmr_tdee_and_safe_floor():
    ctx = compute_energy_context(
        user_id=1,
        user={
            "gender": "male",
            "birth_date": date(1996, 5, 1),
            "height_cm": 175,
            "current_weight_kg": 80,
            "activity_level": "moderately_active",
            "target_calories": 2200,
        },
        total_intake=1800,
        has_food_log=True,
        date_record=date(2026, 5, 6),
        today=date(2026, 5, 6),
    )

    assert ctx.bmr == pytest.approx(1748.75)
    assert ctx.tdee == pytest.approx(2710.5625)
    assert ctx.min_safe_calories == pytest.approx(1748.75)
    assert ctx.target_calories == 2200


def test_no_low_intake_warning_before_evening_cutoff():
    findings = classify_calorie_safety(
        _context(total_intake=600),
        now=datetime(2026, 5, 6, 12, 0),
    )

    assert _codes(findings) == []


def test_no_low_intake_warning_when_user_has_no_food_log():
    findings = classify_calorie_safety(
        _context(total_intake=0, has_food_log=False),
        now=datetime(2026, 5, 6, 20, 0),
    )

    assert _codes(findings) == []


def test_severe_low_intake_after_cutoff_is_danger():
    findings = classify_calorie_safety(
        _context(total_intake=650),
        now=datetime(2026, 5, 6, 20, 0),
    )

    assert _codes(findings) == ["severe_low_intake"]
    assert findings[0].severity == "danger"


def test_below_safe_floor_warning_after_cutoff():
    findings = classify_calorie_safety(
        _context(total_intake=1200, min_safe_calories=1350),
        now=datetime(2026, 5, 6, 20, 0),
    )

    assert "below_safe_floor" in _codes(findings)


def test_large_deficit_warning_when_intake_is_above_safe_floor():
    findings = classify_calorie_safety(
        _context(total_intake=1500, min_safe_calories=1200, tdee=2400),
        now=datetime(2026, 5, 6, 20, 0),
    )

    assert _codes(findings) == ["large_deficit"]


def test_severe_deficit_warning_when_gap_is_very_large():
    findings = classify_calorie_safety(
        _context(total_intake=1500, min_safe_calories=1200, tdee=2700),
        now=datetime(2026, 5, 6, 20, 0),
    )

    assert _codes(findings) == ["severe_deficit"]
    assert findings[0].severity == "danger"


def test_consecutive_low_intake_adds_pattern_warning():
    findings = classify_calorie_safety(
        _context(total_intake=1200, min_safe_calories=1350),
        now=datetime(2026, 5, 6, 20, 0),
        recent_low_days=2,
    )

    assert "below_safe_floor" in _codes(findings)
    assert "consecutive_low_intake" in _codes(findings)


def test_unsafe_manual_target_is_flagged_even_before_cutoff():
    findings = classify_calorie_safety(
        _context(target_calories=1000, min_safe_calories=1350),
        now=datetime(2026, 5, 6, 10, 0),
    )

    assert _codes(findings) == ["unsafe_target_calories"]
