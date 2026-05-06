"""Error-path tests for ai_models.llm_provider — supplements the happy-path tests
in test_llm_provider_ollama.py."""
import pytest
import requests

import ai_models.llm_provider as llm


class _Resp:
    def __init__(self, status: int, body):
        self.status_code = status
        self.text = str(body)
        self._body = body

    def json(self):
        if isinstance(self._body, str):
            raise ValueError("not json")
        return self._body


def test_4xx_raises_config_error(monkeypatch):
    monkeypatch.setenv("OLLAMA_BASE_URL", "http://x")
    monkeypatch.setenv("OLLAMA_MODEL", "deepseek-r1:8b")
    monkeypatch.setattr(
        llm.requests, "post", lambda *a, **kw: _Resp(404, "model not found")
    )
    with pytest.raises(llm.LLMConfigError):
        llm.generate("s", "u")


def test_timeout_raises_llm_timeout(monkeypatch):
    monkeypatch.setenv("OLLAMA_BASE_URL", "http://x")
    monkeypatch.setenv("OLLAMA_MODEL", "deepseek-r1:8b")

    def boom(*a, **kw):
        raise requests.Timeout("timed out")

    monkeypatch.setattr(llm.requests, "post", boom)
    monkeypatch.setattr(llm.time, "sleep", lambda _s: None)
    with pytest.raises(llm.LLMTimeout):
        llm.generate("s", "u")


def test_connection_error_retried_then_unavailable(monkeypatch):
    monkeypatch.setenv("OLLAMA_BASE_URL", "http://x")
    monkeypatch.setenv("OLLAMA_MODEL", "deepseek-r1:8b")
    calls = {"n": 0}

    def boom(*a, **kw):
        calls["n"] += 1
        raise requests.ConnectionError("refused")

    monkeypatch.setattr(llm.requests, "post", boom)
    monkeypatch.setattr(llm.time, "sleep", lambda _s: None)
    with pytest.raises(llm.LLMUnavailable):
        llm.generate("s", "u")
    assert calls["n"] == 2


def test_5xx_retried_then_unavailable(monkeypatch):
    monkeypatch.setenv("OLLAMA_BASE_URL", "http://x")
    monkeypatch.setenv("OLLAMA_MODEL", "deepseek-r1:8b")
    calls = {"n": 0}

    def fake_post(*a, **kw):
        calls["n"] += 1
        return _Resp(503, "unavail")

    monkeypatch.setattr(llm.requests, "post", fake_post)
    monkeypatch.setattr(llm.time, "sleep", lambda _s: None)
    with pytest.raises(llm.LLMUnavailable):
        llm.generate("s", "u")
    assert calls["n"] == 2


def test_empty_content_raises(monkeypatch):
    monkeypatch.setenv("OLLAMA_BASE_URL", "http://x")
    monkeypatch.setenv("OLLAMA_MODEL", "deepseek-r1:8b")
    monkeypatch.setattr(
        llm.requests,
        "post",
        lambda *a, **kw: _Resp(200, {"message": {"content": ""}}),
    )
    monkeypatch.setattr(llm.time, "sleep", lambda _s: None)
    with pytest.raises(llm.LLMUnavailable):
        llm.generate("s", "u")


def test_health_check_handles_connection_error(monkeypatch):
    monkeypatch.setenv("OLLAMA_BASE_URL", "http://x")

    def boom(*a, **kw):
        raise requests.ConnectionError("nope")

    monkeypatch.setattr(llm.requests, "get", boom)
    assert llm.health_check() is False


def test_health_check_ok(monkeypatch):
    monkeypatch.setenv("OLLAMA_BASE_URL", "http://x")
    monkeypatch.setattr(
        llm.requests, "get", lambda *a, **kw: _Resp(200, {"models": []})
    )
    assert llm.health_check() is True


def test_cf_access_headers_passed(monkeypatch):
    captured: dict = {}

    def fake_post(url, headers=None, json=None, timeout=None):
        captured["headers"] = headers
        return _Resp(200, {"message": {"content": "ok"}})

    monkeypatch.setenv("OLLAMA_BASE_URL", "http://x")
    monkeypatch.setenv("OLLAMA_MODEL", "deepseek-r1:8b")
    monkeypatch.setenv("CF_ACCESS_CLIENT_ID", "id-123")
    monkeypatch.setenv("CF_ACCESS_CLIENT_SECRET", "shh")
    monkeypatch.delenv("OLLAMA_SECRET_API_KEY", raising=False)
    monkeypatch.delenv("OLLAMA_API_KEY", raising=False)
    monkeypatch.setattr(llm, "settings", None)
    monkeypatch.setattr(llm.requests, "post", fake_post)

    llm.generate("s", "u")
    assert captured["headers"]["CF-Access-Client-Id"] == "id-123"
    assert captured["headers"]["CF-Access-Client-Secret"] == "shh"


def test_generate_json_parses_format_json(monkeypatch):
    captured: dict = {}

    def fake_post(url, headers=None, json=None, timeout=None):
        captured["payload"] = json
        return _Resp(200, {"message": {"content": '{"calories": 420}'}})

    monkeypatch.setenv("OLLAMA_BASE_URL", "http://x")
    monkeypatch.setenv("OLLAMA_MODEL", "deepseek-r1:8b")
    monkeypatch.setattr(llm.requests, "post", fake_post)

    out = llm.generate_json("s", "u")
    assert out == {"calories": 420}
    assert captured["payload"]["format"] == "json"


def test_generate_json_rejects_bad_json(monkeypatch):
    monkeypatch.setenv("OLLAMA_BASE_URL", "http://x")
    monkeypatch.setenv("OLLAMA_MODEL", "deepseek-r1:8b")
    monkeypatch.setattr(
        llm.requests,
        "post",
        lambda *a, **kw: _Resp(200, {"message": {"content": "not-json"}}),
    )
    with pytest.raises(llm.LLMConfigError):
        llm.generate_json("s", "u")
