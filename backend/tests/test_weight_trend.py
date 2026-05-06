from datetime import date, timedelta

from ai_models.weight_trend_model import analyze_trend


def _series(weights: list[float]) -> list[dict]:
    base = date(2026, 1, 1)
    return [
        {"date": base + timedelta(days=i), "weight": w}
        for i, w in enumerate(weights)
    ]


def test_insufficient_data_returns_unknown():
    out = analyze_trend(_series([70.0]), target_weight=65.0)
    assert out["trend"] == "unknown"


def test_loss_trend_detected():
    out = analyze_trend(_series([72.0, 71.5, 71.0, 70.5, 70.0]), target_weight=65.0)
    assert out["trend"] == "ลด"
    assert out["slope_per_week"] < 0


def test_gain_trend_detected():
    out = analyze_trend(_series([60.0, 60.4, 60.8, 61.2, 61.6]), target_weight=65.0)
    assert out["trend"] == "เพิ่ม"
    assert out["slope_per_week"] > 0


def test_stable_trend():
    out = analyze_trend(_series([70.0, 70.01, 70.0, 70.02, 70.0]), target_weight=70.0)
    assert out["trend"] == "คงที่"


def test_message_mentions_target_diff():
    out = analyze_trend(_series([72.0, 71.0, 70.0, 69.0, 68.0]), target_weight=65.0)
    assert "เป้าหมาย" in out["message"]
