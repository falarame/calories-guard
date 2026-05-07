# Monitoring & SLOs

> Covers PRODUCTION_READINESS.md task #14.
> What's observed, where to look, and how to react.

---

## Stack

| Signal | Tool | Cost |
|---|---|---|
| Errors + transactions | Sentry (one project per env) | Free tier: 5 k errors / 10 k perf events per month |
| Uptime probe on `/health` | UptimeRobot | Free: 50 monitors, 5-minute interval |
| Supabase DB health | Supabase Dashboard | Included |
| Railway app logs | Railway logs tab | Included (7-day retention) |

Two Sentry projects — one per env — so staging noise does not drown out
real prod alerts:

- `calories-guard-api` (prod)
- `calories-guard-api-staging`

Flutter has its own DSN injected via `--dart-define=SENTRY_DSN=...`.

---

## SLO-critical transactions

Three operations are tagged explicitly with `sentry_sdk` so the
dashboard can slice failure rate and p95 by op:

| `transaction.op` | Wrapped in | Why it's tracked |
|---|---|---|
| `auth.login` | `backend/app/routers/auth.py::login` | Login success rate is table-stakes for any session app. |
| `meal.create` | `backend/app/routers/meals.py::add_meal` | The core user journey. A regression here wastes every other feature. |
| `chat.coach`, `chat.multi` | `backend/app/routers/chat.py` | Ollama can be slow or unavailable. Failure rate + p95 tell us when to flip AI_ENABLED=false. |

Helper lives in `backend/app/core/observability.py` — call sites look
like:

```python
from app.core.observability import track, note_failure

with track("meal.create", "POST /meals", user_id=uid, items=len(items)):
    ...
```

The helper degrades to a no-op if `sentry-sdk` isn't installed or
`SENTRY_DSN` is empty, so it is safe in local dev.

---

## Flutter side

Hot-path transactions are started from the widgets, not from the HTTP
client, so they capture Flutter work (layout, form validation) too:

| Client op | File | Notes |
|---|---|---|
| `meal.record` | `lib/screens/record/record_food_screen.dart` → `_submit()` | Wrap with `Sentry.startTransaction("meal.record", "ui.submit")`. |
| `chat.send` | `lib/screens/chat/chat_screen.dart` → `_send()` | Errors are reported through `ErrorReporter.report("chat.send", ...)`; add a full Sentry transaction if UI latency needs its own SLO. |

`lib/services/error_reporter.dart` already ships silent errors to Sentry
with a `where=` tag — that gives a per-screen breakdown in the issues
tab.

---

## Dashboard recipe (Sentry)

In Sentry → Dashboards → New:

1. Panel 1 — **Login success rate 24 h**.
   Query: `event.type:transaction transaction.op:auth.login`.
   Visualization: Big Number, metric = `failure_rate()`.

2. Panel 2 — **Meal create p95 latency**.
   Query: `event.type:transaction transaction.op:meal.create`.
   Visualization: Area, metric = `p95(transaction.duration)`.

3. Panel 3 — **AI chat throughput + error count**.
   Query: `event.type:transaction transaction.op:chat.coach OR chat.multi`.
   Visualization: Line, `count()` and `count_if(transaction.status != ok)`.

Paste the dashboard URL below once created so anyone on call can open
it in one click:

- **Prod dashboard**: _TODO — fill in after creating in Sentry_
- **Staging dashboard**: _TODO_

---

## Alerting thresholds

Set these in Sentry → Alerts → New Metric Alert. First-pass numbers —
tune after a week of data.

| Alert | Condition | Route |
|---|---|---|
| Login failure spike | `auth.login` failure_rate > 10% over 10 min | `#oncall` Slack |
| Meal create p95 regression | `meal.create` p95 > 2s over 30 min | `#oncall` |
| Ollama outage | `chat.coach` OR `chat.multi` failure_rate > 30% over 15 min | `#oncall`, also triggers `AI_ENABLED=false` runbook below |
| Uptime drop | UptimeRobot 2 consecutive failures | email + SMS |

## Runbook: AI outage

1. Check Sentry `chat.*` dashboard. If failure rate > 30% persistent:
2. Railway → prod service → env vars → set `AI_ENABLED=false` → restart.
3. Clients get 503 and display a clear AI-unavailable fallback in
   `lib/screens/chat/chat_screen.dart`; core logging/dashboard features remain usable.
4. Keep monitoring Ollama process health, CPU/GPU/RAM, and request latency.
5. Flip `AI_ENABLED` back to `true` once failure rate < 5% for 30 min.

## Runbook: DB latency spike

1. Supabase Dashboard → Database → Query performance → sort by
   `mean_exec_time`.
2. If a single query dominates, check recent migrations for new tables
   without indexes (see `backend/migrations/v11_add_performance_indexes.sql`).
3. `EXPLAIN ANALYZE` the offender, add index via a new migration file.
