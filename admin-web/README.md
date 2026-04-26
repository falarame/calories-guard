# Calories Guard — Admin Web

Vite + React + TypeScript admin panel for Calories Guard. Talks to the FastAPI
backend (which in turn uses Supabase for DB/Auth/Storage) and is deployed as a
static site on Cloudflare Pages.

```
┌──────────────┐       JWT          ┌──────────────┐      SQL      ┌──────────┐
│  Admin Web   │ ─────────────────▶ │  FastAPI     │ ───────────▶  │ Supabase │
│  (CF Pages)  │ ◀───── /login ──── │  (Railway)   │ ◀─────────    │ Postgres │
└──────────────┘                    └──────────────┘               └──────────┘
```

## Local development

```bash
cp .env.example .env.local          # defaults point at http://localhost:8000
npm install
npm run dev                         # http://localhost:3000
```

The backend must be running locally (`uvicorn main:app --reload` from
`../backend`). Log in with an admin account — any user whose `role_id == 1` in
the `users` table.

## Environment variables

| Variable                 | Required | Notes                                                 |
|--------------------------|----------|-------------------------------------------------------|
| `VITE_API_BASE_URL`      | yes      | Base URL of the FastAPI backend, no trailing slash.   |
| `VITE_SUPABASE_URL`      | no       | Reserved for future direct-to-Supabase features.      |
| `VITE_SUPABASE_ANON_KEY` | no       | Reserved for future direct-to-Supabase features.      |

Vite only exposes variables prefixed with `VITE_` to the browser — anything
sensitive (service-role keys, SMTP creds, `SUPABASE_JWT_SECRET`) must stay on
the backend.

## Deployment

### Backend → Railway

The FastAPI backend lives in `../backend` and deploys to Railway from the
project root. The admin panel depends on these backend env vars being set:

- `DB_MODE=supabase`, `SUPABASE_DB_URL` (with `sslmode=require`)
- `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_JWT_SECRET`
- `ALLOWED_ORIGINS=https://admin.calories-guard.xxx,https://app.calories-guard.xxx`

Grab the public URL from the Railway dashboard once the deploy is green — that
is what you plug into `VITE_API_BASE_URL` below.

### Admin Web → Cloudflare Pages

1. **Connect the repo** — Cloudflare dashboard → Workers & Pages → Create →
   Pages → Connect to Git → pick this repo.
2. **Build settings**
   - Framework preset: `Vite`
   - Build command: `npm run build`
   - Build output directory: `dist`
   - Root directory: `admin-web`
3. **Environment variables** (Settings → Environment variables)
   - Production: `VITE_API_BASE_URL=https://<railway-url>`
   - Preview:    `VITE_API_BASE_URL=https://<staging-railway-url>`
4. **Custom domain** (Settings → Custom domains) — point
   `admin.calories-guard.xxx` at the Pages project. Cloudflare provisions SSL
   automatically.
5. **SPA routing** is handled by `wrangler.toml` static assets config
   (`not_found_handling = "single-page-application"`);
   without this, deep-linking to `/users` etc. 404s.
6. **Security headers** are set in `public/_headers`.

### Post-deploy smoke test

- `curl https://<railway-url>/health` → `{"status":"ok"}`
- Open `https://admin.calories-guard.xxx`, log in with an admin account.
- Check the browser devtools Network tab — requests should go to the Railway
  URL with `Authorization: Bearer <jwt>`.
- Try refreshing `/users` directly in the URL bar → should not 404 (confirms
  the SPA fallback is active).

## Adding a new admin

The app does not self-serve admin creation — promote a user manually:

```sql
UPDATE users SET role_id = 1 WHERE email = 'you@example.com';
```

Run that from the Supabase SQL editor.

## Notes on auth

- The admin panel uses the same `/login` endpoint as the mobile app. On
  success, the backend returns an HS256 JWT signed with `SUPABASE_JWT_SECRET`
  — the same algorithm Supabase itself uses — so `get_current_admin` in the
  backend accepts it transparently.
- Tokens live in `localStorage` under `cg_admin_auth`. On a 401 response the
  key is cleared and the app bounces back to `/login`.
- There is no refresh-token rotation yet; tokens expire after 12 hours and the
  user must re-login.
