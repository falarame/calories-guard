# ชุดคู่มือ Calories Guard

เอกสารชุดนี้เป็นคู่มือฉบับใช้งานจริงสำหรับระบบ Calories Guard ครอบคลุมทั้งผู้ใช้ทั่วไป แอดมิน และผู้ดูแลระบบ deploy บน Railway, Cloudflare และ Supabase

วันที่จัดทำ/ปรับปรุง: 2026-05-03

ขอบเขตของเอกสารยึดตามโค้ดใน repository ปัจจุบัน ได้แก่ Flutter app (`flutter_application_1/`), Admin Web (`admin-web/`), FastAPI backend (`backend/`) และเอกสาร deployment ที่มีอยู่ใน `docs/`

## รายการคู่มือ

| ไฟล์ | สำหรับ | เนื้อหา |
|---|---|---|
| [USER_APP_MANUAL.md](USER_APP_MANUAL.md) | ผู้ใช้แอป | สมัครสมาชิก ยืนยันอีเมล ตั้งค่าเป้าหมาย บันทึกอาหาร น้ำ กิจกรรม ดูโปรไฟล์ และใช้งาน AI |
| [ADMIN_MANUAL.md](ADMIN_MANUAL.md) | แอดมิน | เข้าระบบ จัดการอาหาร อนุมัติ Temp Foods ตรวจชื่ออาหารท้องถิ่น และดูผู้ใช้ |
| [RAILWAY_SETUP_MANUAL.md](RAILWAY_SETUP_MANUAL.md) | ผู้ดูแล backend | ตั้งค่า Railway สำหรับ FastAPI backend, environment variables, domain, health check |
| [CLOUDFLARE_SETUP_MANUAL.md](CLOUDFLARE_SETUP_MANUAL.md) | ผู้ดูแล frontend/DNS | ตั้งค่า Cloudflare Workers/Pages, custom domains, DNS, deploy Flutter web และ admin web |
| [SUPABASE_SETUP_MANUAL.md](SUPABASE_SETUP_MANUAL.md) | ผู้ดูแลฐานข้อมูล/Auth | ตั้งค่า Supabase DB, Auth, redirect URLs, API keys, Storage, migrations และ admin user |

## URL Production ปัจจุบัน

| ระบบ | URL |
|---|---|
| User Web/PWA | `https://app.caloriesguard.com` |
| Backend API | `https://api.caloriesguard.com` |
| Admin Web | `https://admin.caloriesguard.com` |
| Supabase Project URL | ดูค่าจาก `.env` หรือ Supabase Dashboard |

## หมายเหตุด้านความปลอดภัย

- ห้าม commit ค่า secret เช่น `SUPABASE_SERVICE_ROLE_KEY`, `SUPABASE_JWT_SECRET`, DB password, SMTP password
- ให้เก็บ secret ไว้ใน Railway Variables, Cloudflare environment variables, Supabase Dashboard หรือ secret manager เท่านั้น
- ถ้าพบว่า secret เคยหลุดในแชต/เอกสาร/commit ให้ rotate ทันที
- ค่า `SUPABASE_ANON_KEY` สามารถอยู่ฝั่ง client ได้ แต่ไม่ควรสับสนกับ `SUPABASE_SERVICE_ROLE_KEY`
- ก่อนส่งต่อเอกสารภายนอกทีม ให้ตรวจว่าไม่มี screenshot หรือข้อความที่มี secret จริงติดไปด้วย

## วิธีใช้งานเอกสารชุดนี้

1. เริ่มจากอ่านคู่มือที่ตรงกับบทบาทของตนเอง
2. ถ้าเป็นผู้ดูแลระบบ ให้ตั้งค่า Supabase ก่อน Railway และ Cloudflare เพราะ backend/frontend ต้องใช้ค่าจาก Supabase
3. หลัง deploy ทุกครั้ง ให้ทำ smoke test ตาม checklist ในคู่มือ Railway และ Cloudflare
4. ถ้าเกิดปัญหา auth/login ให้ตรวจ Supabase Auth, backend env และ CORS ตามลำดับ

## ลำดับการตั้งค่าระบบจากศูนย์

1. สร้าง Supabase project และ apply database schema/migrations
2. ตั้งค่า Supabase Auth, redirect URLs, email templates และ storage bucket
3. Deploy backend บน Railway พร้อม environment variables
4. ผูก `api.caloriesguard.com` เข้ากับ Railway
5. Build และ deploy Flutter Web/PWA ไป Cloudflare
6. Build และ deploy Admin Web ไป Cloudflare
7. สร้าง/โปรโมต admin user
8. ทดสอบ user flow และ admin flow แบบ end-to-end

## Definition of Done สำหรับเอกสารชุดนี้

ถือว่าระบบพร้อมใช้งานเมื่อผ่านรายการต่อไปนี้:

- ผู้ใช้สมัคร ยืนยันอีเมล login และเข้า onboarding ได้
- ผู้ใช้บันทึกอาหาร น้ำ กิจกรรม และดูหน้าแรกได้
- Admin login ได้ด้วยบัญชี `role_id = 1`
- Admin จัดการอาหาร ตรวจ temp food และตรวจ regional names ได้
- `https://api.caloriesguard.com/health` ตอบ `200`
- `https://app.caloriesguard.com` เปิดได้และแสดงชื่อ Calories Guard ถูกต้อง
- `https://admin.caloriesguard.com` เปิดได้และ refresh deep link ไม่ 404
- Supabase Auth ส่งอีเมลยืนยันภายใต้ชื่อ Calories Guard
- Storage bucket สำหรับรูปอาหารใช้งานได้

## แหล่งอ้างอิงหลัก

- Railway Docs: https://docs.railway.com
- Cloudflare Workers Docs: https://developers.cloudflare.com/workers
- Supabase Docs: https://supabase.com/docs
