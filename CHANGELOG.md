# Calories Guard — Changelog

---

## [Unreleased] — 2026-05-06

### Consent Flow (PDPA)

- **ย้าย DataConsentScreen ไปท้าย onboarding**: ผู้ใช้ใหม่จะเห็น consent หลังเลือกระยะเวลาเป้าหมาย (DurationSliderScreen → DataConsentScreen → MainScreen) ไม่ใช่ก่อน onboarding
- **แก้ Progress bar**: consent screen แสดง progress 100% (เดิม 12.5%) เพราะเป็นขั้นตอนสุดท้าย
- **ผู้ใช้เดิม** ที่ onboarding เสร็จแล้วแต่ยังไม่ยอมรับ consent ยังถูกถามก่อนเข้าแอพเหมือนเดิม (via `routeAfterAuth`)

ไฟล์ที่แก้ไข:
- `lib/login_register/screens/target_weight_screen.dart` — เปลี่ยน navigation ให้ผ่าน `routeAfterAuth`
- `lib/login_register/screens/data_consent_screen.dart` — progress bar = 1.0

---

### Semantic Color System

#### หน้าโปรไฟล์ (`profile_screen.dart`)

Stats row ใช้สีที่มีความหมายชัดเจน:

| ค่าที่แสดง | สีเดิม | สีใหม่ | เหตุผล |
|---|---|---|---|
| น้ำหนักปัจจุบัน | เขียว (#27AE60) | น้ำเงิน (#3B82F6) | ข้อมูลเชิงสถิติ (neutral fact) |
| เป้าหมาย | แดง (#E74C3C) | เขียวแบรนด์ (#628141) | เป้าหมายเชิงบวก (aspiration) |
| วันที่เหลือ | น้ำเงิน (#3498DB) | แบบ conditional | > 30 วัน = เขียว, 14–30 = amber, < 14 = orange, ผ่านแล้ว = gray |

#### หน้าเมนูอาหาร / โภชนาการ (`recommend_food_screen.dart`)

สีของ macro ทั้ง 3 ตัวปรับให้สื่อความหมาย:

| Macro | สีเดิม | สีใหม่ | สื่อถึง |
|---|---|---|---|
| โปรตีน | แดง #E53935 | น้ำเงิน #2563EB | กล้ามเนื้อ/ความแข็งแรง |
| คาร์บ | น้ำเงิน #1E88E5 | อำพัน #D97706 | พลังงาน/ธัญพืช |
| ไขมัน | อำพัน #F59E0B | ส้ม #EA580C | ความอบอุ่น/ไขมัน |

ก่อนหน้านี้ โปรตีนใช้สีแดงซึ่งดูเหมือน error state และคาร์บใช้น้ำเงินที่ซ้ำกับสีข้อมูล

#### หน้าสูตรคำนวณ (`tdee_formula_screen.dart`)

ลดสีสันที่ไม่มีความหมาย ให้สอดคล้องกับ design system:

| Step | สีเดิม | สีใหม่ | เหตุผล |
|---|---|---|---|
| Step 1 BMR | ส้มสด #FF7043 | น้ำเงิน #0369A1 | physiological baseline (clinical tone) |
| Step 2 TDEE | ม่วง #8E24AA | ม่วง #7C3AED | ปรับให้เป็น violet ในระบบ Tailwind |
| Step 3 Goal | goal color | goal color (ไม่เปลี่ยน) | ยังคงสีตามเป้าหมาย |
| Step 4 Target | เขียว | เขียว (ไม่เปลี่ยน) | brand color |
| Macro chips | แดง/น้ำเงิน/อำพัน | น้ำเงิน/อำพัน/ส้ม | สอดคล้องกับ macro system |
| Calorie deficit | แดง | ส้ม #EA580C | deficit ≠ error |
| Calorie surplus | น้ำเงิน | น้ำเงิน #2563EB | ยังคงเดิม |
| Warning banner | อำพัน #F59E0B | amber-700 #B45309 | แยกออกจาก carbs color |

---

### OTP ผ่านเบอร์โทรศัพท์

ไฟล์ใหม่: `lib/login_register/screens/phone_otp_screen.dart`

**Feature:**
- กรอกเบอร์โทร → ส่ง OTP ผ่าน Supabase phone auth (SMS via Twilio)
- รองรับ format ไทย: `081-234-5678` → normalize เป็น `+66812345678` อัตโนมัติ
- OTP expire ตามการตั้งค่า Supabase (default 60 วินาที)
- Resend cooldown 60 วินาที
- หลัง verify สำเร็จ → sync กับ backend → consent/onboarding ตาม flow ปกติ

**เพิ่มปุ่มที่ login_screen.dart:**
- ปุ่ม "เบอร์โทรศัพท์" ต่อจาก Google Sign-In

#### วิธีตั้งค่า Supabase Phone Auth

1. ไปที่ [Supabase Dashboard](https://supabase.com) → Project → Authentication → Providers
2. เปิด "Phone" provider
3. ตั้งค่า SMS provider (Twilio แนะนำสำหรับไทย):
   - Account SID
   - Auth Token
   - Message Service SID หรือ Phone Number
4. ทดสอบด้วย Test OTP Numbers ในโหมด dev

#### วิธีตั้งค่า SendGrid (Email OTP / Transactional Email)

> หมายเหตุ: SendGrid ใช้สำหรับ email ไม่ใช่ SMS OTP

1. สมัคร [SendGrid](https://sendgrid.com) → สร้าง API Key
2. ใน Supabase Dashboard → Authentication → Email Templates → ตั้ง Custom SMTP:
   - Host: `smtp.sendgrid.net`
   - Port: `587`
   - Username: `apikey`
   - Password: `[your SendGrid API Key]`
   - Sender email: verified sender ใน SendGrid

---

### Localization

เพิ่ม keys ใหม่ใน `lib/l10n/app_localizations.dart` (ทั้ง EN และ TH):

```
phone.title
phone.subtitle
phone.label
phone.hint
phone.cta
phone.otp.title
phone.otp.subtitle
phone.otp.hint
phone.otp.cta
phone.otp.resend
phone.otp.resend_in
phone.error.invalid
phone.error.send_failed
phone.error.verify_failed
phone.or_use
```

---

### Architecture Notes

**Semantic macro color system** (ใช้ค่าเดียวกันทุกหน้า):

```dart
const proteinColor = Color(0xFF2563EB); // blue-600
const carbsColor   = Color(0xFFD97706); // amber-600
const fatColor     = Color(0xFFEA580C); // orange-600
```

ในหน้า TdeeFormulaScreen เก็บเป็น static const ชื่อ `_macroProtein`, `_macroCarbs`, `_macroFat` — แก้ที่นี่จุดเดียวแล้วทุก widget ใน screen จะใช้สีที่ถูกต้อง

**Days-remaining color logic** (profile_screen.dart):

```dart
Color _daysColor(String daysLeftText) {
  final days = int.tryParse(daysLeftText) ?? 0;
  if (days <= 0)  return Color(0xFF6B7280); // gray — ผ่านแล้ว
  if (days <= 14) return Color(0xFFE85D04); // orange — ด่วน
  if (days <= 30) return Color(0xFFD97706); // amber — ใกล้ถึง
  return Color(0xFF628141);                 // brand — ยังมีเวลา
}
```
