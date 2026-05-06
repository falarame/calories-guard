"""End-to-end coach agent test with mocked DB + LLM."""
from datetime import date, timedelta

import ai_models.coach_agent as ca
from ai_models.coach_agent import CoachAgent


def _profile():
    return {
        "username": "frame",
        "gender": "M",
        "birth_date": date(1995, 1, 1),
        "height_cm": 175,
        "current_weight_kg": 72.0,
        "goal_type": "ลดน้ำหนัก",
        "target_weight_kg": 65.0,
        "target_calories": 2000,
        "target_protein": 100,
        "target_carbs": 250,
        "target_fat": 70,
        "activity_level": "moderate",
    }


def _context() -> dict:
    base = date(2026, 1, 1)
    return {
        "profile": _profile(),
        "weight_logs": [
            {"date": base + timedelta(days=i), "weight": 72.0 - 0.1 * i}
            for i in range(7)
        ][::-1],
        "daily_summaries": [
            {"date": base, "calories": 1900, "protein": 95, "carbs": 240, "fat": 68}
        ],
        "recent_foods": [
            {"food_name": "ข้าวผัด", "amount": 1, "cal_per_unit": 500},
            {"food_name": "ข้าวผัด", "amount": 1, "cal_per_unit": 500},
            {"food_name": "ส้มตำ",   "amount": 1, "cal_per_unit": 200},
        ],
        "allergies": ["กุ้ง"],
    }


def test_off_topic_returns_reject(monkeypatch):
    agent = CoachAgent()
    out = agent.generate_response(1, "เขียนโค้ด python ให้หน่อย")
    assert "โภชนาการ" in out or "อาหาร" in out


def test_no_user_context_returns_polite_error(monkeypatch):
    agent = CoachAgent()
    monkeypatch.setattr(agent, "fetch_user_context", lambda uid: None)
    out = agent.generate_response(99, "ข้าวผัดกะเพรากี่แคล")
    assert "โปรไฟล์" in out


def test_happy_path_calls_llm_with_built_prompt(monkeypatch):
    agent = CoachAgent()
    captured: dict = {}

    def fake_generate(system, user, **_kw):
        captured["system"] = system
        captured["user"] = user
        return "กินข้าวผัดกะเพราได้ ~500 kcal ครับ"

    monkeypatch.setattr(agent, "fetch_user_context", lambda uid: _context())
    monkeypatch.setattr(ca.llm_provider, "is_configured", lambda: True)
    monkeypatch.setattr(ca.llm_provider, "generate", fake_generate)

    out = agent.generate_response(1, "ข้าวผัดกะเพรากี่แคล")

    assert "500" in out
    assert "ลดน้ำหนัก" in captured["system"]    # goal injected
    assert "กุ้ง" in captured["system"]          # allergy injected
    assert "ข้าวผัด" in captured["system"]      # frequent food injected


def test_llm_unavailable_returns_friendly_message(monkeypatch):
    agent = CoachAgent()

    def boom(*_a, **_kw):
        raise ca.llm_provider.LLMUnavailable("ollama down")

    monkeypatch.setattr(agent, "fetch_user_context", lambda uid: _context())
    monkeypatch.setattr(ca.llm_provider, "is_configured", lambda: True)
    monkeypatch.setattr(ca.llm_provider, "generate", boom)

    out = agent.generate_response(1, "ข้าวผัดกะเพรากี่แคล")
    assert "ใช้ไม่ได้ชั่วคราว" in out


def test_llm_not_configured_returns_mock(monkeypatch):
    agent = CoachAgent()
    monkeypatch.setattr(agent, "fetch_user_context", lambda uid: _context())
    monkeypatch.setattr(ca.llm_provider, "is_configured", lambda: False)
    out = agent.generate_response(1, "ข้าวผัดกะเพรากี่แคล")
    assert "Mock" in out or "แนวโน้ม" in out
