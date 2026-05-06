# Methodology และ Bug Review ปัจจุบันของแอพ Calories Guard

วันที่จัดทำ: 5 พฤษภาคม 2569  
บทบาทผู้ตรวจ: Senior Software Engineer / Developer / Committee Reviewer  
ขอบเขตการตรวจ: Flutter mobile app, FastAPI backend, Supabase PostgreSQL schema ที่แอพใช้งานจริงในปัจจุบัน

> เอกสารนี้อธิบาย logic และสูตรที่พบจาก codebase ปัจจุบัน ไม่ใช่คำแนะนำทางการแพทย์หรือโภชนาการเฉพาะบุคคล การใช้งานจริงควรมี disclaimer และควรให้ผู้ใช้ปรึกษาผู้เชี่ยวชาญเมื่อมีโรคประจำตัว ตั้งครรภ์ หรือมีข้อจำกัดด้านสุขภาพ

---

## 1. แหล่งโค้ดที่ใช้ตรวจสอบ

| ส่วนระบบ | ไฟล์หลักที่ตรวจ |
|---|---|
| สูตรโภชนาการฝั่ง backend | `backend/app/services/nutrition_service.py` |
| ข้อมูลผู้ใช้และสูตรฝั่ง Flutter | `flutter_application_1/lib/providers/user_data_provider.dart` |
| บันทึกมื้ออาหารและ daily summary | `backend/app/routers/meals.py` |
| บันทึกน้ำ | `backend/app/routers/water.py` |
| น้ำหนักและ goal progress | `backend/app/routers/weight.py` |
| Gamification / mission / tier | `flutter_application_1/lib/screens/tamagotchi/tamagotchi_screen.dart` |
| Reward shop | `flutter_application_1/lib/screens/tamagotchi/reward_shop_screen.dart` |
| AI meal estimate UI | `flutter_application_1/lib/widget/ai_meal_estimate_sheet.dart` |
| AI coach / AI meal estimate API | `backend/app/routers/chat.py` |
| Auth ownership guard | `backend/app/core/dependencies.py` |
| User gamification endpoint | `backend/app/routers/users.py` |
| Food CRUD และ user food suggestion | `backend/app/routers/foods.py` |
| Recipe review | `backend/app/routers/social.py` |

---

## 2. Methodology ภายในแอพ

### 2.1 การคำนวณอายุ

ใช้วันเกิดของผู้ใช้เทียบกับวันที่ปัจจุบัน

```text
age = ปีปัจจุบัน - ปีเกิด
ถ้าวันเกิดของปีนี้ยังมาไม่ถึง:
  age = age - 1
```

กรณีไม่มีวันเกิด:

| ฝั่งระบบ | ค่า default |
|---|---:|
| Backend | 20 ปี |
| Flutter | 20 ปี |

Backend จำกัดอายุขั้นต่ำด้วย:

```text
age = max(age, 10)
```

ผลกระทบ: ถ้าผู้ใช้ไม่ได้กรอกวันเกิด ระบบจะคำนวณ BMR, TDEE และเป้าหมายแคลอรีจากอายุ 20 ปีทันที

---

### 2.2 BMI

สูตร BMI ใน Flutter:

```text
height_m = height_cm / 100
BMI = weight_kg / (height_m ^ 2)
```

ถ้าน้ำหนักหรือส่วนสูงไม่ถูกต้อง:

```text
BMI = 0
```

ตารางแปลผล BMI ที่แอพใช้เป็นแนว Asian BMI:

| ช่วง BMI | ความหมาย |
|---:|---|
| น้อยกว่า 18.5 | น้ำหนักน้อย |
| 18.5 - 22.9 | ปกติ |
| 23.0 - 24.9 | น้ำหนักเกิน / ท้วม |
| 25.0 - 29.9 | อ้วน |
| 30.0 ขึ้นไป | อ้วนมาก |

---

### 2.3 BMR: Mifflin-St Jeor

แอพใช้สูตร Mifflin-St Jeor ทั้ง backend และ Flutter

```text
base = (10 * weight_kg) + (6.25 * height_cm) - (5 * age)
```

| เพศ | สูตร BMR |
|---|---|
| male | `base + 5` |
| female หรือค่าอื่น | `base - 161` |

ถ้าข้อมูลน้ำหนักหรือส่วนสูงไม่ถูกต้อง:

| ฝั่งระบบ | ค่า fallback |
|---|---:|
| Backend target calories | 2000 kcal |
| Flutter BMR | 1500 kcal |

ข้อสังเกต: fallback ระหว่าง backend และ Flutter ไม่เหมือนกัน จึงทำให้หน้าจอบางหน้าอาจแสดงเป้าหมายไม่ตรงกับ backend ถ้า stored target ยังไม่มี

---

### 2.4 TDEE

สูตร:

```text
TDEE = BMR * activity_factor
```

ตัวคูณกิจกรรมที่ใช้:

| activity_level | ความหมายโดยทั่วไป | Flutter | Backend `_compute_target_calories` | Backend `recalc_tdee` |
|---|---|---:|---:|---:|
| sedentary | นั่งทำงาน ไม่ค่อยออกกำลังกาย | 1.2 | 1.2 | 1.2 |
| lightly_active | กิจกรรมเบา | 1.375 | 1.375 | 1.375 |
| moderately_active | กิจกรรมปานกลาง | 1.55 | 1.55 | 1.55 |
| very_active | กิจกรรมมาก | 1.725 | 1.725 | 1.725 |
| extra_active | กิจกรรมหนักมาก | 1.9 | ไม่รองรับ | 1.9 |

จุดที่ต้องระวัง: `extra_active` มีใน Flutter และบาง endpoint ของ backend แต่ไม่มีใน `_compute_target_calories` ทำให้ผู้ใช้กลุ่มนี้อาจได้ target calories ต่ำกว่าที่ควรในบาง flow

---

### 2.5 Target Calories: สูตรหลักของ backend

Backend ใน `nutrition_service.py` ใช้สูตร:

```text
target_calories = TDEE + (kg_per_week * 1100)
```

โดย:

```text
kg_per_week = (target_weight_kg - current_weight_kg) / num_weeks
```

ถ้ามี `goal_start_date` และ `goal_target_date`:

```text
num_weeks = max((goal_target_date - goal_start_date) / 7, 1)
```

ถ้าไม่มีช่วงเวลาเป้าหมาย:

```text
num_weeks = 12
```

เหตุผลของค่า `1100`:

```text
1 kg ไขมันโดยประมาณ = 7700 kcal
7700 / 7 วัน = 1100 kcal ต่อวันต่อ 1 kg/week
```

ตัวอย่างการตีความ:

| เป้าหมาย | kg_per_week | ผลต่อ target calories |
|---|---:|---|
| ลดน้ำหนัก | ค่าติดลบ | ลดจาก TDEE |
| เพิ่มน้ำหนัก / เพิ่มกล้าม | ค่าบวก | เพิ่มจาก TDEE |
| คงน้ำหนัก | ใกล้ 0 | ใกล้ TDEE |

Backend มี safe minimum:

```text
male:   min_safe_cal = max(BMR, 1500)
female: min_safe_cal = max(BMR, 1200)
target_calories = max(target_calories, min_safe_cal)
```

ข้อดี: ลดโอกาสระบบแนะนำแคลอรีต่ำเกินไป  
ข้อควรตรวจเพิ่ม: การใช้ `max(BMR, 1500/1200)` อาจทำให้ผู้ใช้บางคนได้ target สูงมากจนลดน้ำหนักไม่ลง หาก BMR สูงกว่า minimum มาก

---

### 2.6 Target Calories: สูตรฝั่ง Flutter

Flutter จะใช้ค่า `storedTargetCalories` จาก backend ก่อน ถ้ามีค่า

```text
if storedTargetCalories > 0:
  targetCalories = storedTargetCalories
```

ถ้าไม่มีค่า stored target:

```text
lose_weight:  kg_per_week = -0.5
gain_muscle:  kg_per_week =  0.5
maintain:     kg_per_week =  0
```

ถ้ามี target weight:

```text
kg_per_week = (targetWeight - currentWeight) / effectiveWeeks
targetCalories = TDEE + (kg_per_week * 1100)
```

`effectiveWeeks`:

```text
ถ้ามี targetDate และ targetDate > today:
  effectiveWeeks = จำนวนวันถึง targetDate / 7
ถ้าไม่มี:
  effectiveWeeks = duration หรือ 12
```

จุดต่างจาก backend:

| ประเด็น | Flutter fallback | Backend |
|---|---|---|
| มี safe minimum หรือไม่ | ไม่มี | มี |
| fallback BMR เมื่อข้อมูลไม่ครบ | 1500 | target calories fallback 2000 |
| activity `extra_active` | รองรับ 1.9 | บางสูตรไม่รองรับ |
| ถ้ามี stored target | ใช้ stored target | เป็นผู้สร้าง stored target |

ผลกระทบ: ถ้า user data ยัง sync ไม่ครบ หรือ backend ยังไม่ได้บันทึก target calories หน้าจอ Flutter อาจคำนวณ target ไม่ตรงกับ backend

---

### 2.7 Recalculate TDEE Endpoint

ใน `backend/app/routers/users.py` มี logic recalculate target calories อีกชุดหนึ่ง

```text
BMR = Mifflin-St Jeor
TDEE = BMR * activity_factor
```

ถ้าเป็นการลดน้ำหนักและมี target date:

```text
kg_to_lose = current_weight_kg - target_weight_kg
days_left = goal_target_date - today
deficit_per_day = (kg_to_lose * 7700) / days_left
deficit = min(deficit_per_day, 750)
```

จากนั้น:

```text
male:   min_cal = 1500
female: min_cal = 1200
new_target_calories = max(min_cal, round(TDEE - deficit))
```

ข้อแตกต่างจากสูตรหลัก:

| ประเด็น | `_compute_target_calories` | `recalc_tdee` |
|---|---|---|
| ลด/เพิ่มแคลอรี | ใช้ `kg_per_week * 1100` ได้ทั้งลดและเพิ่ม | ใช้ deficit เฉพาะลดน้ำหนัก |
| จำกัด deficit | ไม่จำกัดตรงๆ แต่ clamp ด้วย min safe | จำกัด deficit สูงสุด 750 kcal/day |
| minimum calories | `max(BMR, 1500/1200)` | `1500/1200` |

ข้อเสนอเชิง methodology: ควรเลือกสูตรเดียวเป็น canonical formula และให้ทุก endpoint กับ Flutter ใช้ผลลัพธ์เดียวกันจาก backend

---

### 2.8 Target Macros ฝั่ง backend

Backend ใช้วิธีคำนวณแบบกรัมต่อน้ำหนักตัวก่อน แล้วค่อยคำนวณ carbs จากแคลอรีที่เหลือ

ถ้าไม่มี target calories:

```text
cal = _compute_target_calories(user)
```

ถ้าไม่มีน้ำหนัก:

```text
weight_kg = cal / 25
```

สูตรโปรตีนและไขมัน:

| goal_type | protein | fat |
|---|---:|---:|
| maintain_weight | `1.6 g * weight_kg` | `1.0 g * weight_kg` |
| gain_muscle | `2.0 g * weight_kg` | `1.0 g * weight_kg` |
| lose_weight | `1.8 g * weight_kg` | `0.8 g * weight_kg` |

แปลงเป็นแคลอรี:

```text
protein_cal = protein_g * 4
fat_cal = fat_g * 9
carbs_cal = target_calories - (protein_cal + fat_cal)
carbs_g = carbs_cal / 4
```

ถ้า carbs ต่ำกว่า 10% ของ target calories:

```text
if carbs_cal < target_calories * 0.1:
  ใช้สูตร ratio fallback
```

Ratio fallback:

| goal_type | Protein | Carbs | Fat |
|---|---:|---:|---:|
| maintain_weight | 25% | 45% | 30% |
| gain_muscle | 30% | 50% | 20% |
| lose_weight | 30% | 40% | 30% |

การแปลง ratio เป็นกรัม:

```text
protein_g = target_calories * protein_ratio / 4
carbs_g   = target_calories * carbs_ratio / 4
fat_g     = target_calories * fat_ratio / 9
```

---

### 2.9 Target Macros ฝั่ง Flutter

Flutter ใช้ stored target macros จาก backend ก่อน

```text
if storedTargetProtein > 0: ใช้ storedTargetProtein
if storedTargetCarbs > 0:   ใช้ storedTargetCarbs
if storedTargetFat > 0:     ใช้ storedTargetFat
```

ถ้าไม่มี stored values จะใช้ ratio:

| goal | Protein | Carbs | Fat |
|---|---:|---:|---:|
| lose_weight | 30% | 40% | 30% |
| maintain_weight | 25% | 45% | 30% |
| buildMuscle / gain_muscle | 30% | 50% | 20% |

สูตร:

```text
protein_g = targetCalories * protein_ratio / 4
carbs_g   = targetCalories * carbs_ratio / 4
fat_g     = targetCalories * fat_ratio / 9
```

จุดต่างจาก backend: Flutter fallback ใช้ ratio เท่านั้น แต่ backend ใช้กรัมต่อน้ำหนักตัวเป็นหลัก ดังนั้นหาก stored macro ยังไม่มี หน้าจออาจแสดงเป้าหมาย protein/carbs/fat ไม่ตรงกับ backend

---

### 2.10 Atwater Calories

ใน backend มี utility:

```text
calories = (protein_g * 4) + (carbs_g * 4) + (fat_g * 9)
```

ใช้หลัก Atwater factor:

| สารอาหาร | kcal ต่อกรัม |
|---|---:|
| Protein | 4 |
| Carbohydrate | 4 |
| Fat | 9 |

---

### 2.11 Normalize Calories

ใน backend มี helper สำหรับ normalize ค่าพลังงานจากหลายแหล่ง:

```text
valid = ค่า calories ที่ไม่ใช่ null และ >= 0
```

ถ้ามีน้อยกว่า 3 ค่า:

```text
return ค่าแรก
```

ถ้ามีตั้งแต่ 3 ค่าขึ้นไป:

```text
return ค่าเฉลี่ย
```

ข้อสังเกต: วิธีนี้เรียบง่าย แต่ยังไม่ตัด outlier เช่นค่าที่สูงผิดปกติจาก LLM หรือ data source ผิดพลาด

---

### 2.12 การบันทึกมื้ออาหาร

เมื่อบันทึกมื้ออาหาร:

```text
meal_total_calories = sum(item.cal_per_unit * item.amount)
```

รายการอาหารแต่ละรายการถูกเก็บใน `detail_items` โดยมี:

```text
amount
cal_per_unit
protein_per_unit
carbs_per_unit
fat_per_unit
```

ในหน้ารายละเอียดมื้ออาหาร:

```text
total_cal     = amount * cal_per_unit
total_protein = amount * protein_per_unit
total_carbs   = amount * carbs_per_unit
total_fat     = amount * fat_per_unit
```

การสรุปรายวัน:

```text
daily_total_calories = sum(detail_items.amount * detail_items.cal_per_unit)
daily_total_protein  = sum(detail_items.amount * detail_items.protein_per_unit)
daily_total_carbs    = sum(detail_items.amount * detail_items.carbs_per_unit)
daily_total_fat      = sum(detail_items.amount * detail_items.fat_per_unit)
```

ระบบมีการอ่านจาก `daily_summaries` และคำนวณซ้ำจาก `meals + detail_items` เพื่อให้ค่าที่แสดงล่าสุดถูกต้อง

---

### 2.13 การแจ้งเตือนแคลอรี

หลังบันทึกมื้ออาหาร backend ตรวจว่าแคลอรีรวมของวันเทียบกับเป้าหมายอย่างไร

ถ้าเกินเป้าหมาย:

```text
if total_intake > target_calories:
  สร้าง notification type = warning
```

ถ้าใกล้ถึงเป้า:

```text
if total_intake >= target_calories * 0.9:
  สร้าง notification type = tip
```

มีอีก logic ที่ทำงานหลัง 17:00:

```text
if current_time.hour >= 17:
  min_safe_cal = max(BMR, 1500) สำหรับ male
  min_safe_cal = max(BMR, 1200) สำหรับ female
  if today_calories < min_safe_cal:
    สร้าง warning ว่ากินต่ำกว่าระดับปลอดภัย
```

ข้อควรระวัง: ถ้า enum ในฐานข้อมูลไม่มี `warning` หรือ `tip` การ insert notification จะล้มเหลว และบางจุด swallow error ทำให้ทีมไม่เห็นปัญหาจาก log

---

### 2.14 การบันทึกน้ำ

Backend บันทึกปริมาณน้ำเป็น ml และคำนวณจำนวนแก้ว

```text
glasses = max(0, round(amount_ml / 250))
```

ตัวอย่าง:

| amount_ml | glasses |
|---:|---:|
| 0 | 0 |
| 250 | 1 |
| 500 | 2 |
| 750 | 3 |

ปัจจุบัน backend บันทึกวันที่ด้วย `CURRENT_DATE`

```text
INSERT INTO water_logs (..., date_record, ...)
VALUES (..., CURRENT_DATE, ...)
```

ผลกระทบ: แม้ Flutter ส่งวันที่ที่ผู้ใช้เลือกมา ถ้า backend schema ไม่รับหรือไม่ใช้ `date_record` จะถูกบันทึกเป็นวันนี้เสมอ

---

### 2.15 การบันทึกน้ำหนัก

เมื่อบันทึกน้ำหนัก:

```text
recorded_date = date.today()
```

ถ้ามี log วันนี้แล้ว:

```text
UPDATE weight_logs
```

ถ้ายังไม่มี:

```text
INSERT weight_logs
```

จากนั้น sync น้ำหนักล่าสุดกลับไปที่ตาราง `users`

```text
users.current_weight_kg = entry.weight_kg
```

---

### 2.16 Goal Progress ปัจจุบัน

Endpoint `/users/{user_id}/goal_progress` หา start weight ด้วยลำดับนี้:

1. น้ำหนัก log แรกที่อยู่หลัง `goal_start_date`
2. ถ้าไม่มี ใช้น้ำหนัก log แรกของผู้ใช้
3. ถ้าไม่มี log ใช้ current weight

สูตรปัจจุบัน:

```text
needed = abs(target_weight - start_weight)
done = abs(current_weight - start_weight)
progress_pct = min(100, done / needed * 100)
remaining_kg = abs(target_weight - current_weight)
```

ข้อจำกัดสำคัญ: สูตรนี้ใช้ `abs()` จึงไม่รู้ทิศทางของเป้าหมาย เช่นผู้ใช้ตั้งลดน้ำหนักแต่กลับน้ำหนักเพิ่ม ระบบก็ยังอาจนับว่า progress เพิ่ม

Endpoint `/progress_summary/{user_id}` มีสูตรที่ถูกทิศทางกว่า:

ลดน้ำหนัก:

```text
progress = (start_weight - current_weight) / (start_weight - target_weight)
```

เพิ่มกล้าม / เพิ่มน้ำหนัก:

```text
progress = (current_weight - start_weight) / (target_weight - start_weight)
```

คงน้ำหนัก:

```text
progress = 1 - abs(current_weight - target_weight) / max(target_weight, 1)
```

ค่าถูก clamp ให้อยู่ในช่วง `0.0 - 1.0`

ข้อเสนอ: ใช้สูตรของ `/progress_summary` เป็น canonical progress formula แล้วให้ endpoint อื่นใช้ร่วมกัน

---

### 2.17 Estimated Days to Goal

ใน `/goal_progress` ใช้น้ำหนักย้อนหลังล่าสุด 14 รายการ

```text
day_gap = newest_date - oldest_date
kg_diff = abs(newest_weight - oldest_weight)
rate = kg_diff / day_gap
estimated_days = remaining_kg / rate
```

ข้อจำกัด: ใช้ `abs()` จึงไม่รู้ว่าผู้ใช้กำลังไปถูกทางหรือผิดทาง ถ้าน้ำหนักเปลี่ยนผิดทิศ ระบบยังอาจคำนวณวันถึงเป้าหมายให้

สูตรที่ควรใช้:

```text
lose_weight:
  directional_change = oldest_weight - newest_weight

gain_muscle:
  directional_change = newest_weight - oldest_weight

if directional_change <= 0:
  estimated_days = null
else:
  rate = directional_change / day_gap
  estimated_days = remaining_kg / rate
```

---

### 2.18 Gamification Methodology

ระบบ Gamification ฝั่ง Flutter ใช้คะแนนสะสมชื่อ `tama_points`

Tier ปัจจุบัน:

| Tier index | ชื่อ | คะแนนขั้นต่ำ | multiplier |
|---:|---|---:|---:|
| 0 | ติ๊ด | 0 | 1.0 |
| 1 | ต้อย | 100 | 1.2 |
| 2 | แต้ว | 300 | 1.5 |
| 3 | โต้ง | 600 | 1.8 |
| 4 | พราว | 1000 | 2.0 |
| 5 | วิ้งค์ | 2000 | 2.5 |

Mission:

| mission_id | เงื่อนไข | base points |
|---|---|---:|
| open_app | เปิดแอพวันนี้ | 2 |
| log_meal | calories วันนี้มากกว่า 0 | 5 |
| hit_all_macros | protein, carbs, fat ถึงเป้าทั้งหมด | 20 |
| hit_calories | calories อยู่ในช่วง 80% - 110% ของเป้า | 15 |
| streak_3 | streak >= 3 วัน | 10 |

สูตรคะแนนเมื่อ claim mission:

```text
earned_points = round(base_points * tier_multiplier)
new_total_points = old_total_points + earned_points
```

สูตรเลื่อน tier:

```text
earnedTier = tier สูงสุดที่ new_total_points >= tier.minPts
maxTier = max(oldMaxTier, earnedTier)
```

หมายเหตุ: Tier ไม่ลดลงแม้ผู้ใช้ใช้คะแนนแลกรางวัล เพราะระบบใช้ `maxTier` เพื่อรักษาสถานะที่เคยทำได้สูงสุด

---

### 2.19 Reward Shop Methodology

Reward shop ใช้คะแนนสะสมแลกรางวัล

หลักการ:

```text
if total_points >= reward.cost และ reward ยังไม่เคยแลก:
  total_points = total_points - reward.cost
  add reward.id เข้า claimed_badges
  sync ไป backend
```

สถานะ reward:

| สถานะ | เงื่อนไข |
|---|---|
| แลกได้ | reward available และคะแนนพอ และยังไม่เคยแลก |
| คะแนนไม่พอ | reward available แต่คะแนนน้อยกว่า cost |
| แลกแล้ว | reward id อยู่ใน claimed_badges |
| ยังไม่เปิดใช้งาน | reward marked coming soon |

---

### 2.20 AI Meal Estimate Methodology

Flow ที่ออกแบบไว้:

1. ผู้ใช้พิมพ์ข้อความ เช่น “ข้าวผัดกะเพรา 1 จาน ต้มยำกุ้งครึ่งถ้วย”
2. Flutter เรียก `POST /api/meals/estimate`
3. Backend sanitize ข้อความ
4. Backend ใช้ nutrition agent แยกชื่ออาหารและปริมาณ
5. Backend วิเคราะห์ calories และ macro
6. Flutter แสดงรายการให้ผู้ใช้ตรวจ
7. ผู้ใช้กดบันทึก
8. Flutter เรียก `POST /meals/{user_id}`

ข้อสำคัญของ data contract:

```text
ถ้า backend ส่ง calories เป็น "ต่อ 1 หน่วย":
  Flutter ต้องส่ง amount = quantity และ cal_per_unit = calories_per_unit

ถ้า backend ส่ง calories เป็น "รวมตาม quantity แล้ว":
  Flutter ต้องส่ง amount = 1 หรือแปลงกลับเป็น per_unit ก่อนบันทึก
```

ปัจจุบัน Flutter ส่ง:

```text
amount = item.quantity
cal_per_unit = item.calories
protein_per_unit = item.protein
carbs_per_unit = item.carbs
fat_per_unit = item.fat
```

ดังนั้นต้องยืนยันว่า backend ส่งค่าเป็น per unit จริงหรือไม่ ถ้า backend ส่งค่าแบบรวมแล้ว จะเกิด double count ทันที

---

## 3. Bug และ Risk ที่พบในแอพปัจจุบัน

### 3.1 ตารางสรุประดับความรุนแรง

| ระดับ | จำนวน | ความหมาย |
|---|---:|---|
| Critical | 5 | มีโอกาสทำให้ระบบหลักพัง, ข้อมูลผิดมาก, หรือมีช่องโหว่สิทธิ์ |
| High | 7 | ทำให้ผลลัพธ์ผู้ใช้ผิด, UX เสีย, หรือข้อมูลสะสมผิด |
| Medium | 8 | ควรแก้เพื่อความถูกต้อง ความเสถียร และ maintainability |
| Low | 3 | ปรับปรุงคุณภาพ code / logging / consistency |

---

### 3.2 รายการปัญหาแบบละเอียด

| ID | Severity | จุดบกพร่อง | หลักฐานจากโค้ด | ผลกระทบ | วิธีแก้ที่เสนอ |
|---|---|---|---|---|---|
| BUG-001 | Critical | โฟลเดอร์ `backend/ai_models` ไม่มีอยู่ใน workspace แต่ backend import `ai_models.multi_agent_system` และ `ai_models.llm_provider` | `backend/app/routers/chat.py`, `backend/app/routers/foods.py`, `Test-Path backend/ai_models = False` | Backend อาจ start ไม่ขึ้น หรือ endpoint AI/recipe ล้มเหลวทันที | Restore module ที่ถูกลบ, หรือปิด router/feature ด้วย kill switch ให้ import แบบ lazy, แล้วเพิ่ม startup test |
| BUG-002 | Critical | Endpoint gamification `/users/{user_id}/tama-points` ไม่มี auth และ ownership guard | `backend/app/routers/users.py` | ผู้ใช้หรือ attacker อาจอ่าน/แก้คะแนนของ user_id อื่นได้ | เพิ่ม `Depends(get_current_user)`, เรียก `check_ownership`, validate payload |
| BUG-003 | Critical | `check_ownership` ปล่อยผ่านเมื่อ `token_user_id is None` | `backend/app/core/dependencies.py` | ถ้า auth metadata ผิดหรือ lookup user ไม่ได้ อาจกลายเป็นเข้าถึง resource ได้ | ถ้า `token_user_id is None` ให้ `raise HTTPException(401/403)` |
| BUG-004 | Critical | `POST /foods` และ `PUT /foods/{food_id}` ไม่มี admin guard แต่ `PATCH/DELETE` มี | `backend/app/routers/foods.py` | คนทั่วไปอาจเพิ่มหรือแก้ฐานข้อมูลอาหารหลักได้ | ใส่ `Depends(get_current_admin)` ให้ POST/PUT หรือย้าย user suggestion ไป temp_food เท่านั้น |
| BUG-005 | Critical | AI meal estimate มีความเสี่ยง double count quantity | Flutter ส่ง `amount = quantity` และ `cal_per_unit = calories` | ถ้า backend ส่ง calories แบบรวมแล้ว อาหาร 2 จานจะถูกนับเป็น 4 จานเชิงแคลอรี | นิยาม contract ชัดเจน เช่น backend ส่ง `calories_per_unit` และ `total_calories` แยกกัน |
| BUG-006 | High | การบันทึกน้ำไม่ใช้วันที่ที่ผู้ใช้เลือก | Backend ใช้ `CURRENT_DATE` ใน `water.py` | ผู้ใช้เลือกวันย้อนหลังแล้วบันทึกน้ำ แต่ข้อมูลไปลงวันนี้ | เพิ่ม `date_record` ใน schema และใช้ค่านั้นใน upsert |
| BUG-007 | High | Goal progress ใช้ `abs()` ทำให้ไม่รู้ทิศทาง | `/goal_progress` ใช้ `abs(target-start)` และ `abs(current-start)` | ลดน้ำหนักผิดทางแต่ progress อาจเพิ่ม | ใช้สูตร directional ตาม goal_type |
| BUG-008 | High | Estimated days ใช้ `abs()` ทำให้คำนวณวันถึงเป้าทั้งที่ไปผิดทาง | `kg_diff = abs(newest-oldest)` | Dashboard อาจให้ความหวังผิดหรือคำแนะนำผิด | ถ้า direction ไม่ถูกต้องให้ `estimated_days = null` |
| BUG-009 | High | สูตร target calories มีหลายชุดและไม่ตรงกัน | `nutrition_service.py`, `users.py`, `user_data_provider.dart` | ผู้ใช้เห็น target ต่างกันตามหน้าจอหรือ timing การ sync | ทำ backend เป็น single source of truth และให้ Flutter ใช้ stored values |
| BUG-010 | High | สูตร macro backend กับ Flutter fallback ไม่เหมือนกัน | Backend ใช้ g/kg ก่อน, Flutter ใช้ ratio | Macro target อาจไม่ตรงกัน | ให้ backend ส่ง `target_protein/carbs/fat` เสมอหลัง onboarding/recalc |
| BUG-011 | High | `extra_active` รองรับไม่ครบทุกสูตร | Flutter มี 1.9, backend บางสูตรไม่มี | ผู้ใช้ออกกำลังหนักมากอาจได้ TDEE ต่ำ | เพิ่ม `extra_active: 1.9` ในทุก formula map และ test |
| BUG-012 | High | Notification type `warning/tip` อาจไม่ตรง enum ฐานข้อมูล | Code insert type `warning`, `tip` | Insert notification อาจ fail เงียบ เพราะบางจุด `except Exception: pass` | ตรวจ enum live, migration เพิ่ม type หรือ map เป็น enum ที่มีอยู่ |
| BUG-013 | Medium | `get_weight_logs` query `ORDER BY recorded_date ASC LIMIT 30` ทำให้ได้ 30 รายการเก่าสุด | `backend/app/routers/weight.py` | กราฟน้ำหนักอาจไม่แสดงข้อมูลล่าสุดเมื่อมี log เกิน 30 วัน | Query DESC LIMIT 30 แล้ว reverse ก่อนส่ง |
| BUG-014 | Medium | วันที่ใน backend ใช้ `date.today()` / `CURRENT_DATE` โดยไม่กำหนด timezone ของผู้ใช้ | หลาย router | ผู้ใช้อยู่ Asia/Bangkok อาจเจอข้อมูลเหลื่อมวันถ้า server timezone เป็น UTC | ใช้ user timezone หรือกำหนด service timezone ชัดเจน |
| BUG-015 | Medium | `GET /water_logs/{user_id}` ถ้า date format ผิดจะกลายเป็น 500 | `date.fromisoformat(date_record)` อยู่นอก try | UX/API contract ไม่ดี | จับ `ValueError` แล้วตอบ 400 |
| BUG-016 | Medium | Notification insert หลัง meal swallow error | `except Exception: pass` | Production ไม่รู้ว่า notification พัง | log exception ด้วย logger และ metric |
| BUG-017 | Medium | `POST /foods/auto-add` รับ `user_id` จาก body โดยไม่มี auth ownership | `backend/app/routers/foods.py` | ผู้ใช้ส่ง suggestion แทน user อื่นได้ | ใช้ current user จาก token แทน body user_id |
| BUG-018 | Medium | `POST /recipes/{food_id}/review` ไม่มี auth guard และรับ `user_id` จาก body | `backend/app/routers/social.py` | รีวิวปลอมในนาม user อื่นได้ | เพิ่ม auth, ใช้ `current_user.user_id`, ไม่รับ user_id จาก client |
| BUG-019 | Medium | มี endpoint debug auth ใน production surface | `backend/app/routers/health.py` | อาจเผยข้อมูล auth/session เกินจำเป็น | เปิดเฉพาะ non-production หรือ require admin |
| BUG-020 | Medium | Lifecycle/on-track logic มีแนวโน้มใช้ current weight เป็น start weight | `backend/app/routers/users.py` lifecycle logic | สถานะ on-track อาจผิด | ใช้ goal_start_date และ first weight log จริงเป็น baseline |
| BUG-021 | Low | `normalize_calories` เฉลี่ยแบบง่าย ไม่ตัด outlier | `nutrition_service.py` | LLM/data source ผิดค่าหนึ่งอาจดึงค่าเฉลี่ยเพี้ยน | ใช้ median หรือ trimmed mean เมื่อมีหลาย source |
| BUG-022 | Low | fallback ค่า default หลายจุดไม่เหมือนกัน | Backend 2000, Flutter BMR 1500, age 20 | Debug ยากและผลลัพธ์ไม่สม่ำเสมอ | รวม constants ไว้ที่เดียวและทำ API config |
| BUG-023 | Low | บาง comment/emoji ใน Flutter มี encoding เพี้ยนใน terminal | `tamagotchi_screen.dart` บาง emoji แสดงเป็น replacement char ใน output | ไม่กระทบ runtime เสมอไป แต่กระทบ maintainability | ตรวจ encoding UTF-8 และแก้ข้อความที่เพี้ยน |

---

## 4. วิธีแก้ไขที่เสนอแบบจัดลำดับ

### 4.1 P0: ต้องแก้ก่อน deploy production

| งาน | รายละเอียด | Acceptance Criteria |
|---|---|---|
| Restore หรือ isolate AI modules | คืน `backend/ai_models` หรือปรับ import เป็น lazy และปิด route เมื่อ AI disabled | Backend start ผ่าน, `/health` ผ่าน, AI disabled แล้วไม่ crash |
| Lock ownership guard | `token_user_id is None` ต้องไม่ผ่าน | Test unauthorized/malformed token ได้ 401/403 |
| Lock gamification endpoints | เพิ่ม auth + ownership ให้ GET/PATCH tama-points | User A แก้คะแนน User B ไม่ได้ |
| Lock food admin endpoints | POST/PUT foods ต้องใช้ admin | Non-admin ได้ 403 |
| Lock review/auto-add identity | ใช้ user id จาก token | Client ปลอม user_id ไม่ได้ |

---

### 4.2 P1: แก้ความถูกต้องของข้อมูลผู้ใช้

| งาน | รายละเอียด | Acceptance Criteria |
|---|---|---|
| Fix water selected date | เพิ่ม `date_record` ใน `WaterLogUpdate` และใช้ใน upsert | เลือกวันย้อนหลังแล้วบันทึกตรงวัน |
| Fix goal progress | ใช้ directional formula ตาม goal_type | ไปผิดทาง progress = 0 หรือไม่เพิ่ม |
| Fix estimated days | คำนวณเฉพาะเมื่อ trend ไปถูกทาง | trend ผิดทางส่ง `estimated_days = null` |
| Fix AI meal contract | แยก `per_unit` กับ `total` ชัดเจน | Quantity 2 ไม่ double count |
| Fix notification enum | migration/enum ให้ตรงกับ code หรือ map type | Insert warning/tip สำเร็จและมี test |

---

### 4.3 P2: รวมสูตรให้เป็นมาตรฐานเดียว

| งาน | รายละเอียด | Acceptance Criteria |
|---|---|---|
| Canonical nutrition engine | รวม BMR/TDEE/target/macro formula ที่ backend | ทุก endpoint ใช้ service เดียว |
| Flutter ใช้ backend target | Flutter ใช้ stored target เป็นหลัก และแสดง loading ถ้ายังไม่มี | ไม่มีหน้าจอคำนวณ target คนละสูตร |
| Support `extra_active` ครบ | activity map เดียวกันทุกที่ | Unit test ครบทุก activity |
| Standard timezone | กำหนด timezone policy เช่น Asia/Bangkok สำหรับ user date | ไม่มี off-by-one date ใน test |
| Improve calorie normalization | ใช้ median/trimmed mean | Outlier ไม่ทำให้ค่าพัง |

---

## 5. สูตรที่ควรปรับให้เป็น Canonical Version

### 5.1 Canonical BMR

```text
function calculate_bmr(weight_kg, height_cm, age, gender):
  if weight_kg <= 0 or height_cm <= 0:
    return null

  base = (10 * weight_kg) + (6.25 * height_cm) - (5 * age)

  if gender == "male":
    return base + 5
  else:
    return base - 161
```

### 5.2 Canonical TDEE

```text
activity_factors = {
  sedentary: 1.2,
  lightly_active: 1.375,
  moderately_active: 1.55,
  very_active: 1.725,
  extra_active: 1.9
}

TDEE = BMR * activity_factors[activity_level]
```

### 5.3 Canonical Target Calories

แนะนำให้เลือกแนวนี้ เพราะรองรับทั้งลด เพิ่ม และคงน้ำหนักในสูตรเดียว

```text
weeks = max((goal_target_date - goal_start_date).days / 7, 1)
kg_per_week = (target_weight_kg - current_weight_kg) / weeks
raw_target = TDEE + (kg_per_week * 1100)
```

แต่ควรเพิ่ม guard:

```text
max_loss_rate_kg_per_week = 1.0
max_gain_rate_kg_per_week = 0.5 หรือ 0.75
kg_per_week = clamp(kg_per_week, -max_loss_rate, max_gain_rate)
```

แล้วค่อย clamp calories:

```text
minimum_calories = 1500 สำหรับ male, 1200 สำหรับ female
target_calories = max(raw_target, minimum_calories)
```

ถ้าต้องการ safety สูง:

```text
target_calories = max(raw_target, min(BMR, TDEE), minimum_calories)
```

หมายเหตุ: ไม่ควรใช้ `max(BMR, minimum_calories)` โดยไม่ผ่าน review เพราะอาจทำให้เป้าลดน้ำหนักสูงเกินจำเป็นสำหรับผู้ใช้บางกลุ่ม

### 5.4 Canonical Macros

แนะนำให้ใช้ backend เป็น source of truth และเก็บค่าลง DB

```text
protein_g = weight_kg * protein_factor_by_goal
fat_g = weight_kg * fat_factor_by_goal
remaining_cal = target_calories - (protein_g * 4) - (fat_g * 9)
carbs_g = remaining_cal / 4
```

ถ้า carbs ต่ำเกิน:

```text
ใช้ ratio fallback ตาม goal
```

### 5.5 Canonical Progress

```text
if goal == lose_weight:
  total = start_weight - target_weight
  done = start_weight - current_weight

if goal == gain_muscle:
  total = target_weight - start_weight
  done = current_weight - start_weight

if goal == maintain_weight:
  diff = abs(current_weight - target_weight)
  progress = 1 - diff / max(target_weight, 1)

progress = clamp(done / total, 0, 1)
```

---

## 6. Test Cases ที่ควรเพิ่ม

### 6.1 Unit Tests: Nutrition Formula

| Test | Input | Expected |
|---|---|---|
| BMR male | 70kg, 170cm, 30y | `(10*70)+(6.25*170)-(5*30)+5` |
| BMR female | 60kg, 160cm, 30y | `(10*60)+(6.25*160)-(5*30)-161` |
| TDEE sedentary | BMR 1500 | 1800 |
| TDEE extra_active | BMR 1500 | 2850 |
| Target lose | target lower than current | calories lower than TDEE |
| Target gain | target higher than current | calories higher than TDEE |
| Minimum calories | raw target below minimum | clamped to minimum |

### 6.2 Unit Tests: Macro Formula

| Test | Expected |
|---|---|
| lose_weight ใช้ protein 1.8g/kg |
| gain_muscle ใช้ protein 2.0g/kg |
| maintain ใช้ protein 1.6g/kg |
| carbs ต่ำกว่า 10% แล้ว fallback ratio |
| grams แปลงจาก kcal ถูกต้องด้วย 4/4/9 |

### 6.3 API Tests: Security

| Endpoint | Test |
|---|---|
| `GET /users/{id}/tama-points` | User A อ่าน User B ต้อง 403 |
| `PATCH /users/{id}/tama-points` | User A แก้ User B ต้อง 403 |
| `POST /foods` | Non-admin ต้อง 403 |
| `PUT /foods/{food_id}` | Non-admin ต้อง 403 |
| `POST /foods/auto-add` | user_id ต้องมาจาก token |
| `POST /recipes/{food_id}/review` | user_id ต้องมาจาก token |

### 6.4 API Tests: Water

| Test | Expected |
|---|---|
| POST water วันนี้ | บันทึกวันนี้ |
| POST water วันย้อนหลัง | บันทึกวันที่เลือก |
| GET water invalid date | 400 ไม่ใช่ 500 |
| amount_ml < 0 | 400 |
| amount_ml 500 | glasses = 2 |

### 6.5 API Tests: Goal Progress

| Goal | Start | Current | Target | Expected |
|---|---:|---:|---:|---|
| lose_weight | 80 | 75 | 70 | 50% |
| lose_weight ผิดทาง | 80 | 82 | 70 | 0% |
| gain_muscle | 60 | 65 | 70 | 50% |
| gain_muscle ผิดทาง | 60 | 58 | 70 | 0% |
| maintain | 60 | 60 | 60 | 100% |

### 6.6 Integration Tests: AI Meal Estimate

| Test | Expected |
|---|---|
| ข้าว 1 จาน | บันทึก calories เท่าที่ estimate |
| ข้าว 2 จาน | calories รวมต้องเป็น 2 เท่า ไม่ใช่ 4 เท่า |
| Unknown food | auto-add temp_food สำเร็จเมื่อเปิด AI |
| AI disabled | endpoint ตอบ 503 ไม่ทำให้ backend crash |

---

## 7. สรุปสำหรับกรรมการ

ระบบ Calories Guard มี methodology หลักครบสำหรับ health tracking ได้แก่ BMI, BMR, TDEE, target calories, target macros, daily meal summary, water log, weight progress และ gamification reward loop

จุดแข็งของระบบ:

| จุดแข็ง | รายละเอียด |
|---|---|
| ใช้สูตรโภชนาการมาตรฐาน | BMR ใช้ Mifflin-St Jeor, macro ใช้ g/kg และ Atwater factor |
| มี safe minimum calories | ลดความเสี่ยงการแนะนำพลังงานต่ำเกินไป |
| รองรับ daily tracking ครบ | อาหาร, macro, น้ำ, น้ำหนัก, progress |
| มี gamification | เพิ่ม engagement ผ่าน mission, tier, reward |
| มี AI flow | รองรับการบันทึกอาหารจากข้อความธรรมชาติ |

จุดที่ต้องแก้ก่อนถือว่าสมบูรณ์:

| ประเด็น | เหตุผล |
|---|---|
| Security guard | บาง endpoint ยังแก้ข้อมูลแทน user อื่นได้ |
| AI module missing | อาจทำให้ backend start หรือ feature AI พัง |
| Formula consistency | Backend และ Flutter มีสูตร fallback ไม่ตรงกัน |
| Water selected date | ข้อมูลผู้ใช้อาจบันทึกผิดวัน |
| Goal progress direction | progress อาจผิดเมื่อผู้ใช้เคลื่อนไปผิดทาง |
| AI quantity contract | มีโอกาสนับแคลอรีซ้ำ |

ข้อเสนอสุดท้าย: ให้ทำ backend nutrition service เป็น single source of truth สำหรับทุกสูตร แล้วให้ Flutter แสดงค่าที่ backend คำนวณและบันทึกไว้เป็นหลัก ส่วน Flutter formula ควรเหลือเฉพาะ fallback ชั่วคราวหรือ preview ที่มี label ชัดเจนว่าเป็นค่าประมาณ

