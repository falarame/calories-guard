# E2E Connectivity Audit - 2026-05-07

## Scope

ตรวจ flow เชื่อมต่อระหว่าง Flutter app, backend API, database-backed tests,
admin web build และ deployment health เท่าที่ทำได้จาก workspace นี้
โดยไม่ใช้ Android เครื่องจริงหรือบัญชี production จริง

## Automated Checks Run

| Check | Result |
|---|---|
| Flutter -> Backend route contract audit | PASS: 62 Flutter API calls, 0 unmatched |
| Backend route count discovered | 88 routes |
| Flutter analyze | PASS |
| Flutter tests | PASS: 284 tests |
| Backend pytest | PASS: 129 tests |
| Backend meal DB integration | PASS: create -> summary -> detail -> delete |
| Admin web production build | PASS |
| Android debug APK build | PASS |

## Fixes Applied During Audit

1. Manual meal save now validates API/DB success before updating Home.
2. Home meal list preserves `dailyMeals` when only calorie/macros are updated.
3. Backend meal date queries use Asia/Bangkok date extraction.
4. AI meal save now notifies Home to refresh the saved date.
5. Added `scripts/audit_flutter_backend_contract.py` for repeatable route contract audits.

## Connectivity Status By Flow

| Flow | Automated Status | Notes |
|---|---|---|
| Email register/login backend endpoints | Covered by backend auth tests and route contract | Supabase real email OTP still needs manual test |
| Google/Facebook OAuth | Route contract only | Requires real OAuth redirect/device/browser |
| Profile fetch/update | Route contract and backend tests | Avatar upload needs manual media selection |
| Food search/list | Route contract and backend tests | Search UX still needs manual app test |
| Quick custom food from record page | Route contract and manual-save code path verified by analyze/build | Admin approval lifecycle should be manually verified |
| Manual meal record | Backend DB integration PASS | App UI device test still recommended |
| AI meal estimate/save | Route contract PASS and Home refresh fixed | AI provider availability still environment-dependent |
| Daily summary/Home meals | Backend DB integration PASS | Home UI render should be manually verified on device |
| Water log | Backend tests PASS | UI permission-free, device test recommended |
| Weight log/progress | Backend tests PASS | UI chart render should be manually verified |
| Notifications read/unread | Route contract PASS | Push/local notification permission needs Android device |
| Health Connect/Samsung Health | Not automatable here | Requires physical Android + Health Connect/Samsung Health data |
| Tamagotchi points/reward | Route contract and Flutter logic tests | DB persistence route needs manual/e2e extension |
| Recipe favorite/review | Backend tests PASS | UI interaction needs manual test |
| Admin web users/foods/temp approvals | Admin build PASS and backend admin tests PASS | Browser manual QA recommended |

## Known Limits

- This audit did not use a physical Android device.
- This audit did not log in with a real user on production/staging Supabase.
- `APP_ENV=staging` alone does not change `API_BASE_URL` or `SUPABASE_URL`; staging builds must pass all dart-defines explicitly.
- Health Connect, Samsung Health, notification permission, OAuth redirect, camera/gallery upload, and public store install flows require manual QA.

## Repeat Commands

```powershell
python scripts/audit_flutter_backend_contract.py --verbose
flutter analyze
flutter test
pytest -q
npm run build
flutter build apk --debug --dart-define=APP_ENV=staging
```
