# คู่มือการตั้งค่า Railway สำหรับ Calories Guard Backend

คู่มือนี้สำหรับ deploy FastAPI backend (`backend/`) ขึ้น Railway

## 1. ภาพรวม

Backend ทำหน้าที่:

- รับ request จาก Flutter app และ Admin Web
- ตรวจ JWT จาก Supabase หรือ backend-issued token
- เชื่อมต่อ PostgreSQL บน Supabase
- เรียก AI provider สำหรับ chat/food estimation
- อัปโหลดรูปไป Supabase Storage

Production API:

`https://api.caloriesguard.com`

## 2. สิ่งที่ต้องมี

- Railway account
- GitHub repository ที่ Railway อ่านได้
- Supabase project ที่ตั้งค่า DB/Auth/Storage แล้ว
- ค่า environment variables จาก Supabase
- Domain `api.caloriesguard.com` บน Cloudflare

## 2.1 สถาปัตยกรรมที่ Railway รับผิดชอบ

Railway host เฉพาะ backend API ไม่ได้ host Flutter web หรือ Admin Web

Flow:

1. Flutter/Admin ส่ง request ไป `https://api.caloriesguard.com`
2. FastAPI ตรวจ token ด้วย `SUPABASE_JWT_SECRET` หรือ fallback ไป Supabase Auth API
3. Backend เชื่อม Supabase PostgreSQL
4. Backend อัปโหลด/อ่านรูปผ่าน Supabase Storage
5. Backend เรียก AI provider ถ้าเปิด `AI_ENABLED`

## 3. เตรียม repository

ไฟล์สำคัญ:

- `backend/Dockerfile`
- `backend/railway.json`
- `backend/requirements.txt`
- `backend/main.py`

ตรวจว่า health endpoint ทำงาน:

```bash
cd backend
python -m pytest tests/test_health.py
```

ตรวจ build context:

- Root Directory ใน Railway ต้องเป็น `backend`
- `backend/Dockerfile` ต้องอยู่ใน root ของ service
- `backend/railway.json` ต้องมี `healthcheckPath` เป็น `/health`

ถ้า deploy จาก project root โดยไม่ตั้ง root directory อาจ build ไม่เจอ Dockerfile หรือ context ผิด

## 4. สร้าง Railway service

1. เปิด Railway Dashboard
2. เลือก `New Project`
3. เลือก `Deploy from GitHub repo`
4. เลือก repository `falarame/calories-guard`
5. ตั้ง Root Directory เป็น `backend`
6. Railway จะ detect `Dockerfile`
7. สร้าง service แล้วรอ build ครั้งแรก

หมายเหตุ: ถ้า Railway หา repo ไม่เจอ ให้ตรวจ GitHub App installation ว่า Railway ได้รับสิทธิ์อ่าน repo แล้ว

## 4.1 ตั้งค่า branch deploy

แนวทาง production:

- Branch: `main`
- Auto deploy: เปิดได้ถ้าทีมพร้อม
- ถ้าต้องควบคุม release ให้ปิด auto deploy แล้วกด deploy manual จาก Railway หรือ GitHub Actions

แนวทาง staging:

- สร้าง Railway service แยก เช่น `calories-guard-api-staging`
- ใช้ Supabase staging project
- ใช้ domain เช่น `staging-api.caloriesguard.com`
- ห้ามชี้ staging ไป production DB

## 5. ตั้งค่า Environment Variables

เปิด Railway service -> `Variables` แล้วเพิ่มค่าต่อไปนี้

### 5.1 Core

| Key | ตัวอย่าง | หมายเหตุ |
|---|---|---|
| `APP_ENV` | `production` | ใช้แยก environment |
| `DB_MODE` | `supabase` | ให้ backend ใช้ Supabase DB |
| `ALLOWED_ORIGINS` | `https://app.caloriesguard.com,https://admin.caloriesguard.com` | CORS allowlist |

ควรใส่ origin ให้ครบ:

```env
ALLOWED_ORIGINS=https://app.caloriesguard.com,https://admin.caloriesguard.com,https://caloriesguard.com
```

ถ้าทดสอบ local เพิ่ม:

```env
ALLOWED_ORIGINS=http://localhost:3000,http://localhost:5173,http://localhost:8000,https://app.caloriesguard.com,https://admin.caloriesguard.com
```

### 5.2 Database

ใช้ค่าจาก Supabase Database Settings หรือ Connection Pooler

| Key | ตัวอย่าง |
|---|---|
| `SUPABASE_HOST` หรือ `DB_HOST` | `aws-1-...pooler.supabase.com` |
| `SUPABASE_NAME` หรือ `DB_NAME` | `postgres` |
| `SUPABASE_USER` หรือ `DB_USER` | `postgres.<project-ref>` |
| `SUPABASE_PASSWORD` หรือ `DB_PASSWORD` | DB password |
| `SUPABASE_PORT` หรือ `DB_PORT` | `5432` หรือ `6543` |

ถ้าใช้ `DATABASE_URL` หรือ `SUPABASE_DB_URL` ให้ใส่ `sslmode=require`

คำแนะนำการเลือก port:

- `5432`: session/direct connection เหมาะกับงาน migration หรือ connection ยาว
- `6543`: transaction pooler เหมาะกับ serverless/connection สั้น

ถ้า Railway log มี error connection limit ให้เปลี่ยนไปใช้ pooler และตรวจ max connections

### 5.3 Supabase Auth

| Key | ค่า |
|---|---|
| `SUPABASE_URL` | Project URL |
| `SUPABASE_PROJECT_URL` | ค่าเดียวกับ `SUPABASE_URL` |
| `SUPABASE_ANON_KEY` | anon/publishable key |
| `SUPABASE_SERVICE_ROLE_KEY` | service role key |
| `SUPABASE_JWT_SECRET` | JWT Secret |

ข้อควรระวัง:

- `SUPABASE_SERVICE_ROLE_KEY` และ `SUPABASE_JWT_SECRET` เป็น secret ห้ามใส่ใน frontend
- ถ้าเปลี่ยน `SUPABASE_JWT_SECRET` ต้อง redeploy backend และอาจกระทบ token เก่า

### 5.4 AI

| Key | ตัวอย่าง |
|---|---|
| `AI_ENABLED` | `true` |
| `LLM_PROVIDER` | `ollama`, `gemini`, หรือ provider ที่รองรับ |
| `OLLAMA_BASE_URL` | URL ที่ Railway เข้าถึงได้ |
| `OLLAMA_API_KEY` | ถ้ามี proxy/auth |
| `OLLAMA_MODEL` | model tag |

ถ้าไม่ต้องการเปิด AI ชั่วคราว:

```env
AI_ENABLED=false
```

ถ้าเปิด AI แล้ว response ช้า ให้เพิ่ม timeout:

```env
OLLAMA_TIMEOUT=120
```

### 5.5 Email และ Monitoring

| Key | หมายเหตุ |
|---|---|
| `SMTP_SERVER`, `SMTP_PORT`, `SMTP_USERNAME`, `SMTP_PASSWORD` | ใช้เฉพาะ email ที่ backend ส่งเอง |
| `SENDGRID_API_KEY` หรือ `RESEND_API_KEY` | optional |
| `SENTRY_DSN` | optional สำหรับ error monitoring |

## 6. ตั้งค่า Health Check

ใน Railway service:

1. เปิด Settings
2. ตั้ง Health Check Path เป็น `/health`
3. Deploy ใหม่

ตรวจด้วย:

```bash
curl https://api.caloriesguard.com/health
```

ควรได้:

```json
{"status":"ok","api_version":"2026.04"}
```

ตามพฤติกรรม Railway health check หาก endpoint ไม่ตอบ HTTP 200 ภายใน timeout deployment จะถูกถือว่าไม่ผ่าน ดังนั้น `/health` ต้องไม่พึ่ง DB/AI หนักเกินไป

## 7. ตั้งค่า Custom Domain

1. Railway -> Service -> Settings -> Networking
2. เพิ่ม custom domain `api.caloriesguard.com`
3. Railway จะแสดง target CNAME
4. ไปที่ Cloudflare DNS แล้วสร้าง CNAME `api` ชี้ไป target ของ Railway
5. รอ SSL provisioning
6. ทดสอบ `/health`

## 8. Deploy และ Redeploy

Railway deploy ได้ 2 แบบ

- Push ไป `main` ถ้าเชื่อม GitHub auto deploy แล้ว
- กด Redeploy ใน Railway Dashboard

หรือใช้ deploy webhook/GitHub Actions ถ้าตั้ง secret ไว้:

- `RAILWAY_STAGING_WEBHOOK`
- `RAILWAY_PROD_WEBHOOK`
- `STAGING_URL`
- `PROD_URL`

หลัง deploy ให้ตรวจ:

```bash
curl https://api.caloriesguard.com/health
curl https://api.caloriesguard.com/foods?q=ข้าว
```

Smoke test เพิ่มเติม:

```bash
curl https://api.caloriesguard.com/
curl https://api.caloriesguard.com/debug-auth
```

หมายเหตุ: `/debug-auth` ควรจำกัดหรือปิดก่อน public launch ถ้าไม่จำเป็น

## 8.1 Deploy checklist

ก่อน deploy:

- code อยู่บน branch ที่ถูกต้อง
- tests สำคัญผ่าน
- env vars ครบ
- Supabase project พร้อม
- migration ที่จำเป็นถูก apply แล้ว
- domain/API URL ถูกต้อง

หลัง deploy:

- `/health` ตอบ 200
- login จาก Flutter/Web ได้
- admin login ได้
- protected endpoint ไม่ 401/403 ผิดปกติ
- Railway logs ไม่มี crash loop
- Sentry ไม่เกิด error spike

## 9. Rollback

ถ้า deploy ใหม่มีปัญหา:

1. เปิด Railway service
2. ไปที่ Deployments
3. เลือก deployment ก่อนหน้าที่ใช้งานได้
4. กด Redeploy/Rollback ตาม UI
5. ตรวจ `/health`

Rollback แบบใช้ Git:

1. หา commit ที่ใช้งานได้
2. revert commit ที่มีปัญหา หรือ deploy commit เก่า
3. push/redeploy
4. ตรวจ DB migration ว่ามีการเปลี่ยน schema ที่ต้อง rollback แยกหรือไม่

ข้อควรระวัง: ถ้า deploy มี migration ที่เปลี่ยน schema/data แล้ว rollback code อย่างเดียวอาจไม่พอ

## 10. Troubleshooting

| อาการ | วิธีตรวจ | วิธีแก้ |
|---|---|---|
| Build fail | ดู Railway build logs | ตรวจ `requirements.txt`, Dockerfile |
| App crash | ดู deploy logs | ตรวจ env vars และ stack trace |
| `/health` ไม่ผ่าน | curl health endpoint | ตรวจ port binding และ `backend/main.py` |
| DB connect ไม่ได้ | ดู error psycopg2 | ตรวจ host/user/password/port/ssl |
| Login fail หลัง deploy | ดู Supabase/JWT env | ตรวจ `SUPABASE_JWT_SECRET`, `SUPABASE_URL`, `SUPABASE_ANON_KEY` |
| CORS error | Browser devtools | เพิ่ม origin ใน `ALLOWED_ORIGINS` |
| Deploy ค้าง pending | Railway deployment page | ดู build/runtime logs |
| API 502/503 | Railway logs + healthcheck | ตรวจ port `$PORT` และ process start |
| Upload รูปไม่ได้ | backend logs | ตรวจ `SUPABASE_SERVICE_ROLE_KEY`, bucket, policy |
| AI chat timeout | logs ของ backend/AI proxy | ตรวจ `OLLAMA_BASE_URL`, `OLLAMA_TIMEOUT`, model |

## 11. คำสั่งที่ใช้บ่อย

```bash
# local backend tests
cd backend
python -m pytest

# health check production
curl https://api.caloriesguard.com/health

# ดู commit ล่าสุด
git log -1 --oneline
```

## 12. Security checklist

- ไม่ใส่ secret ใน Dockerfile
- ไม่ใส่ secret ใน frontend build
- Railway variables ต้องจำกัดเฉพาะ service ที่ต้องใช้
- เปลี่ยน DB password/service role key ถ้ารั่ว
- จำกัด CORS เฉพาะ domain จริง
- ตรวจ log ไม่ให้พิมพ์ token/password
- เปิด least privilege สำหรับบัญชี GitHub/Railway

## 13. อ้างอิง

- Railway Healthchecks: https://docs.railway.com/reference/healthchecks
- Railway Variables: https://docs.railway.com/reference/variables
- Railway Build and Start Commands: https://docs.railway.com/reference/build-and-start-commands
