# Calories Guard Handoff Status

Last updated: 2026-04-27

## Current Deployment Shape

- Backend: FastAPI on Railway, public API at `https://api.caloriesguard.com`.
- Database/Auth/Storage: Supabase project, schema `cleangoal`.
- Admin web: Cloudflare Workers/Pages at `https://admin.caloriesguard.com`.
- Flutter web/PWA: Cloudflare Workers/Pages at `https://app.caloriesguard.com`.
- AI provider: Ollama local/self-hosted DeepSeek model. The app does not use DeepSeek API.

## What Has Been Done

- Supabase migrations through the regional-food/cleanup phases were applied.
- Backend was moved to production-style Supabase config.
- Admin web and Flutter web were configured for Cloudflare Workers static assets.
- Custom domains were attached:
  - `api.caloriesguard.com`
  - `admin.caloriesguard.com`
  - `app.caloriesguard.com`
- Flutter web login page was fixed for desktop responsiveness.
- Flutter web no longer hardcodes a stale Supabase anon key. Production builds must pass `SUPABASE_ANON_KEY` via `--dart-define`.
- `/login` now accepts Supabase-authenticated users and returns a backend-issued HS256 token.
- Backend auth now has fallback validation through Supabase Auth `/auth/v1/user`, useful for Supabase ES256 access tokens.
- Flutter `ApiClient` now prefers the backend-issued token after login.
- Chatbot icon asset was cropped from the wide source image into a compact transparent PNG for use in FAB/chat UI.
- Multi-agent chatbot endpoint now returns a user-friendly fallback response instead of surfacing a raw 500 if the AI pipeline fails.

## Important Environment Variables

Railway backend must have:

```env
DATABASE_URL=...
DIRECT_DATABASE_URL=...
SUPABASE_URL=https://zawlghlnzgftlxcoipuf.supabase.co
SUPABASE_PROJECT_URL=https://zawlghlnzgftlxcoipuf.supabase.co
SUPABASE_ANON_KEY=...
SUPABASE_SERVICE_ROLE_KEY=...
SUPABASE_JWT_SECRET=...
ALLOWED_ORIGINS=https://app.caloriesguard.com,https://admin.caloriesguard.com,https://caloriesguard.com
AI_ENABLED=true
LLM_PROVIDER=ollama
OLLAMA_BASE_URL=https://<ollama-domain>
OLLAMA_API_KEY=<proxy bearer secret, if proxy requires it>
OLLAMA_MODEL=deepseek-r1:1.5b
OLLAMA_TIMEOUT=120
```

Flutter web build requires:

```bash
flutter build web --release \
  --dart-define=API_BASE_URL=https://api.caloriesguard.com \
  --dart-define=SUPABASE_URL=https://zawlghlnzgftlxcoipuf.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY \
  --dart-define=APP_ENV=production
```

Cloudflare build environment does not include Flutter by default. Use local build + `npx wrangler deploy`, or move Flutter deployment to GitHub Actions.

## Recent Fix Commits

- `048092d6` Require Supabase key at Flutter build time and constrain auth layout.
- `6c855cad` Backend accepts `ALLOWED_ORIGINS` alias.
- `56e623ca` `/login` accepts Supabase token during login sync.
- `12a2eb60` Flutter sends Supabase token explicitly to `/login`.
- `6e3f6d7c` Backend validates Supabase token via Auth API fallback.

## Known Issues / Next Steps

1. Redeploy backend after auth/chat fixes.
2. Redeploy Flutter web after client or asset changes.
3. Verify all protected endpoints after login:
   - `/users/{id}`
   - `/daily_logs/{id}`
   - `/water_logs/{id}`
   - `/notifications/{id}/unread_count`
   - `/api/chat/multi`
4. Verify AI/Ollama config on Railway:
   - `OLLAMA_BASE_URL` must be reachable from Railway.
   - If Cloudflare/Nginx proxy protects Ollama, backend must set `OLLAMA_API_KEY`.
   - Ollama server must have the configured model pulled.
5. Remove or restrict `/debug-auth` before production public launch.
6. Add GitHub Actions for Flutter web deployment, because Cloudflare cannot run `flutter build` unless Flutter SDK is installed manually in the build command.
7. Continue Phase 4 database cleanup only after production auth/chat flows are stable.

## Debug Checklist

If login fails:

- Browser DevTools -> Network -> `/login` must include `Authorization: Bearer ...`.
- Railway logs should show `/login 200`.
- If protected endpoints show `JWTError: The specified alg value is not allowed`, backend is not running the auth dependency fallback commit.

If chatbot fails:

- Check Railway env `AI_ENABLED=true`.
- Check `OLLAMA_BASE_URL`, `OLLAMA_MODEL`, and optional `OLLAMA_API_KEY`.
- Railway logs should show `POST /api/chat/multi 200`; fallback responses may use `"agent": "fallback"`.
- Test Ollama directly from the server/proxy if possible.

## Files Most Relevant To Continue

- `backend/auth/dependencies.py`
- `backend/app/routers/auth.py`
- `backend/app/routers/chat.py`
- `backend/ai_models/llm_provider.py`
- `backend/ai_models/multi_agent_system.py`
- `flutter_application_1/lib/services/api_client.dart`
- `flutter_application_1/lib/services/auth_service.dart`
- `flutter_application_1/lib/screens/chat/chat_screen.dart`
- `flutter_application_1/assets/images/icon/chatbot_icon.png`

