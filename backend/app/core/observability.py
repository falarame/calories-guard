"""
Thin Sentry helpers for tagging critical-path transactions (task #14).

Sentry's FastApiIntegration already auto-creates a transaction per HTTP
request. What we add here is:
  - stable `transaction.op` and `transaction.name` for SLO dashboards
  - per-call tags (user_id, item_count) so failure rates can be sliced

If sentry-sdk is not installed, OR SENTRY_DSN wasn't set at startup,
every helper becomes a no-op — keeps the import cost zero in dev.
"""
from __future__ import annotations

from contextlib import contextmanager
from typing import Any, Iterator

try:
    import sentry_sdk  # type: ignore
    _HAS_SENTRY = True
except ImportError:
    _HAS_SENTRY = False


@contextmanager
def track(op: str, name: str, **tags: Any) -> Iterator[None]:
    """Tag the current Sentry transaction and attach a span for this scope.

    Usage:
        with track("meal.create", "POST /meals", user_id=user_id, items=len(items)):
            ...

    `op` is the coarse bucket ("meal.create", "chat.send", "auth.login")
    — SLO dashboards aggregate by this. `name` is the HTTP method+path
    for readability in the trace explorer.

    Tags show up as searchable attributes on the transaction (e.g.
    `user_id:42` lets you filter to one user when a beta tester reports
    a bug).
    """
    if not _HAS_SENTRY:
        yield
        return

    # Rename the auto-created transaction so dashboards cluster correctly.
    scope = sentry_sdk.get_current_scope() if hasattr(sentry_sdk, "get_current_scope") else None
    if scope is not None and scope.transaction is not None:
        scope.transaction.op = op
        scope.transaction.name = name
    for k, v in tags.items():
        if v is None:
            continue
        try:
            sentry_sdk.set_tag(k, str(v))
        except Exception:
            # Tag collection must never break the request path.
            pass

    with sentry_sdk.start_span(op=op, description=name):
        yield


def note_failure(where: str, exc: BaseException, **tags: Any) -> None:
    """Report an exception with a `where=` tag for SLO breakdown.

    Prefer this over raw `sentry_sdk.capture_exception(e)` in the three
    hot-path routers so the Sentry issue grouping stays readable.
    """
    if not _HAS_SENTRY:
        return
    try:
        for k, v in tags.items():
            if v is None:
                continue
            sentry_sdk.set_tag(k, str(v))
        sentry_sdk.set_tag("where", where)
        sentry_sdk.capture_exception(exc)
    except Exception:
        pass
