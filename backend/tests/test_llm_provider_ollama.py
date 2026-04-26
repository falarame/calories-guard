import ai_models.llm_provider as llm_provider


class _FakeResponse:
    def __init__(self, payload):
        self._payload = payload

    def raise_for_status(self):
        return None

    def json(self):
        return self._payload


def test_ollama_provider_posts_to_local_chat_api(monkeypatch):
    calls = []

    def fake_post(url, headers, json, timeout):
        calls.append({"url": url, "headers": headers, "json": json, "timeout": timeout})
        return _FakeResponse({"message": {"content": "ตอบจาก Ollama"}})

    monkeypatch.setenv("LLM_PROVIDER", "ollama")
    monkeypatch.setenv("OLLAMA_BASE_URL", "http://ollama:11434")
    monkeypatch.setenv("OLLAMA_MODEL", "deepseek-r1:1.5b")
    monkeypatch.setenv("OLLAMA_TIMEOUT", "12")
    monkeypatch.setattr(llm_provider.requests, "post", fake_post)

    result = llm_provider.generate("system prompt", "user prompt")

    assert result == "ตอบจาก Ollama"
    assert calls[0]["url"] == "http://ollama:11434/api/chat"
    assert calls[0]["headers"] is None
    assert calls[0]["timeout"] == 12.0
    assert calls[0]["json"]["model"] == "deepseek-r1:1.5b"
    assert calls[0]["json"]["stream"] is False
    assert calls[0]["json"]["messages"] == [
        {"role": "system", "content": "system prompt"},
        {"role": "user", "content": "user prompt"},
    ]


def test_ollama_is_default_provider_without_deepseek_key(monkeypatch):
    monkeypatch.delenv("LLM_PROVIDER", raising=False)
    monkeypatch.delenv("DEEPSEEK_API_KEY", raising=False)
    monkeypatch.setenv("OLLAMA_MODEL", "deepseek-r1:1.5b")

    assert llm_provider.is_configured() is True


def test_ollama_provider_sends_proxy_bearer_token(monkeypatch):
    calls = []

    def fake_post(url, headers, json, timeout):
        calls.append({"url": url, "headers": headers, "json": json, "timeout": timeout})
        return _FakeResponse({"message": {"content": "ok"}})

    monkeypatch.setenv("LLM_PROVIDER", "ollama")
    monkeypatch.setenv("OLLAMA_BASE_URL", "https://ollama.example.com")
    monkeypatch.setenv("OLLAMA_MODEL", "deepseek-r1:1.5b")
    monkeypatch.setenv("OLLAMA_API_KEY", "sk-local-ollama")
    monkeypatch.setattr(llm_provider.requests, "post", fake_post)

    assert llm_provider.generate("s", "u") == "ok"
    assert calls[0]["headers"] == {"Authorization": "Bearer sk-local-ollama"}
