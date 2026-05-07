# Manual QA and Demo Screenshots

Date: 2026-05-07

Use this checklist on a real Android device or emulator connected to staging.
Capture screenshots after each step for the demo deck.

## Build under test

```bash
cd flutter_application_1
flutter build apk --release \
  --dart-define=APP_ENV=staging \
  --dart-define=API_BASE_URL=https://<staging-api> \
  --dart-define=SUPABASE_URL=https://<staging-ref>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<staging-anon-key> \
  --dart-define=PRIVACY_POLICY_URL=https://admin.caloriesguard.com/privacy.html \
  --dart-define=TERMS_URL=https://admin.caloriesguard.com/terms.html
```

## Screenshots to capture

- Welcome/Login screen
- Data consent screen
- Gender/personal info/activity onboarding
- Goal selection and target weight/duration
- Food allergy selection
- Home dashboard after onboarding
- Record food screen before adding food
- Food search results
- Added meal with updated calories/macros
- AI estimate fallback when AI is unavailable or times out
- Water log update
- Weight/progress chart
- Recommended food list
- Recipe detail
- AI Coach normal response, if AI is available
- AI Coach unavailable fallback, if `AI_ENABLED=false`
- Tamagotchi missions/reward
- Settings with Privacy Policy and Terms links
- Privacy Policy opened in browser
- Terms opened in browser
- Staging banner visible

## Functional QA

| Step | Expected result | Status |
|---|---|---|
| Login with demo user | User lands on home or onboarding continuation |  |
| Register new staging user | User is created only in staging Supabase |  |
| Accept consent | App proceeds to profile flow |  |
| Complete onboarding | BMI, calorie target, macros are calculated |  |
| Record one food | Home calories and meal list update |  |
| Record beverage | Water total updates when beverage is non-alcoholic |  |
| Toggle notification permission | OS permission dialog appears; app does not crash if denied |  |
| Open Health Connect/Samsung Health | Permission/status screen appears; app has fallback if unavailable |  |
| Ask AI Coach with `AI_ENABLED=true` | Returns in-scope answer |  |
| Ask AI Coach with `AI_ENABLED=false` | Shows AI-unavailable fallback and core app remains usable |  |
| Disable network and ask AI | Shows network fallback, no crash |  |
| Open Privacy Policy | Browser opens public URL |  |
| Open Terms | Browser opens public URL |  |
| Delete account on staging | User returns to welcome/login |  |

## Physical Android checks

- App installs as `com.caloriesguard.app`.
- Login works over mobile data and Wi-Fi.
- Record meal works after app restart.
- Notification permission request works on Android 13+.
- Health Connect/Samsung Health permission prompt appears when supported.
- If Health Connect is unavailable, the app shows fallback state and still allows manual logging.
