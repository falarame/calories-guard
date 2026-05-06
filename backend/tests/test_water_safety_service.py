from datetime import date, datetime

from app.services.water_safety_service import classify_water_safety


def _codes(findings):
    return [finding.code for finding in findings]


def test_no_water_warning_before_evening_cutoff():
    findings = classify_water_safety(
        amount_ml=250,
        date_record=date(2026, 5, 6),
        now=datetime(2026, 5, 6, 12, 0),
    )

    assert _codes(findings) == []


def test_no_water_warning_when_target_is_met():
    findings = classify_water_safety(
        amount_ml=2000,
        date_record=date(2026, 5, 6),
        now=datetime(2026, 5, 6, 20, 0),
    )

    assert _codes(findings) == []


def test_low_water_warning_after_cutoff():
    findings = classify_water_safety(
        amount_ml=1200,
        date_record=date(2026, 5, 6),
        now=datetime(2026, 5, 6, 20, 0),
    )

    assert _codes(findings) == ["low_water"]
    assert findings[0].severity == "info"


def test_severe_low_water_warning_after_cutoff():
    findings = classify_water_safety(
        amount_ml=750,
        date_record=date(2026, 5, 6),
        now=datetime(2026, 5, 6, 20, 0),
    )

    assert _codes(findings) == ["severe_low_water"]
    assert findings[0].severity == "warning"


def test_past_date_is_evaluated_even_before_today_cutoff():
    findings = classify_water_safety(
        amount_ml=1000,
        date_record=date(2026, 5, 5),
        now=datetime(2026, 5, 6, 9, 0),
    )

    assert _codes(findings) == ["low_water"]
