# คู่มือการตั้งค่า Cloudflare สำหรับ Calories Guard

คู่มือนี้ครอบคลุม DNS, deploy Flutter Web/PWA, deploy Admin Web และ custom domains บน Cloudflare

## 1. ภาพรวม

Cloudflare ใช้สำหรับ:

- DNS ของ `caloriesguard.com`
- User Web/PWA: `https://app.caloriesguard.com`
- Admin Web: `https://admin.caloriesguard.com`
- ชี้ API domain `https://api.caloriesguard.com` ไป Railway

Cloudflare ไม่ได้เก็บ backend secret ใด ๆ ของระบบ ผู้ใช้ browser จะเห็นค่าที่ถูก build ลง frontend ได้เสมอ ดังนั้นให้ใส่เฉพาะค่าที่เผยแพร่ได้ เช่น API base URL และ Supabase anon key

## 2. DNS หลัก

โดเมนที่ใช้:

| Subdomain | ปลายทาง | หมายเหตุ |
|---|---|---|
| `app.caloriesguard.com` | Cloudflare Worker static assets | Flutter Web/PWA |
| `admin.caloriesguard.com` | Cloudflare Pages/Worker | Admin Web |
| `api.caloriesguard.com` | Railway backend | FastAPI |

ค่า DNS ที่แนะนำ:

- `app`: ชี้ไป Worker/Pages ของ Flutter web
- `admin`: ชี้ไป Worker/Pages ของ Admin Web
- `api`: CNAME ไป Railway custom domain target

ถ้าใช้ Cloudflare proxy กับ Railway แล้วพบ SSL/redirect issue ให้ลองตั้ง `api` เป็น DNS only ชั่วคราวเพื่อแยกปัญหา

## 3. Deploy Flutter Web/PWA ด้วย Wrangler

โปรเจกต์ Flutter ใช้ไฟล์:

`flutter_application_1/wrangler.toml`

ตัวอย่าง config:

```toml
name = "app-caloriesguard"
compatibility_date = "2025-01-01"

[assets]
directory = "./build/web"
not_found_handling = "single-page-application"
```

### 3.1 Build Flutter Web

```powershell
cd flutter_application_1

flutter build web --release `
  --dart-define=API_BASE_URL=https://api.caloriesguard.com `
  --dart-define=SUPABASE_URL=<supabase-url> `
  --dart-define=SUPABASE_ANON_KEY=<supabase-anon-key> `
  --dart-define=GOOGLE_WEB_CLIENT_ID=<google-web-client-id> `
  --dart-define=APP_ENV=production
```

หมายเหตุ:

- `SUPABASE_ANON_KEY` ต้องส่งตอน build ไม่เช่นนั้น app จะแสดงหน้า missing config
- หลังแก้โค้ด Flutter ต้อง build ใหม่ก่อน `wrangler deploy`
- Cloudflare ไม่ได้ build Flutter ให้อัตโนมัติใน setup ปัจจุบัน

### 3.2 Deploy

```powershell
npx wrangler deploy
```

หลัง deploy จะได้ workers.dev URL เช่น:

`https://app-caloriesguard.<account>.workers.dev`

จากนั้นผูก custom domain เป็น:

`https://app.caloriesguard.com`

ถ้าต้อง login Wrangler:

```powershell
npx wrangler login
```

ถ้าใช้ CI/CD ให้ใช้ Cloudflare API token ที่มีสิทธิ์ deploy Worker/Pages เท่าที่จำเป็น

### 3.3 Smoke test

```powershell
Invoke-WebRequest https://app.caloriesguard.com -UseBasicParsing
Invoke-WebRequest https://app.caloriesguard.com/manifest.json -UseBasicParsing
```

ตรวจว่า:

- HTTP status เป็น 200
- `<title>` เป็น `Calories Guard`
- `manifest.name` เป็น `Calories Guard`
- favicon โหลดเป็นโลโก้แอป

ตรวจ cache-bust:

```powershell
Invoke-WebRequest "https://app.caloriesguard.com/?v=$(Get-Date -UFormat %s)" -UseBasicParsing
```

## 4. ตั้งค่า favicon และ PWA manifest

ไฟล์สำคัญ:

- `flutter_application_1/web/index.html`
- `flutter_application_1/web/manifest.json`
- `flutter_application_1/web/favicon-calories-guard.png`
- `flutter_application_1/web/icons/calories-guard-192.png`
- `flutter_application_1/web/icons/calories-guard-512.png`

ถ้า browser ยังเห็นชื่อหรือ favicon เก่า ให้:

- เปลี่ยนชื่อไฟล์ icon ใหม่
- เพิ่ม query version เช่น `?v=20260503`
- deploy ใหม่
- hard refresh หรือ clear site data

สำหรับ PWA ที่ติดตั้งลงเครื่องแล้ว บางครั้ง OS cache ชื่อ/ไอคอนแยกจาก browser ต้อง uninstall PWA แล้ว install ใหม่

ค่าปัจจุบันที่ต้องรักษา:

- `<title>` = `Calories Guard`
- `apple-mobile-web-app-title` = `Calories Guard`
- `manifest.name` = `Calories Guard`
- `manifest.short_name` = `Calories Guard`
- favicon ชี้ไป `favicon-calories-guard.png`

## 5. Deploy Admin Web

Admin Web อยู่ที่:

`admin-web/`

### 5.1 Build settings

ถ้าใช้ Cloudflare Pages:

| Setting | Value |
|---|---|
| Framework preset | `Vite` |
| Root directory | `admin-web` |
| Build command | `npm run build` |
| Build output directory | `dist` |

ถ้า deploy ด้วย Wrangler จากเครื่อง:

```powershell
cd admin-web
npm install
npm run build
npx wrangler deploy
```

ถ้าใช้ Cloudflare Pages ผ่าน GitHub ให้ตั้ง build settings ใน dashboard แทน

### 5.2 Environment Variables

ใส่ใน Cloudflare Pages/Worker settings:

| Key | Value |
|---|---|
| `VITE_API_BASE_URL` | `https://api.caloriesguard.com` |

ห้ามใส่ secret ฝั่ง backend เช่น `SUPABASE_SERVICE_ROLE_KEY` ใน Cloudflare frontend

ค่า `VITE_API_BASE_URL` ต้องมี protocol:

```env
VITE_API_BASE_URL=https://api.caloriesguard.com
```

อย่าใช้ค่าแบบไม่มี `https://`

### 5.3 Smoke test

1. เปิด `https://admin.caloriesguard.com`
2. Login ด้วย admin account
3. เปิด `/users` โดยตรงแล้ว refresh
4. ต้องไม่ 404

ถ้า refresh route แล้ว 404 ให้ตรวจ SPA fallback

ไฟล์ที่เกี่ยวข้อง:

- `admin-web/wrangler.toml`
- `admin-web/public/_headers`
- `admin-web/src/App.tsx`

## 6. ตั้งค่า API DNS ไป Railway

1. เปิด Cloudflare Dashboard
2. ไปที่ DNS
3. Add record
4. Type: `CNAME`
5. Name: `api`
6. Target: domain จาก Railway
7. Proxy status: ใช้ตาม setup SSL ของ Railway ถ้าเจอ SSL issue ให้ลอง DNS only
8. ไป Railway เพิ่ม custom domain `api.caloriesguard.com`
9. รอ certificate พร้อม
10. ทดสอบ:

```bash
curl https://api.caloriesguard.com/health
```

ผลลัพธ์ที่คาดหวัง:

```json
{"status":"ok","api_version":"2026.04"}
```

ถ้า Cloudflare แสดง error 525/526 ให้ตรวจ SSL mode และ certificate ของ Railway custom domain

## 6.1 ตั้งค่า Custom Domain สำหรับ Worker Static Assets

ใน Cloudflare:

1. ไปที่ Workers & Pages
2. เลือก Worker ของ Flutter เช่น `app-caloriesguard`
3. ไปที่ Settings -> Domains & Routes
4. เพิ่ม custom domain `app.caloriesguard.com`
5. รอ Cloudflare provision certificate
6. เปิด URL และตรวจ title/manifest

ทำแบบเดียวกันกับ Admin Web โดยใช้ `admin.caloriesguard.com`

## 7. Cache และการแก้ปัญหา

| อาการ | วิธีแก้ |
|---|---|
| หน้าเว็บยังเป็น version เก่า | hard refresh, clear cache, ตรวจ deploy version |
| PWA icon ไม่เปลี่ยน | เปลี่ยนชื่อไฟล์ icon และ manifest query version |
| เปิด path ลึกแล้ว 404 | ตั้ง `not_found_handling = "single-page-application"` |
| Admin เรียก API ไม่ได้ | ตรวจ `VITE_API_BASE_URL` และ CORS backend |
| API custom domain SSL error | ตรวจ Cloudflare DNS + Railway custom domain |

## 8. Release checklist สำหรับ Cloudflare

Flutter Web:

- `flutter test` ผ่าน
- `flutter build web --release` ผ่าน
- `npx wrangler deploy` สำเร็จ
- `https://app.caloriesguard.com` ตอบ 200
- title/manifest/favicon ถูกต้อง
- login ได้
- refresh path หลักแล้วไม่ blank

Admin Web:

- `npm run build` ผ่าน
- deploy สำเร็จ
- `https://admin.caloriesguard.com` ตอบ 200
- login admin ได้
- refresh `/users` แล้วไม่ 404
- API requests ไป `https://api.caloriesguard.com`

DNS/API:

- `api.caloriesguard.com/health` ตอบ 200
- CORS ไม่ block จาก `app` และ `admin`

## 9. อ้างอิง

- Cloudflare Workers Static Assets: https://developers.cloudflare.com/workers/static-assets/
- Wrangler Configuration: https://developers.cloudflare.com/workers/wrangler/configuration/
- Wrangler Deploy Commands: https://developers.cloudflare.com/workers/wrangler/commands/workers/
