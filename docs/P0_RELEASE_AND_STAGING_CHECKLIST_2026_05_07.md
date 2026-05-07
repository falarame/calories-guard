# P0 Release, Staging, Secrets, and Load-Test Checklist

Date: 2026-05-07

## Completed in code

- `flutter analyze` now returns `No issues found`.
- Flutter deprecated `withOpacity` calls were replaced with `withValues(alpha: ...)`.
- Production `print(...)` calls in Flutter avatar upload flows were replaced with `debugPrint(...)`.
- Settings now opens public Privacy Policy and Terms URLs.
- `admin-web/public/privacy.html` and `admin-web/public/terms.html` were added so Cloudflare Pages can serve real legal URLs.
- Chat screen now shows clearer fallback messages for AI disabled, AI timeout, rate limit, network failure, and unknown AI failure.
- `APP_ENV=staging` now shows a visible `STAGING` banner in the Flutter app.
- A manual GitHub Actions workflow was added for staging k6 load tests: `.github/workflows/loadtest.yml`.

## Must be done in provider consoles

### Rotate Supabase secrets

The local `.env` contains real Supabase credentials and must be treated as exposed.

Do this in Supabase Dashboard before beta testing:

1. Database Settings -> rotate/reset the database password.
2. Project Settings -> API/JWT -> rotate JWT secret if supported by your current Supabase plan/workflow.
3. Regenerate or replace service role key if available.
4. Update Railway prod/staging env vars:
   - `SUPABASE_PASSWORD`
   - `DATABASE_URL` or DB host/user/password fields
   - `SUPABASE_JWT_SECRET`
   - `SUPABASE_SERVICE_ROLE_KEY`
5. Update GitHub Actions secrets used by deploy/synthetic/load-test workflows.
6. Restart Railway services and confirm `/health`.

Never commit `.env`; it is already ignored by `.gitignore`.

### Confirm staging is isolated

Required checks:

- Railway staging service uses a different Supabase project ref from production.
- Flutter staging APK is built with:

```bash
flutter build apk --release \
  --dart-define=APP_ENV=staging \
  --dart-define=API_BASE_URL=https://<staging-api> \
  --dart-define=SUPABASE_URL=https://<staging-ref>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<staging-anon-key>
```

- Register a test user in staging and verify it does not appear in production.
- The app shows the `STAGING` banner.

### Run staging load tests

Local machine note: `k6` was not installed on the current Windows machine.

Run from GitHub Actions after adding these secrets:

- `STAGING_URL`
- `LOADTEST_USER_TOKEN`
- `LOADTEST_USER_ID`

Then run:

1. GitHub Actions -> `Staging load test`
2. `scenario=all`
3. Record p95/error rate in `docs/LOAD_TEST_<YYYY>_<MM>.md`

Scenarios covered:

- `/foods?q=...`
- `/meals/{user_id}` + `/daily_summary/{user_id}`
- `/api/chat/coach`

### Monitoring dashboard

Sentry instrumentation already tags:

- `auth.login`
- `meal.create`
- `chat.coach`
- `chat.multi`

Create dashboard panels in Sentry:

- Login failure rate, 24h
- Meal create p95 latency and failure rate
- AI chat p95/error count

Paste dashboard URLs into `docs/MONITORING.md` after creation.

## Deploy path

Pushing `main` triggers:

- `.github/workflows/ci.yml`
- `.github/workflows/deploy.yml` staging deploy, if `RAILWAY_STAGING_WEBHOOK` and `STAGING_URL` are configured

Production deploy is manual:

- GitHub Actions -> `Deploy`
- `confirm=yes`

