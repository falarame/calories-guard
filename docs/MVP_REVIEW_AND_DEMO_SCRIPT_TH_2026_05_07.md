# Calories Guard MVP Review และ Demo Script

วันที่ตรวจ: 2026-05-07

## 1. สถานะ Branch และการตรวจสอบ

- Branch ปัจจุบัน: `main`
- `git pull --ff-only origin main`: `Already up to date`
- หมายเหตุ git: local `main` ahead `origin/main` อยู่ 2 commits และมีไฟล์ `CalGuard_Presentation_v2.pptx` ถูกแก้ค้างอยู่ก่อนรอบตรวจนี้

## 2. ผลทดสอบล่าสุด

| ส่วน | คำสั่ง | ผล |
|---|---|---|
| Backend API | `python -m pytest -q` ใน `backend/` | ผ่าน 129 tests |
| Flutter app | `flutter test` ใน `flutter_application_1/` | ผ่าน 283 tests |
| Admin web | `npm run build` ใน `admin-web/` | build ผ่าน |
| Flutter analyze | `flutter analyze` | ยังไม่ผ่าน เพราะมี analyzer issues เดิม 121 จุด |

การแก้ที่ทำในรอบนี้:

- ปรับ test ใน `flutter_application_1/test/full_coverage_test.dart` ให้ default language เป็น `th` ตามโค้ดจริงและ positioning ของแอพสำหรับผู้ใช้ไทย

## 3. MVP ที่มีแล้ว

### Mobile App สำหรับผู้ใช้

- สมัครสมาชิก, login, ตรวจ email, verify email, forgot/reset password flow
- onboarding: consent, เพศ, วันเกิด, น้ำหนัก, ส่วนสูง, activity level, เป้าหมาย, น้ำหนักเป้าหมาย, ระยะเวลา, allergy
- คำนวณ BMI, BMR, TDEE, target calories, target macros
- dashboard รายวัน: calories, macros, BMI, meals, water, notification, gamification banner
- บันทึกอาหารตามมื้อ พร้อม food search, quick add, AI meal estimate และ nutrition snapshot
- บันทึกน้ำ พร้อม safety warning เมื่อดื่มน้ำน้อย
- บันทึกน้ำหนักและดู progress chart
- recommendation: อาหารแนะนำ, recipe detail, favorite, review, add to meal
- AI Coach สำหรับคำถามด้านอาหาร/สุขภาพในขอบเขตแอพ
- gamification: missions, points, badges/reward, leaderboard, character progression
- profile/settings: แก้ข้อมูลผู้ใช้, allergy, unit, language/theme, PDPA/export/delete support ที่ backend รองรับ

### Backend API

- FastAPI แยก router ตามโดเมน: auth, users, foods, meals, water, weight, insights, chat, notifications, feedback, admin, social
- Supabase/PostgreSQL integration, static image serving, CORS, API version header
- nutrition safety service, water safety service, scope guard, AI kill switch, LLM provider abstraction
- auth guard, admin guard, PDPA export/delete, food moderation, regional names, recipe cache/social
- test coverage backend 129 tests ครอบคลุม auth, meals, nutrition, water, AI, recipe, PDPA, guards, schemas

### Admin Web

- React + Vite admin dashboard build ผ่าน
- รองรับ user management, foods, temp food approval, regional name submissions, dashboard

## 4. สิ่งที่ควรปรับก่อนเรียกว่า Closed Beta Ready

P0:

- เคลียร์ `flutter analyze` ให้ผ่าน โดยเริ่มจาก warnings ที่ง่ายก่อน: unused imports, `print`, curly braces, deprecated `withOpacity`
- rotate Supabase DB password ถ้าเคยถูกเผยแพร่ใน chat/log
- ทดสอบ Android เครื่องจริง: login, record meal, AI estimate, notification permission, Health Connect/Samsung Health
- ยืนยัน staging environment แยกจาก production ทั้ง Supabase และ Railway

P1:

- เพิ่ม Thai food database ให้ใหญ่และน่าเชื่อถือขึ้น โดยผูกแหล่งข้อมูล/เวอร์ชันของ food composition
- ทำ load test บน staging สำหรับ `/foods/search`, meal create/summary, chat
- เพิ่ม monitoring dashboard: login success, record meal success, AI latency/error rate
- ใส่ public URL ของ Privacy Policy และ Terms ในแอพ
- เพิ่ม UI fallback ชัดเจนเมื่อ AI unavailable หรือ network timeout

P2:

- ลด tech debt ใน Flutter UI: deprecated opacity, hardcoded strings ที่ยังไม่ผ่าน l10n, duplicated logic
- เพิ่ม screenshot/manual QA สำหรับ flow เดโมจริง
- ตรวจ iOS build หลัง Android stable

## 5. Research/Evidence ที่ใช้เล่าให้กรรมการฟัง

- BMI cutoff สำหรับผู้ใช้เอเชียใช้จุดเตือนที่ BMI 23 และ 27.5 ตาม WHO Expert Consultation/Lancet 2004 ที่ถูกอ้างต่อในงานวิชาการหลายชิ้น: https://pmc.ncbi.nlm.nih.gov/articles/PMC4217157/
- การลดน้ำหนักควรค่อยเป็นค่อยไปประมาณ 1-2 lb/week หรือราว 0.45-0.9 kg/week ตาม CDC: https://www.cdc.gov/healthy-weight-growth/losing-weight/index.html
- AI ด้านสุขภาพควรมี human oversight, transparency, safety และไม่แทนแพทย์ ตาม WHO AI health ethics guidance: https://www.who.int/publications/i/item/9789240029200
- allergy warning สำคัญเพราะ food allergy อาจรุนแรงถึง anaphylaxis และ FDA ระบุ major allergens/labeling requirements ชัดเจน: https://www.fda.gov/food/buy-store-serve-safe-food/food-allergies-what-you-need-know
- self-monitoring พร้อม feedback เป็นแนวคิดสำคัญใน behavior change intervention: https://link.springer.com/article/10.1186/s12966-023-01555-6

## 6. Demo Script 10-12 นาที

### Opening

สวัสดีครับ วันนี้ผมจะนำเสนอ Calories Guard แอพติดตามโภชนาการสำหรับผู้ใช้ไทย จุดเด่นคือไม่ได้ให้ผู้ใช้จดแคลอรี่อย่างเดียว แต่เริ่มจากข้อมูลสุขภาพของผู้ใช้ คำนวณเป้าหมายเฉพาะบุคคล แล้วช่วยบันทึกอาหาร น้ำ น้ำหนัก ดู progress รับคำแนะนำ และมี AI Coach พร้อม safety guardrails

### Part 1: Login และ Onboarding

สิ่งที่ทำบนจอ:

1. เปิด Welcome/Login
2. login ด้วยบัญชี demo
3. ถ้าเริ่มใหม่ให้โชว์ consent และข้อมูลพื้นฐาน

Script:

ระบบเริ่มจากบัญชีผู้ใช้และ consent เพราะข้อมูลที่ใช้เป็นข้อมูลสุขภาพ เช่น อายุ น้ำหนัก ส่วนสูง เป้าหมาย และ allergy เราเก็บข้อมูลเหล่านี้เพื่อคำนวณ BMI, BMR, TDEE, target calories และ macro target ไม่ใช่เก็บโดยไม่มีเหตุผล

### Part 2: BMI, Activity และ Goal

สิ่งที่ทำบนจอ:

1. แสดง BMI/Activity
2. เลือก goal: ลดน้ำหนัก, รักษาน้ำหนัก, เพิ่มกล้าม
3. ตั้ง target weight และ duration

Script:

แอพใช้ BMI cutoff สำหรับคนเอเชีย โดยเริ่มเตือนความเสี่ยงที่ BMI 23 และเสี่ยงสูงที่ 27.5 จากนั้นใช้ activity level คำนวณ TDEE แล้วปรับเป้าหมายตาม goal ถ้าลดน้ำหนักจะเป็น calorie deficit แบบมี guardrail ถ้ารักษาน้ำหนักจะใกล้ TDEE และถ้าเพิ่มกล้ามจะเพิ่มพลังงานและโปรตีน

### Part 3: Home Dashboard

สิ่งที่ทำบนจอ:

1. ชี้ calorie progress
2. ชี้ protein/carbs/fat
3. ชี้ water, notification, tamagotchi banner

Script:

หน้าหลักตอบคำถามว่า วันนี้ผู้ใช้อยู่ตรงไหนแล้ว กินไปเท่าไหร่ เหลือเท่าไหร่ สารอาหารหลักพอไหม และมีความเสี่ยงอะไรที่ระบบควรแจ้งเตือน จุดนี้ทำให้ตัวเลขกลายเป็น feedback ที่ผู้ใช้ตัดสินใจต่อได้

### Part 4: Record Food และ AI Estimate

สิ่งที่ทำบนจอ:

1. เปิด Record Food
2. ค้นหาอาหาร เช่น กะเพราไก่ หรือ ไข่ต้ม
3. เพิ่มอาหารเข้ามื้อ
4. ลอง AI meal estimate หรือ quick add

Script:

ผู้ใช้สามารถบันทึกอาหารตามมื้อ ระบบจะรวม calories และ macros เข้า daily summary ทันที ถ้าอาหารไม่มีในฐานข้อมูล ผู้ใช้สามารถใช้ AI estimate หรือส่งอาหารใหม่เข้า temp food เพื่อรอ admin review จุดสำคัญคือเมื่อบันทึกอาหาร ระบบเก็บ nutrition snapshot ไว้ ทำให้ประวัติไม่เปลี่ยนย้อนหลังแม้ฐานข้อมูลอาหารกลางจะถูกแก้ภายหลัง

### Part 5: Allergy และ Recommendation

สิ่งที่ทำบนจอ:

1. เปิดอาหารแนะนำหรือ recipe
2. เลือกเมนูที่เกี่ยวกับ allergy demo
3. ชี้ warning

Script:

Recommendation ของเราไม่ได้ดูแค่แคลอรี่ แต่ดูความเหมาะสมกับผู้ใช้ด้วย เช่น goal, macro และ allergy ถ้าอาหารมีความเสี่ยง ระบบเตือนก่อนให้ผู้ใช้ตัดสินใจ เพราะในบริบทสุขภาพ ความปลอดภัยสำคัญกว่าการแนะนำอาหารให้ครบจำนวน

### Part 6: Water, Weight และ Progress

สิ่งที่ทำบนจอ:

1. เพิ่มน้ำ 1 แก้ว
2. เปิด weight/progress chart
3. แสดง trend

Script:

นอกจากอาหาร แอพติดตามน้ำและน้ำหนัก น้ำใช้เตือนพฤติกรรมรายวัน ส่วนน้ำหนักใช้ดูแนวโน้มระยะยาว เพราะการตัดสินจากวันเดียวอาจผิดพลาด ระบบจึงควรดู trend และ feedback ต่อเนื่อง

### Part 7: AI Coach และ Scope Guard

สิ่งที่ทำบนจอ:

1. เปิด AI Coach
2. ถาม “วันนี้กินอะไรดีถ้าอยากลดน้ำหนัก”
3. ถามนอก scope สั้นๆ เพื่อโชว์ refusal ถ้าพร้อม

Script:

AI Coach เป็นผู้ช่วย ไม่ใช่แพทย์และไม่ใช่ตัวตัดสินใจสุดท้าย ระบบมี scope guard ให้ตอบเฉพาะด้านอาหาร สุขภาพ พฤติกรรม และเป้าหมายของแอพ ถ้า AI ไม่พร้อม แอพยังใช้งาน core flow ได้ เช่น บันทึกอาหาร dashboard progress และ recommendation

### Part 8: Gamification

สิ่งที่ทำบนจอ:

1. เปิด Tamagotchi
2. แสดง missions, points, badges

Script:

สุขภาพเป็นพฤติกรรมที่ต้องทำซ้ำทุกวัน Gamification ใช้ช่วยให้ผู้ใช้กลับมาบันทึกต่อเนื่อง เช่น mission, reward, character progression แต่แกนหลักยังเป็น nutrition data และ safety

### Closing

สรุปแล้ว Calories Guard คือ personalized nutrition tracker สำหรับผู้ใช้ไทย ที่รวม food logging, water, weight, recommendation, AI Coach, admin moderation และ safety guardrails ไว้ในระบบเดียว จุดแข็งคือผู้ใช้ไม่ได้เห็นแค่ตัวเลข แต่เห็นว่าควรทำอะไรต่ออย่างปลอดภัยและเหมาะกับเป้าหมายของตัวเอง

## 7. Test Demo Script สำหรับโชว์การทดสอบ

พูดนำ:

ก่อนส่ง MVP ผมทดสอบ 3 ชั้น คือ backend API, Flutter app และ admin web เพื่อให้มั่นใจว่า core flow ไม่พัง

ลำดับที่โชว์:

1. Backend: เปิด terminal แล้วบอกว่า `python -m pytest -q` ผ่าน 129 tests ครอบคลุม auth guard, admin guard, meal, nutrition safety, water safety, AI scope, recipe, PDPA
2. Flutter: บอกว่า `flutter test` ผ่าน 283 tests ครอบคลุม BMI/BMR/TDEE, validation, l10n, gamification, API parsing, offline behavior
3. Admin: บอกว่า `npm run build` ผ่าน แปลว่า TypeScript และ production build ใช้งานได้
4. Analyzer: แจ้งตรงไปตรงมาว่า `flutter analyze` ยังมี 121 issues ส่วนใหญ่เป็น code quality/deprecation ไม่ใช่ failing unit test และถูกจัดไว้เป็นงานก่อน closed beta

Fallback ถ้าเครื่องเดโมรัน test ช้า:

ผมมีผลตรวจล่าสุดจากวันที่ 2026-05-07: backend ผ่าน 129 tests, Flutter ผ่าน 283 tests, admin build ผ่าน ส่วน analyzer ยังมีรายการปรับปรุงที่ต้องเก็บก่อน closed beta

