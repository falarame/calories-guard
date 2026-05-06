# คู่มือการตั้งค่า Supabase สำหรับ Calories Guard

คู่มือนี้ครอบคลุมการตั้งค่า Supabase PostgreSQL, Auth, API keys, Storage, migrations และ admin user

## 1. บทบาทของ Supabase ในระบบ

Supabase ใช้สำหรับ:

- PostgreSQL database
- Supabase Auth สำหรับสมัครสมาชิก login และ email confirmation
- Storage สำหรับรูปอาหาร
- Dashboard สำหรับตรวจ logs/query เบื้องต้น

Backend ยังเป็นตัวกลางหลักในการเข้าถึงข้อมูลธุรกิจ ส่วน mobile/web app ใช้ Supabase SDK เพื่อ auth และส่ง token ให้ backend

สรุปการใช้งาน:

| ส่วน | ใช้ Supabase อย่างไร |
|---|---|
| Auth | สมัครสมาชิก, login, email OTP, Google OAuth |
| PostgreSQL | เก็บข้อมูลผู้ใช้ อาหาร มื้ออาหาร น้ำ กิจกรรม น้ำหนัก |
| Storage | เก็บรูปอาหารและรูปที่ backend upload |
| Dashboard | ตรวจ auth users, SQL, logs และ storage |

## 2. สร้าง Project

1. เปิด Supabase Dashboard
2. สร้าง Project ใหม่
3. ตั้ง region ให้เหมาะกับผู้ใช้หลัก
4. ตั้ง database password และเก็บไว้อย่างปลอดภัย
5. รอ project provisioning เสร็จ

คำแนะนำ:

- เลือก region ใกล้ผู้ใช้หลักที่สุดเท่าที่เหมาะสม
- ตั้ง DB password แบบสุ่มและยาว
- เก็บ password ใน secret manager หรือ Railway Variables
- แยก production และ staging เป็นคนละ Supabase project ถ้าเป็นไปได้

## 3. เก็บค่าที่ต้องใช้

ไปที่ Project Settings แล้วเก็บค่าเหล่านี้

| ค่า | ใช้ที่ไหน |
|---|---|
| Project URL | Flutter, backend |
| anon/publishable key | Flutter, backend fallback auth |
| service role key | backend เท่านั้น |
| JWT Secret | backend เท่านั้น |
| DB host/user/password/port | Railway backend |

ข้อควรระวัง:

- anon key ใส่ใน client ได้
- service role key ห้ามใส่ใน client
- JWT Secret ห้ามใส่ใน client
- DB password ห้าม commit ลง repo

ตำแหน่งใน Supabase Dashboard อาจเปลี่ยนตาม UI แต่โดยทั่วไป:

- Project URL และ API keys อยู่ใน Project Settings -> API
- JWT Secret อยู่ใน Project Settings -> API หรือ JWT settings
- Database host/pooler อยู่ใน Project Settings -> Database
- Redirect URLs อยู่ใน Authentication -> URL Configuration

## 4. ตั้งค่า Database

### 4.1 Schema

ระบบใช้ schema หลักชื่อ `cleangoal` และมีตารางสำคัญ เช่น

- `users`
- `roles`
- `foods`
- `meals`
- `detail_items`
- `water_logs`
- `exercise_logs`
- `weight_logs`
- `temp_food`
- `verified_food`
- `food_regional_name_submissions`

ดูรายละเอียด schema ได้ที่:

- `docs/DATA_DICTIONARY_FULL.md`
- `docs/SCHEMA_DIAGRAM.md`

ตาราง auth ของ Supabase (`auth.users`) แยกจากตาราง business user (`cleangoal.users`/`users`) ของแอป ระบบจึงต้อง sync ระหว่าง Supabase Auth UID/email กับ user row ของแอปผ่าน backend

### 4.2 Apply migrations

ใช้ SQL Editor หรือ script:

```bash
cd backend
python run_migrations.py
```

ก่อนรันกับ production ให้ backup หรือทดสอบกับ staging ก่อน

ลำดับปฏิบัติที่แนะนำ:

1. อ่าน migration SQL ก่อนรัน
2. รันบน staging
3. ทดสอบ login/register/meal flow
4. backup production
5. รันบน production
6. ตรวจ `schema_migrations`
7. ตรวจ endpoint สำคัญ

### 4.3 ตรวจ schema migrations

```sql
SELECT *
FROM cleangoal.schema_migrations
ORDER BY version;
```

ถ้าตาราง `schema_migrations` อยู่ schema อื่น ให้ปรับ query ตาม schema จริง

## 5. ตั้งค่า Auth

### 5.1 Email provider

ไปที่ Authentication -> Providers แล้วเปิด Email

Calories Guard ใช้ Supabase Auth เป็น source of truth สำหรับ email confirmation:

- สมัครสมาชิกผ่าน `_supabase.auth.signUp`
- Supabase ส่ง OTP/email confirmation
- Flutter verify OTP ด้วย Supabase
- Backend sync `users.is_email_verified = TRUE`

อย่าส่ง OTP ยืนยันอีเมลซ้ำจาก backend เพื่อหลีกเลี่ยงปัญหา `Email not confirmed`

Flow ปัจจุบัน:

1. Flutter เรียก Supabase `signUp`
2. Supabase ส่ง OTP/email confirmation
3. Flutter เรียก Supabase `verifyOTP`
4. ถ้า verify สำเร็จ Flutter เรียก backend `/verify-email`
5. Backend mark `users.is_email_verified = TRUE`
6. Login ครั้งต่อไปผ่าน Supabase และ backend ได้

ถ้าใช้ OTP จากระบบอื่นที่ไม่ใช่ Supabase จะทำให้ Supabase ยังถือว่า email ไม่ confirmed

### 5.2 URL Configuration

ไปที่ Authentication -> URL Configuration

ค่าแนะนำ:

| Field | Value |
|---|---|
| Site URL | `https://app.caloriesguard.com` |
| Redirect URL | `https://app.caloriesguard.com/**` |
| Redirect URL | `https://admin.caloriesguard.com/**` ถ้าจำเป็น |
| Redirect URL | `com.caloriesguard.app://login-callback/**` |

Mobile deep link ที่ใช้ใน Flutter:

`com.caloriesguard.app://login-callback`

หลักการ:

- URL ต้องตรงกับ `redirectTo` ที่ client ส่ง
- OAuth provider เช่น Google ต้องมี callback ไป Supabase: `https://<project-ref>.supabase.co/auth/v1/callback`
- production, staging และ local ควรแยก URL ให้ชัด

### 5.3 Email Templates

ไปที่ Authentication -> Email Templates

ควรแก้ template:

- Confirm signup
- Magic Link ถ้าใช้
- Reset Password

เนื้อหาควรใช้ชื่อ `Calories Guard` และภาษาไทย/อังกฤษตามผู้ใช้

ตัวอย่างหัวข้อ:

- Confirm signup: `ยืนยันอีเมลของคุณ - Calories Guard`
- Reset Password: `รีเซ็ตรหัสผ่าน - Calories Guard`

ควรตรวจว่า template ไม่ใช้ชื่อเก่า เช่น `Calorie Guard`

### 5.4 Google OAuth

1. เปิด Google Cloud Console
2. สร้าง OAuth Client ID แบบ Web application
3. Authorized redirect URI:

```text
https://<project-ref>.supabase.co/auth/v1/callback
```

4. นำ Client ID และ Client Secret ไปใส่ใน Supabase -> Authentication -> Providers -> Google
5. ฝั่ง Flutter build ต้องส่ง `GOOGLE_WEB_CLIENT_ID` ผ่าน `--dart-define`

หลังตั้งค่า:

1. ทดสอบ login Google บน web
2. ทดสอบ login Google บน Android ถ้าเปิดใช้
3. ตรวจว่า backend สร้าง/อัปเดต user row ผ่าน `/social-login`

## 6. ตั้งค่า Storage

ใช้เก็บรูปอาหาร

Bucket ที่ควรมี:

- `food-images` หรือ bucket ตามที่ backend config ใช้งาน

แนวทาง:

- Public read สำหรับรูปอาหารที่แสดงในแอป
- Write ผ่าน backend เท่านั้น
- หลีกเลี่ยงให้ client เขียนลง storage โดยตรงถ้าไม่จำเป็น

ตรวจ backend env:

- `SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`

ถ้า bucket เป็น public:

- ผู้ใช้ที่มี URL สามารถเปิดดูไฟล์ได้
- เหมาะกับรูปอาหารทั่วไปที่ไม่อ่อนไหว

ถ้า bucket เป็น private:

- ต้องมี signed URL หรือ backend proxy
- ต้องตั้ง RLS/policy ให้ละเอียดขึ้น

สำหรับ Calories Guard ปัจจุบัน แนะนำให้รูปอาหาร public read และ upload ผ่าน backend เท่านั้น

## 7. สร้าง Admin User

หลังผู้ใช้สมัครและยืนยันอีเมลแล้ว ให้ปรับ role:

```sql
UPDATE users
SET role_id = 1
WHERE LOWER(email) = LOWER('admin@example.com');
```

ตรวจสอบ:

```sql
SELECT user_id, email, username, role_id, is_email_verified
FROM users
WHERE LOWER(email) = LOWER('admin@example.com');
```

ขั้นตอนครบถ้วน:

1. ให้ผู้ใช้สมัครผ่านแอป
2. ยืนยันอีเมลให้เรียบร้อย
3. รัน SQL ปรับ `role_id = 1`
4. ให้ผู้ใช้ออกจากระบบและ login ใหม่
5. เปิด `https://admin.caloriesguard.com`
6. ตรวจว่าสามารถเข้า Dashboard ได้

## 8. Row-Level Security

โปรเจกต์นี้ใช้ backend เป็น data access layer หลัก

แนวทาง:

- เปิด RLS บนตาราง user-owned เพื่อกัน client ใช้ anon/authenticated key อ่านข้อมูลตรง
- Backend ใช้ DB credentials/service role ตามที่ออกแบบ
- ถ้าในอนาคตให้ client เขียน/อ่าน PostgREST โดยตรง ต้องเพิ่ม policy ที่ผูกกับ `auth.uid()`

ดูรายละเอียดได้ที่:

- `backend/migrations/v15_c_rls_policies.sql`
- `docs/SUPABASE_CLEANGOAL_SCHEMA_REVIEW.md`

หลักปฏิบัติ:

- เปิด RLS บนตารางที่มีข้อมูลผู้ใช้
- อย่าให้ anon/authenticated role อ่านข้อมูลส่วนตัวโดยตรง
- ใช้ backend เป็นตัว enforce business rules
- ถ้าจำเป็นต้องเปิด direct client access ให้เขียน policy ที่อ้าง `auth.uid()` และทดสอบด้วย user จริง

## 8.1 API keys และ secret rotation

ควร rotate เมื่อ:

- มี secret หลุดในแชต/commit/log
- มีคนออกจากทีมที่เคยเข้าถึง secret
- สงสัยว่ามีการใช้งานผิดปกติ

หลัง rotate:

1. อัปเดต Railway Variables
2. อัปเดต local `.env`
3. Rebuild Flutter web/APK ถ้าเปลี่ยน anon key
4. Redeploy backend ถ้าเปลี่ยน JWT/service role/DB password
5. ทดสอบ login/register/upload

## 9. Backup และ Restore

ก่อน migration สำคัญ:

1. Export backup หรือใช้ Supabase backup feature ตาม plan
2. ทดสอบ migration ใน staging
3. จดเวลาที่ deploy
4. เตรียม rollback SQL ถ้ามี

ข้อมูลที่ควร backup ก่อน migration:

- schema
- ตาราง `users`
- ตารางอาหารและ recipe
- logs สำคัญที่ใช้ตรวจย้อนหลัง

ถ้าใช้ Supabase plan ที่มี PITR ให้จดเวลา deploy/migration เพื่อ restore ได้แม่นขึ้น

## 9.1 Monitoring ใน Supabase

ตรวจประจำ:

- Auth logs: login/signup failures
- Database logs: query error, connection error
- Storage logs: upload/download error
- Database size และ connection usage
- Slow query ถ้ามี traffic เพิ่มขึ้น

## 10. Troubleshooting

| อาการ | วิธีตรวจ | วิธีแก้ |
|---|---|---|
| Login ขึ้น `Email not confirmed` | ดู auth user ใน Supabase | ให้ผู้ใช้ verify OTP จาก Supabase ล่าสุด |
| Backend verify token ไม่ผ่าน | ตรวจ `SUPABASE_JWT_SECRET` | ตั้งค่าให้ตรง project |
| DB connect ไม่ได้ | ตรวจ connection string/pooler | ใช้ host/user/port ให้ถูก |
| รูปอาหาร upload ไม่ได้ | ตรวจ bucket และ service role key | สร้าง bucket/ปรับ policy |
| Admin login แล้ว 403 | ตรวจ `users.role_id` | ตั้ง `role_id = 1` |
| redirect OAuth ไม่กลับแอป | ตรวจ Redirect URLs | เพิ่ม URL ให้ตรงกับ `redirectTo` |
| Email OTP ไม่ส่ง | ตรวจ Auth email settings/logs | ตรวจ SMTP/provider/template/rate limit |
| App สมัครแล้วมีเมลซ้ำ | ตรวจ backend email flow | ให้ Supabase เป็น source of truth สำหรับ verification |
| RLS block query | Supabase SQL/logs | ตรวจ policy หรือให้ backend query แทน |
| Storage public URL เปิดไม่ได้ | ตรวจ bucket public flag | ตั้ง public read หรือใช้ signed URL |

## 11. Checklist ตั้งค่า Supabase

- Project สร้างแล้ว
- เก็บ Project URL
- เก็บ anon key
- เก็บ service role key อย่างปลอดภัย
- เก็บ JWT Secret อย่างปลอดภัย
- Database password เก็บใน secret manager
- Schema/migrations apply ครบ
- Auth Email provider เปิด
- Site URL ตั้งเป็น `https://app.caloriesguard.com`
- Redirect URLs ครบ
- Email templates ใช้ชื่อ Calories Guard
- Google OAuth ตั้ง callback ถูกต้อง ถ้าใช้
- Storage bucket สร้างแล้ว
- RLS/policies ตรวจแล้ว
- Admin user ถูก promote แล้ว
- Register/login/verify ทดสอบผ่าน

## 12. อ้างอิง

- Supabase API Keys: https://supabase.com/docs/guides/getting-started/api-keys
- Supabase Auth Redirect URLs: https://supabase.com/docs/guides/auth/redirect-urls
- Supabase Auth Email Templates: https://supabase.com/docs/guides/auth/auth-email-templates
- Supabase Storage Buckets: https://supabase.com/docs/guides/storage/buckets/fundamentals
