# Nutrition Safety Guardrails

เอกสารนี้อธิบายระบบป้องกันแคลอรี่ต่ำเกินไปและ deficit สูงเกินไปของ Calories Guard

## เป้าหมาย

ระบบต้องไม่สนับสนุนให้ผู้ใช้ทำ energy deficit รุนแรงเกินไปโดยไม่ตั้งใจ โดยเฉพาะกรณีลดน้ำหนักเร็ว กินต่ำกว่า BMR/ขั้นต่ำความปลอดภัย หรือกินต่ำต่อเนื่องหลายวัน

## แหล่งคำนวณหลัก

Backend เป็นแหล่งความจริงของ safety guardrail ผ่าน `backend/app/services/nutrition_safety_service.py`

Flutter ใช้ผลจาก backend เป็นหลักหลังบันทึกอาหาร ถ้า backend ส่ง `nutrition_safety` กลับมา Flutter จะแสดง SnackBar และ local notification ทันที

## สูตรที่ใช้

### BMR

ใช้ Mifflin-St Jeor:

```text
Male BMR = 10W + 6.25H - 5A + 5
Female BMR = 10W + 6.25H - 5A - 161
```

โดย:

- `W` = น้ำหนักตัวหน่วยกิโลกรัม
- `H` = ส่วนสูงหน่วยเซนติเมตร
- `A` = อายุหน่วยปี

### TDEE

```text
TDEE = BMR x activity_factor
```

ตัวคูณกิจกรรม:

| activity_level | factor |
|---|---:|
| sedentary | 1.2 |
| lightly_active | 1.375 |
| moderately_active | 1.55 |
| very_active | 1.725 |
| extra_active | 1.9 |

### ขั้นต่ำความปลอดภัย

```text
male_min_safe = max(BMR, 1500)
female_min_safe = max(BMR, 1200)
```

เหตุผล: ระบบต้องไม่ตั้งเป้าหมายต่ำกว่า BMR หรือ floor ขั้นต่ำทั่วไป เพื่อหลีกเลี่ยงการจำกัดพลังงานรุนแรงเกินไป

## กฎแจ้งเตือน

ระบบจะประเมิน low intake หลัง 17:00 สำหรับวันปัจจุบัน หรือประเมินทันทีสำหรับวันที่ผ่านมาแล้ว

ระบบจะไม่แจ้งว่า “กิน 0 kcal” ถ้าไม่มี meal log จริง เพราะอาจเป็นเพียงการลืมบันทึก

| code | เงื่อนไข | severity | ความหมาย |
|---|---|---|---|
| `unsafe_target_calories` | `target_calories < min_safe_calories` | danger | เป้าหมายที่ตั้งไว้ต่ำเกินไป |
| `severe_low_intake` | intake `< 800 kcal` หลัง cutoff และมี food log | danger | วันนี้กินต่ำมาก |
| `below_safe_floor` | intake `< min_safe_calories` หลัง cutoff และมี food log | warning | ต่ำกว่าขั้นต่ำความปลอดภัย |
| `severe_deficit` | deficit `>= 1000 kcal` และ `>= 35% TDEE` | danger | deficit สูงมาก |
| `large_deficit` | deficit `>= 750 kcal` และ `>= 25% TDEE` | warning | deficit ค่อนข้างสูง |
| `consecutive_low_intake` | ต่ำกว่า floor ต่อเนื่อง 3 วัน | danger | pattern เสี่ยง ไม่ใช่แค่วันเดียว |

## Flow การทำงาน

1. ผู้ใช้บันทึกอาหารที่ Flutter
2. Flutter ส่ง `POST /meals/{user_id}`
3. Backend บันทึก meal/detail_items
4. Backend อ่าน total calories ของวันนั้นจาก meal items
5. Backend อ่านข้อมูลผู้ใช้ เช่น เพศ วันเกิด ส่วนสูง น้ำหนัก activity level และ target calories
6. Backend คำนวณ BMR, TDEE, min safe calories
7. Backend ตรวจ safety rules
8. Backend บันทึก notification แบบไม่ซ้ำ title ในวันเดียวกัน
9. Backend ส่ง `nutrition_safety` กลับใน response
10. Flutter แสดง warning ทันทีถ้ามี finding

## ข้อควรระวัง

- อย่านำ exercise calories หรือ active calories จาก wearable มาหักออกจาก intake ซ้ำโดยตรง ถ้า TDEE ใช้ activity factor อยู่แล้ว เพราะเสี่ยง double counting
- ควรใช้ backend เป็นแหล่งคำนวณหลัก ส่วน Flutter ใช้เฉพาะ preview/fallback
- หากอนาคตรองรับผู้ตั้งครรภ์ ให้นมบุตร เด็ก วัยรุ่น เบาหวาน CKD หรือ eating disorder risk ต้องใช้ guardrail เฉพาะกลุ่มแทน floor ทั่วไป

## ไฟล์ที่เกี่ยวข้อง

- `backend/app/services/nutrition_safety_service.py`
- `backend/app/routers/meals.py`
- `backend/app/services/nutrition_service.py`
- `flutter_application_1/lib/screens/record/record_food_screen.dart`
- `flutter_application_1/lib/services/notification_helper.dart`
