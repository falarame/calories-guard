"""
Ollama-only LLM provider.

The rest of the codebase MUST go through `generate()` / `generate_json()` —
no module should talk to an external LLM SDK directly. There is exactly one
backend (Ollama) so swapping models is an env-var change.

Env:
  OLLAMA_BASE_URL         http://127.0.0.1:11434 (dev) | https://ai.caloriesguard.com (prod tunnel)
  OLLAMA_MODEL            deepseek-r1:8b
  OLLAMA_TIMEOUT          60                       (seconds, per request)
  OLLAMA_NUM_PREDICT      320                      (max output tokens)
  OLLAMA_SECRET_API_KEY   <bearer>                 (optional — protected tunnel/proxy bearer)
  CF_ACCESS_CLIENT_ID     <id>                     (optional — alt Cloudflare Access auth)
  CF_ACCESS_CLIENT_SECRET <secret>                 (paired with CF_ACCESS_CLIENT_ID)

The chat router runs `generate` in a thread pool with a 30s wall-clock limit,
so blocking IO here is fine.
"""
from __future__ import annotations

import json
import os
import time
from typing import Any, Optional

import requests

try:
    from app.core.config import settings
except Exception:  # pragma: no cover - config import can fail in isolated scripts
    settings = None


class LLMError(RuntimeError):
    """Base class for LLM-layer failures surfaced to callers."""


class LLMUnavailable(LLMError):
    """Ollama daemon unreachable or 5xx after retry."""


class LLMTimeout(LLMError):
    """Per-request timeout exceeded."""


class LLMConfigError(LLMError):
    """4xx — bad model name, malformed payload, auth rejected."""


_DEFAULT_BASE_URL = "http://127.0.0.1:11434"
_DEFAULT_MODEL = "deepseek-r1:8b"
_DEFAULT_TIMEOUT = 60.0
_DEFAULT_NUM_PREDICT = 320


def _base_url() -> str:
    configured = getattr(settings, "ollama_base_url", None) if settings else None
    return (configured or os.getenv("OLLAMA_BASE_URL") or _DEFAULT_BASE_URL).rstrip("/")


def _model() -> str:
    configured = getattr(settings, "ollama_model", None) if settings else None
    return configured or os.getenv("OLLAMA_MODEL") or _DEFAULT_MODEL


def _timeout() -> float:
    configured = getattr(settings, "ollama_timeout", None) if settings else None
    if configured is not None:
        return float(configured)
    try:
        return float(os.getenv("OLLAMA_TIMEOUT") or _DEFAULT_TIMEOUT)
    except ValueError:
        return _DEFAULT_TIMEOUT


def _num_predict() -> int:
    configured = getattr(settings, "ollama_num_predict", None) if settings else None
    if configured is not None:
        return int(configured)
    try:
        return int(os.getenv("OLLAMA_NUM_PREDICT") or _DEFAULT_NUM_PREDICT)
    except ValueError:
        return _DEFAULT_NUM_PREDICT


def _auth_headers() -> dict[str, str]:
    headers: dict[str, str] = {}
    bearer = (
        os.getenv("OLLAMA_SECRET_API_KEY")
        or os.getenv("OLLAMA_API_KEY")
        or (getattr(settings, "ollama_api_key", None) if settings else None)
    )
    if bearer:
        headers["Authorization"] = f"Bearer {bearer}"
    cf_id = (
        os.getenv("CF_ACCESS_CLIENT_ID")
        or (getattr(settings, "cf_access_client_id", None) if settings else None)
    )
    cf_secret = (
        os.getenv("CF_ACCESS_CLIENT_SECRET")
        or (getattr(settings, "cf_access_client_secret", None) if settings else None)
    )
    if cf_id and cf_secret:
        headers["CF-Access-Client-Id"] = cf_id
        headers["CF-Access-Client-Secret"] = cf_secret
    return headers


def is_configured() -> bool:
    """True if base URL + model are present. Auth is optional."""
    return bool(_base_url()) and bool(_model())


def health_check() -> bool:
    """Cheap probe — list installed models. Used by /api/chat/health."""
    try:
        r = requests.get(
            f"{_base_url()}/api/tags",
            headers=_auth_headers() or None,
            timeout=5,
        )
        return r.status_code == 200
    except requests.RequestException:
        return False


def _post_chat(payload: dict[str, Any]) -> dict[str, Any]:
    """One POST attempt. Maps requests errors to typed LLM* exceptions."""
    try:
        response = requests.post(
            f"{_base_url()}/api/chat",
            headers=_auth_headers() or None,
            json=payload,
            timeout=_timeout(),
        )
    except requests.Timeout as e:
        raise LLMTimeout(f"Ollama timed out after {_timeout()}s") from e
    except requests.ConnectionError as e:
        raise LLMUnavailable(f"Ollama unreachable at {_base_url()}: {e}") from e

    if 400 <= response.status_code < 500:
        raise LLMConfigError(
            f"Ollama rejected request ({response.status_code}): {response.text[:300]}"
        )
    if response.status_code >= 500:
        raise LLMUnavailable(
            f"Ollama 5xx ({response.status_code}): {response.text[:300]}"
        )
    try:
        return response.json()
    except ValueError as e:
        raise LLMUnavailable(f"Ollama returned non-JSON body: {response.text[:200]}") from e


def _chat(
    system: str,
    user: str,
    *,
    json_mode: bool = False,
    temperature: float = 0.7,
) -> str:
    """Internal: build payload, retry once on transient failure, return content."""
    payload: dict[str, Any] = {
        "model": _model(),
        "stream": False,
        "messages": [
            {"role": "system", "content": system},
            {"role": "user", "content": user},
        ],
        "options": {
            "temperature": temperature,
            "num_predict": _num_predict(),
        },
    }
    if json_mode:
        payload["format"] = "json"

    last_exc: Optional[Exception] = None
    for attempt in range(2):
        try:
            body = _post_chat(payload)
            message = body.get("message") or {}
            content = (message.get("content") or "").strip()
            if not content:
                raise LLMUnavailable("Ollama returned an empty response")
            return content
        except (LLMUnavailable, LLMTimeout) as e:
            last_exc = e
            if attempt == 0:
                time.sleep(2)
                continue
            raise
        except LLMConfigError:
            # 4xx is deterministic — no point retrying.
            raise

    assert last_exc is not None
    raise last_exc


def generate(
    system: str,
    user: str,
    *,
    temperature: float = 0.7,
) -> str:
    """Plain text completion. Raises LLM* on failure."""
    return _chat(system, user, temperature=temperature)


def generate_json(
    system: str,
    user: str,
    *,
    temperature: float = 0.2,
) -> dict[str, Any]:
    """JSON-mode completion. Returns a parsed dict.

    Uses Ollama's `format: "json"` so the model is constrained to emit valid
    JSON. Caller still gets `LLMConfigError` if the model emits something we
    can't parse (rare but possible with very small models).
    """
    raw = _chat(system, user, json_mode=True, temperature=temperature)
    try:
        parsed = json.loads(raw)
    except json.JSONDecodeError as e:
        raise LLMConfigError(f"Model emitted non-JSON despite format=json: {raw[:300]}") from e
    if not isinstance(parsed, dict):
        raise LLMConfigError(f"Expected JSON object, got {type(parsed).__name__}")
    return parsed
