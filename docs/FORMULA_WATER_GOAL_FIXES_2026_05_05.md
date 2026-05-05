# Formula Consistency, Water Date และ Goal Progress Fixes

วันที่จัดทำ: 5 พฤษภาคม 2569  
ขอบเขต: backend nutrition formula, Flutter target display, water log selected date, goal progress direction

---

## 1. ปัญหาที่แก้

| ปัญหา | ผลกระทบเดิม | สถานะ |
|---|---|---|
| Formula consistency | Backend และ Flutter มี fallback/สูตรบางส่วนไม่ตรงกัน | แก้ให้ backend เป็น source of truth และ Flutter label fallback เป็นค่าประมาณ |
| Water selected date | ผู้ใช้เลือกวันย้อนหลัง แต่ backend บันทึกเป็น `CURRENT_DATE` | แก้ให้ POST water ใช้ `date_record` จาก client |
| Goal progress direction | progress ใช้ `abs()` ทำให้เดินผิดทางก็อาจนับ progress | แก้เป็น directional formula ตาม `goal_type` |

---

## 2. Formula Consistency

### 2.1 Backend เป็น source of truth

ปรับ `POST /users/{user_id}/recalc_tdee` ให้ใช้ service เดียวกับ endpoint อื่น:

```python
new_target = _compute_target_calories(dict(u))
target_protein, target_carbs, target_fat = _compute_target_macros(...)
```

ผลลัพธ์ที่บันทึกลง `users`:

```text
target_calories
target_protein
target_carbs
target_fat
last_tdee_recalc_date
```

### 2.2 รองรับ `extra_active` ให้ครบ

เพิ่ม activity multiplier ใน backend canonical formula:

```text
extra_active = 1.9
```

ก่อนหน้า Flutter รองรับ `extra_active` แต่ `_compute_target_calories` ของ backend ไม่รองรับ ทำให้ target อาจต่ำกว่าที่ควร

### 2.3 Flutter ใช้ backend target ก่อน

Flutter provider ใช้ค่า stored จาก backend เป็นหลัก:

```dart
storedTargetCalories
storedTargetProtein
storedTargetCarbs
storedTargetFat
```

ถ้ายังไม่มีค่า stored จึงคำนวณ fallback ในเครื่อง และแสดง label เป็นค่าประมาณ:

```text
เป้าหมาย (ประมาณ)
ประมาณจากข้อมูลในเครื่อง
```

หลักการ:

```text
มี backend target -> แสดงเป็นเป้าหมายจริง
ไม่มี backend target -> ใช้ fallback preview ชั่วคราวพร้อม label ประมาณ
```

---

## 3. Water Selected Date

### 3.1 Schema

เพิ่ม:

```python
class WaterLogUpdate(BaseModel):
    amount_ml: int
    date_record: date | None = None
```

### 3.2 GET validation

ถ้า query `date_record` format ผิด:

```text
400 date_record must be YYYY-MM-DD
```

ไม่ปล่อยให้กลายเป็น 500

### 3.3 POST ใช้วันที่ที่เลือก

ก่อนแก้:

```sql
VALUES (%s, CURRENT_DATE, %s, %s)
```

หลังแก้:

```sql
VALUES (%s, target_date, %s, %s)
```

โดย:

```text
target_date = entry.date_record or date.today()
```

ผลลัพธ์:

```text
ผู้ใช้เลือกวันที่ย้อนหลัง -> water_logs.date_record เป็นวันที่ย้อนหลังจริง
```

---

## 4. Goal Progress Direction

### 4.1 ปัญหาเดิม

เดิมใช้:

```python
needed = abs(target - start)
done = abs(current - start)
```

กรณีลดน้ำหนัก:

```text
start = 80
target = 70
current = 82
```

ระบบเดิมอาจนับว่า progress เพิ่ม เพราะ `abs(82 - 80) = 2`

### 4.2 สูตรใหม่

ลดน้ำหนัก:

```text
total = start_weight - target_weight
done = start_weight - current_weight
progress = clamp(done / total, 0, 1)
```

เพิ่มกล้าม/เพิ่มน้ำหนัก:

```text
total = target_weight - start_weight
done = current_weight - start_weight
progress = clamp(done / total, 0, 1)
```

คงน้ำหนัก:

```text
diff = abs(current_weight - target_weight)
progress = clamp(1 - diff / max(target_weight, 1), 0, 1)
```

### 4.3 Estimated days

เดิมใช้ `abs(newest - oldest)` ทำให้ไปผิดทางก็ยังคำนวณวันถึงเป้าหมาย

ใหม่:

```text
lose_weight:
  directional_change = oldest_weight - newest_weight

gain_muscle:
  directional_change = newest_weight - oldest_weight

if directional_change <= 0:
  estimated_days = null
```

เพิ่ม field:

```text
moving_toward_goal
```

เพื่อให้ Flutter/QA รู้ว่า trend กำลังไปถูกทางหรือไม่

---

## 5. QA Checklist

| Test | Expected |
|---|---|
| POST `/water_logs/{user_id}` พร้อม `date_record=2026-05-01` | row ถูกบันทึกวันที่ `2026-05-01` |
| GET `/water_logs/{user_id}?date_record=bad` | 400 |
| lose weight: start 80, current 75, target 70 | progress 50% |
| lose weight ผิดทาง: start 80, current 82, target 70 | progress 0%, `estimated_days=null` |
| gain muscle: start 60, current 65, target 70 | progress 50% |
| gain muscle ผิดทาง: start 60, current 58, target 70 | progress 0%, `estimated_days=null` |
| Flutter มี `storedTargetCalories` | label `เป้าหมาย` |
| Flutter ไม่มี stored target | label `เป้าหมาย (ประมาณ)` |

---

## 6. ไฟล์ที่แก้

| ไฟล์ | รายละเอียด |
|---|---|
| `backend/app/models/schemas.py` | เพิ่ม `WaterLogUpdate.date_record` |
| `backend/app/routers/water.py` | ใช้ selected date และ validate date format |
| `backend/app/routers/weight.py` | แก้ progress ตามทิศทาง goal |
| `backend/app/services/nutrition_service.py` | เพิ่ม `extra_active` |
| `backend/app/routers/users.py` | ให้ `recalc_tdee` ใช้ canonical backend formula และบันทึก macro |
| `flutter_application_1/lib/providers/user_data_provider.dart` | เพิ่ม flag backend target/fallback estimate |
| `flutter_application_1/lib/screens/app_home_screen.dart` | แสดง label ค่าประมาณเมื่อใช้ Flutter fallback |

