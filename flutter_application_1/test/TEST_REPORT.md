# 🧪 Unit Test Report — Calories Guard
**Framework:** Flutter `flutter_test`  
**Total Tests:** 112 | ✅ Passed: 112 | ❌ Failed: 0  
**Last Run:** 2025 | Status: **ALL PASSED**

---

## 📁 Test Files
| File | Group | Tests |
|---|---|---|
| `health_calc_test.dart` | BMI, BMR, TDEE, Macro, Validation | 76 |
| `gamification_test.dart` | Tier, Badge, Mission, Calorie, Water | 27 |
| `widget_test.dart` | Widget smoke test | 9 |

---

## 🏥 health_calc_test.dart

### 1. BMI Calculation — `weight / (height/100)²`

| # | Test Case | Input | Expected Output | Actual Output | Status |
|---|---|---|---|---|---|
| 1 | ชายปกติ | weight=70kg, height=175cm | 22.86 | 22.86 | ✅ |
| 2 | น้ำหนักน้อย | weight=45kg, height=170cm | 15.57 | 15.57 | ✅ |
| 3 | อ้วน | weight=100kg, height=165cm | 36.73 | 36.73 | ✅ |
| 4 | ท้วม (Asian cutoff) | weight=68kg, height=170cm | 23.53 | 23.53 | ✅ |
| 5 | weight = 0 (guard) | weight=0, height=170cm | 0 | 0 | ✅ |
| 6 | height = 0 (guard) | weight=70kg, height=0cm | 0 | 0 | ✅ |

> **อ้างอิง:** Quetelet Index (1835); WHO BMI formula standard

---

### 2. BMI Status — WHO Asia-Pacific 2004 Cutoffs

| # | Test Case | Input (BMI) | Expected Output | Actual Output | Status |
|---|---|---|---|---|---|
| 7 | น้ำหนักน้อย | 17.0 | น้ำหนักน้อย | น้ำหนักน้อย | ✅ |
| 8 | ปกติ boundary ล่าง | 18.5 | ปกติ | ปกติ | ✅ |
| 9 | ปกติ boundary บน | 22.9 | ปกติ | ปกติ | ✅ |
| 10 | ท้วม boundary ล่าง | 23.0 | ท้วม | ท้วม | ✅ |
| 11 | อ้วน boundary ล่าง | 25.0 | อ้วน | อ้วน | ✅ |
| 12 | อ้วนมาก | 30.0 | อ้วนมาก | อ้วนมาก | ✅ |
| 13 | invalid | 0 | - | - | ✅ |

> **อ้างอิง:** WHO Expert Consultation, *The Lancet*, 2004  
> ⚠️ คนเอเชียใช้ cutoff ต่ำกว่า WHO สากล (23/25/30 แทน 25/30/35)

---

### 3. BMR — Mifflin-St Jeor (1990)
**สูตร:**  
- ชาย: `(10×w) + (6.25×h) - (5×age) + 5`  
- หญิง: `(10×w) + (6.25×h) - (5×age) - 161`

| # | Test Case | Input | Expected (kcal) | Actual (kcal) | Status |
|---|---|---|---|---|---|
| 14 | ชาย อายุ 25 | 70kg, 175cm, male | 1673.75 | 1673.75 | ✅ |
| 15 | หญิง อายุ 30 | 60kg, 162cm, female | 1301.50 | 1301.50 | ✅ |
| 16 | ชายอ้วน อายุ 40 | 90kg, 180cm, male | 1830.00 | 1830.00 | ✅ |
| 17 | หญิงผอม อายุ 20 | 50kg, 155cm, female | 1207.75 | 1207.75 | ✅ |
| 18 | weight=0 (guard) | 0kg, 175cm | 1500 (fallback) | 1500 | ✅ |
| 19 | อายุมาก BMR ลด | 70kg, 170cm, age=65 vs 25 | BMR65 < BMR25 | true | ✅ |

> **อ้างอิง:** Mifflin MD, St Jeor ST et al., *J Am Diet Assoc.* 1990;90(3):286-90. PMID: 2305711  
> ✅ ถูกต้องแม่นยำที่สุดสำหรับคนทั่วไป ± 10% (เทียบกับ Harris-Benedict 1919)

---

### 4. Activity Factor (PAL Multipliers)

| # | Activity Level | Input | Expected Factor | Actual | Status |
|---|---|---|---|---|---|
| 20 | ไม่ออกกำลังกาย | sedentary | 1.200 | 1.200 | ✅ |
| 21 | ออกกำลังกายเบา | lightly_active | 1.375 | 1.375 | ✅ |
| 22 | ออกกำลังกายปานกลาง | moderately_active | 1.550 | 1.550 | ✅ |
| 23 | ออกกำลังกายหนัก | very_active | 1.725 | 1.725 | ✅ |
| 24 | ออกกำลังกายหนักมาก | extra_active | 1.900 | 1.900 | ✅ |
| 25 | ค่าไม่รู้จัก | "unknown" / "" | 1.200 (default) | 1.200 | ✅ |

> **อ้างอิง:** Frankenfield D et al., *J Am Diet Assoc.* 2005;105(5):775-89  
> ⚠️ แอปแสดงเพียง 4 ระดับ (ไม่มี extra_active ใน UI แต่รองรับใน logic)

---

### 5. TDEE = BMR × Activity Factor

| # | Test Case | Input | Expected (kcal) | Actual (kcal) | Status |
|---|---|---|---|---|---|
| 26 | sedentary | BMR=1674, sedentary | 2008.8 | 2008.8 | ✅ |
| 27 | moderately_active | BMR=1674, moderate | 2594.7 | 2594.7 | ✅ |
| 28 | very_active | BMR=1674, very_active | 2887.7 | 2887.7 | ✅ |
| 29 | TDEE > BMR เสมอ | BMR จริง, moderate | TDEE > BMR | true | ✅ |
| 30 | very > moderate > sedentary | BMR=1500 | เรียงจากมากไปน้อย | true | ✅ |

---

### 6. Calorie from Macronutrients — Atwater System
**สูตร:** `(protein×4) + (carbs×4) + (fat×9)` kcal

| # | Test Case | Input | Expected (kcal) | Actual (kcal) | Status |
|---|---|---|---|---|---|
| 31 | Mixed meal | P=30g, C=50g, F=20g | 500.0 | 500.0 | ✅ |
| 32 | Protein only | P=25g, C=0, F=0 | 100.0 | 100.0 | ✅ |
| 33 | Carbs only | P=0, C=100g, F=0 | 400.0 | 400.0 | ✅ |
| 34 | Fat only | P=0, C=0, F=10g | 90.0 | 90.0 | ✅ |
| 35 | All zero | P=0, C=0, F=0 | 0 | 0 | ✅ |
| 36 | ข้าวสวย 1 ถ้วย | P=4g, C=44g, F=0.5g | 196.5 | 196.5 | ✅ |
| 37 | Fat > Carbs (gram เท่ากัน) | F=10g vs C=10g | fat > carbs | true | ✅ |

> **อ้างอิง:** Atwater WO (1899); FAO/WHO. *Food Energy — Methods of Analysis*, 2003  
> Fat ให้พลังงาน 9 kcal/g = 2.25× มากกว่า carbs/protein (4 kcal/g)

---

### 7. Target Calories & Safety Floor

**สูตร:** `TDEE + (kgPerWeek × 1100)`  
**Floor:** ชาย ≥ 1500 kcal/day, หญิง ≥ 1200 kcal/day

| # | Test Case | Input | Expected (kcal) | Actual (kcal) | Status |
|---|---|---|---|---|---|
| 38 | ลด 0.5 kg/week (หญิง) | TDEE=2200, -0.5kg, female | 1650 | 1650 | ✅ |
| 39 | เพิ่มกล้ามเนื้อ | TDEE=2000, +0.5kg, male | 2550 | 2550 | ✅ |
| 40 | คง goal | TDEE=2000, 0kg, male | 2000 | 2000 | ✅ |
| 41 | Floor ชาย (ต่ำเกิน) | TDEE=1600, -1.0kg, male | ≥ 1500 | 1500 | ✅ |
| 42 | Floor หญิง (ต่ำเกิน) | TDEE=1400, -1.0kg, female | ≥ 1200 | 1200 | ✅ |
| 43 | TDEE สูงพอ ไม่โดน floor | TDEE=2500, -0.5kg, female | 1950 | 1950 | ✅ |

> **อ้างอิง:** NIH, *Very Low Calorie Diets*, National Heart, Lung, and Blood Institute  
> ⚠️ ต่ำกว่า floor → เสี่ยง malnutrition, gallstone, กล้ามเนื้อสลาย

---

### 8. Email Validation

| # | Test Case | Input | Expected | Actual | Status |
|---|---|---|---|---|---|
| 44 | email ถูกต้อง | `user@example.com` | valid | valid | ✅ |
| 45 | subdomain + tag | `sub.domain+tag@mail.co.th` | valid | valid | ✅ |
| 46 | ไม่มี @ | `userexample.com` | invalid | invalid | ✅ |
| 47 | ไม่มี domain | `user@` | invalid | invalid | ✅ |
| 48 | ว่างเปล่า | `""` | invalid | invalid | ✅ |
| 49 | มีแค่ @ | `@` | invalid | invalid | ✅ |
| 50 | ไม่มี TLD | `user@domain` | invalid | invalid | ✅ |

---

### 9. Age Validation (10–100 ปี)

> **Rationale:** WHO growth reference เริ่มที่ age 2; แอปกำหนด min 10 เพื่อ target ผู้ใช้ที่ตั้งใจ  
> max 100 = สมเหตุสมผลสำหรับ fitness app  
> **อ้างอิง:** WHO Child Growth Standards (2006); WHO Growth Reference 5–19 years (2007)

| # | Test Case | Input | Expected | Actual | Status |
|---|---|---|---|---|---|
| 51 | อายุปกติ | 25 | valid | valid | ✅ |
| 52 | min boundary | 10 | valid | valid | ✅ |
| 53 | max boundary | 100 | valid | valid | ✅ |
| 54 | ต่ำกว่า min | 9 | invalid | invalid | ✅ |
| 55 | เกิน max | 101 | invalid | invalid | ✅ |
| 56 | ศูนย์ | 0 | invalid | invalid | ✅ |
| 57 | ติดลบ | -1 | invalid | invalid | ✅ |

---

### 10. Height Validation (100–250 cm)

> **Rationale:**  
> - Tallest human on record: 272 cm (Robert Wadlow, 1940) — app cap ที่ 250 เพื่อ UX  
> - เด็กอายุ 10 ปี สูงเฉลี่ย ~138 cm (WHO) → min 100 รองรับ underweight  
> **อ้างอิง:** Guinness World Records; WHO Growth Standards

| # | Test Case | Input | Expected | Actual | Status |
|---|---|---|---|---|---|
| 58 | ส่วนสูงปกติ | 170 cm | valid | valid | ✅ |
| 59 | min boundary | 100 cm | valid | valid | ✅ |
| 60 | max boundary | 250 cm | valid | valid | ✅ |
| 61 | ต่ำกว่า min | 99 cm | invalid | invalid | ✅ |
| 62 | เกิน max | 251 cm | invalid | invalid | ✅ |
| 63 | ศูนย์ | 0 cm | invalid | invalid | ✅ |

---

### 11. Weight Validation (20–300 kg)

> **Rationale:**  
> - เด็ก 10 ปี underweight ต่ำสุด ~20 kg (CDC < 3rd percentile)  
> - Guinness heaviest living: 635 kg — app cap ที่ 300 kg เพื่อความสมเหตุสมผล  
> **อ้างอิง:** CDC Growth Charts (2000); Guinness World Records

| # | Test Case | Input | Expected | Actual | Status |
|---|---|---|---|---|---|
| 64 | น้ำหนักปกติ | 65 kg | valid | valid | ✅ |
| 65 | min boundary | 20 kg | valid | valid | ✅ |
| 66 | max boundary | 300 kg | valid | valid | ✅ |
| 67 | ต่ำกว่า min | 19 kg | invalid | invalid | ✅ |
| 68 | เกิน max | 301 kg | invalid | invalid | ✅ |
| 69 | ศูนย์ | 0 kg | invalid | invalid | ✅ |

---

### 12. Weight Loss Safety (max ±1.0 kg/week)

> **Rationale:**  
> การลดน้ำหนักที่ปลอดภัย = 0.5–1.0 kg/week = deficit 550–1100 kcal/day  
> เกิน 1.0 kg/week → เสี่ยงสูญเสียกล้ามเนื้อ + gallstone formation  
>
> **งานวิจัยรองรับ:**  
> 1. Academy of Nutrition and Dietetics (AND), *J Acad Nutr Diet.* 2016 — "Safe rate of weight loss: 0.5–1.0 kg/week"  
> 2. Johansson K et al., *Obesity Reviews*, 2014 — "Rapid weight loss increases gallstone risk"  
> 3. Stiegler P & Cunliffe A, *Sports Medicine*, 2006 — "Rapid loss >1 kg/week → significant LBM reduction"

| # | Test Case | Input (kg/week) | Expected | Actual | Status |
|---|---|---|---|---|---|
| 70 | ลด 0.5 (แนะนำ) | -0.5 | ปลอดภัย ✅ | ปลอดภัย | ✅ |
| 71 | ลด 1.0 (ขีดจำกัด) | -1.0 | ปลอดภัย ✅ | ปลอดภัย | ✅ |
| 72 | ลด 1.1 (เกินขีดจำกัด) | -1.1 | ไม่ปลอดภัย ❌ | ไม่ปลอดภัย | ✅ |
| 73 | เพิ่ม 1.0 (bulk) | +1.0 | ยอมรับได้ ✅ | ยอมรับได้ | ✅ |
| 74 | เพิ่ม 1.1 (เกิน) | +1.1 | เกินขอบเขต ❌ | เกินขอบเขต | ✅ |
| 75 | คง goal | 0 | ปลอดภัย ✅ | ปลอดภัย | ✅ |
| 76 | Crash diet | -2.0 | อันตราย ❌ | อันตราย | ✅ |

---

## 🎮 gamification_test.dart

### 1. Tier Logic

| # | Test Case | Input | Expected | Actual | Status |
|---|---|---|---|---|---|
| 1 | 0 pts → tier 0 | pts=0 | 0 (ต้นกล้า) | 0 | ✅ |
| 2 | 100 pts → tier 1 | pts=100 | 1 (ต้อย) | 1 | ✅ |
| 3 | 1200 pts → tier 4 | pts=1200 | 4 (พราว) | 4 | ✅ |
| 4 | 2000 pts → tier 5 | pts=2000 | 5 (วิ้งค์) | 5 | ✅ |
| 5 | 9999 pts → tier 5 (max) | pts=9999 | 5 | 5 | ✅ |
| 6 | 299 pts ยังไม่ถึง tier 2 | pts=299 | 1 | 1 | ✅ |
| 7 | maxTierIdx ไม่ลดหลัง spend | 2000→50 pts | maxTier=5 | 5 | ✅ |
| 8 | maxTierIdx เพิ่มเมื่อสูงขึ้น | pts ข้ามเกณฑ์ tier 4 | maxTier=4 | 4 | ✅ |
| 9 | clamp(-1) = 0 | idx=-1 | 0 | 0 | ✅ |

### 2. Badge Redemption

| # | Test Case | Input | Expected | Actual | Status |
|---|---|---|---|---|---|
| 10 | แลก badge (points พอ) | pts=500, cost=50 | 450 | 450 | ✅ |
| 11 | แลก badge_grower | pts=500, cost=300 | 200 | 200 | ✅ |
| 12 | points พอดี | pts=50, cost=50 | 0 | 0 | ✅ |
| 13 | points ไม่พอ | pts=40, cost=50 | Exception | Exception | ✅ |
| 14 | pts=0 แลกไม่ได้ | pts=0, cost=50 | Exception | Exception | ✅ |

### 3. Mission Claim

| # | Test Case | Input | Expected | Actual | Status |
|---|---|---|---|---|---|
| 15 | claim mission ใหม่ | pts=0, mission=50 | 50 | 50 | ✅ |
| 16 | claim บน pts สูง | pts=1000, mission=50 | 1050 | 1050 | ✅ |
| 17 | claim ซ้ำ → throw | mission ใน claimedToday | Exception | Exception | ✅ |
| 18 | claim mission ต่างกัน | m1 then m2 | pts ถูกต้อง | ✅ | ✅ |
| 19 | claim 3 missions | 3×100 pts | 300 | 300 | ✅ |

### 4-5. Calorie & Water (เหมือน Section 6 และ 7 ด้านบน)

---

## 📚 References & Research

| หัวข้อ | งานวิจัย | ปี |
|---|---|---|
| BMI formula | Quetelet Index — Adolphe Quetelet | 1835 |
| BMI Asian cutoffs | WHO Expert Consultation, *The Lancet* | 2004 |
| BMR Mifflin-St Jeor | Mifflin MD et al., *J Am Diet Assoc.* PMID:2305711 | 1990 |
| Activity factors | Frankenfield D et al., *J Am Diet Assoc.* 105(5):775 | 2005 |
| Atwater system | Atwater WO; FAO *Food Energy Methods* | 1899/2003 |
| Calorie floor (VLCD) | NIH — Very Low Calorie Diets guideline | 2023 |
| Safe weight loss rate | Academy of Nutrition & Dietetics, *J Acad Nutr Diet* | 2016 |
| Rapid loss + gallstone | Johansson K et al., *Obesity Reviews* | 2014 |
| Rapid loss + muscle loss | Stiegler P & Cunliffe A, *Sports Medicine* | 2006 |
| Height record | Guinness — Robert Wadlow 272 cm | 1940 |
| Child weight (10y) | CDC Growth Charts | 2000 |

---

## ❓ ถ้าต้องการงานวิจัยใหม่ ทำอย่างไร?

1. **PubMed** — [pubmed.ncbi.nlm.nih.gov](https://pubmed.ncbi.nlm.nih.gov)  
   ค้นด้วย: `"weight loss" "safe rate" OR "BMR equation accuracy" OR "TDEE prediction"`

2. **Google Scholar** — [scholar.google.com](https://scholar.google.com)  
   ค้นด้วย: `Mifflin St Jeor accuracy validation 2020`

3. **WHO Technical Reports** — [who.int](https://www.who.int/publications)  
   ค้นด้วย: `BMI cutoff Asia` หรือ `energy requirements`

4. **Cochrane Library** — [cochranelibrary.com](https://www.cochranelibrary.com)  
   สำหรับ systematic review เรื่อง weight loss interventions
