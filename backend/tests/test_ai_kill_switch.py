"""
AI kill-switch behaviour.

Covers #15: when AI_ENABLED is false, AI-backed endpoints
(chat/coach, meals/estimate) must 503 before touching
the configured LLM provider, so operators can cut traffic during an incident without a
redeploy.

We patch the module-level AI_ENABLED flag rather than the env var
because the config module captures it at import time by design (see
the comment on _require_ai_enabled in routers/chat.py).
"""
from unittest.mock import patch


def _disable_ai():
    return patch("app.routers.chat.AI_ENABLED", False)


def test_chat_coach_503_when_disabled(app_client):
    with _disable_ai():
        r = app_client.post("/api/chat/coach", json={"user_id": 42, "message": "hi"})
    assert r.status_code == 503
    assert "unavailable" in r.json()["detail"].lower()


def test_meal_estimate_503_when_disabled(app_client):
    with _disable_ai():
        r = app_client.post(
            "/api/meals/estimate",
            json={"user_id": 42, "message": "ข้าวผัด", "meal_type": "breakfast"},
        )
    assert r.status_code == 503

def test_chat_health_reports_disabled_without_probe(app_client):
    with _disable_ai(), patch("app.routers.chat.llm_provider.health_check") as probe:
        r = app_client.get("/api/chat/health")
    assert r.status_code == 200
    assert r.json()["ai_enabled"] is False
    assert r.json()["ollama_ok"] is False
    probe.assert_not_called()


def test_chat_health_reports_model_and_probe(app_client, monkeypatch):
    monkeypatch.setattr("app.routers.chat.AI_ENABLED", True)
    monkeypatch.setattr("app.routers.chat.settings", None)
    monkeypatch.setenv("OLLAMA_MODEL", "test-model")
    monkeypatch.setenv("OLLAMA_BASE_URL", "http://ollama-test:11434")
    with patch("app.routers.chat.llm_provider.health_check", return_value=True):
        r = app_client.get("/api/chat/health")
    assert r.status_code == 200
    body = r.json()
    assert body["ai_enabled"] is True
    assert body["ollama_ok"] is True
    assert body["model"] == "test-model"
    assert body["base_url"] == "http://ollama-test:11434"
