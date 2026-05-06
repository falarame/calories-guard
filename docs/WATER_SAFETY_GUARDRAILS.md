# Water Safety Guardrails

Calories Guard มี reminder ดื่มน้ำตามเวลาอยู่แล้ว และเอกสารนี้อธิบาย guardrail ใหม่ที่ตรวจจากข้อมูลจริงหลังผู้ใช้บันทึกน้ำ

## เป้าหมาย

ช่วยเตือนผู้ใช้เมื่อใกล้จบวันแล้วปริมาณน้ำที่บันทึกยังต่ำกว่าเป้าหมาย โดยไม่รบกวนช่วงเช้าหรือกลางวันที่ผู้ใช้อาจยังดื่มไม่ครบตามธรรมชาติ

## ค่าเริ่มต้น

```text
water_target_ml = 2000 ml/day
1 glass = 250 ml
default UI goal = 8 glasses/day
```

ค่า 2,000 ml เป็นค่าเริ่มต้นของแอพ ไม่ใช่ข้อกำหนดทางการแพทย์ตายตัว ผู้ใช้บางกลุ่ม เช่น นักกีฬา ผู้มีโรคไต/หัวใจ หญิงตั้งครรภ์ หรือผู้ที่แพทย์จำกัดน้ำ ควรใช้คำแนะนำเฉพาะบุคคล

## กฎแจ้งเตือน

ระบบจะประเมินวันปัจจุบันหลัง 18:00 หรือประเมินวันที่ผ่านมาแล้วทันที

| code | เงื่อนไข | severity | ความหมาย |
|---|---|---|---|
| `severe_low_water` | ดื่มน้อยกว่า 50% ของเป้า | warning | วันนี้น้ำต่ำมาก ควรค่อยๆ จิบน้ำเพิ่ม |
| `low_water` | ดื่มน้อยกว่า 75% ของเป้า | info | วันนี้น้ำยังไม่ถึงเป้า |

## Flow

1. ผู้ใช้เพิ่มหรือลดจำนวนแก้วน้ำในหน้า record
2. Flutter ส่ง `POST /water_logs/{user_id}`
3. Backend upsert `water_logs`
4. Backend เรียก `water_safety_service`
5. ถ้าพบความเสี่ยง Backend บันทึก `notifications` แบบไม่ซ้ำในวันเดียวกัน
6. Backend ส่ง `water_safety` กลับไปใน response
7. Flutter แสดง SnackBar และ local notification

## ไฟล์ที่เกี่ยวข้อง

- `backend/app/services/water_safety_service.py`
- `backend/app/routers/water.py`
- `flutter_application_1/lib/screens/record/record_food_screen.dart`
- `flutter_application_1/lib/services/notification_helper.dart`
