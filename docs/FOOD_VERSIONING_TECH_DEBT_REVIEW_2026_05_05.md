# Food Versioning และ Technical Debt Review

วันที่จัดทำ: 5 พฤษภาคม 2569  
บทบาท: Senior Database / Developer / QA Tester / Software Engineer / DevOps  
ขอบเขต: การเปลี่ยนแปลงเมนูอาหารในฐานข้อมูล, ผลกระทบต่อ user history, food catalog governance

---

## 1. ปัญหาหลัก

เมนูอาหารใน `foods` เป็น master data ที่แก้ไขได้ แต่รายการอาหารที่ผู้ใช้บันทึกใน `detail_items` เป็น historical fact

หากแก้ `foods` แล้วระบบเอาค่าใหม่ไปทับ log เก่า จะเกิดปัญหา:

| เหตุการณ์ | ผลเสีย |
|---|---|
| ผู้ใช้บันทึกข้าวมันไก่ 596 kcal วันนี้ | ประวัติวันนี้ควรคง 596 kcal |
| Admin แก้ข้าวมันไก่เป็น 650 kcal พรุ่งนี้ | ประวัติเก่าไม่ควรเปลี่ยนตาม |
| ระบบ sync ค่า `foods` ไป `detail_items` | Dashboard/history ของผู้ใช้เปลี่ยนย้อนหลัง ผิดหลัก audit |

หลักการที่ถูกต้อง:

```text
foods = mutable catalogue
food_versions = immutable version history
detail_items = historical snapshot at record time
```

---

## 2. Technical Debt ที่พบ

### 2.1 Trigger เก่าทำให้ประวัติ user ถูก rewrite

พบใน migration เดิม:

```text
backend/migrations/v24_audit_columns_and_sync_triggers.sql
```

มี trigger:

```text
trg_foods_sync_detail_items
```

เจตนาเดิมคือเมื่อแก้ `foods` ให้ propagate ค่าใหม่ไป `detail_items`

ข้อเสีย:

| ปัญหา | ความรุนแรง |
|---|---|
| แก้ master data แล้วประวัติ user เปลี่ยนย้อนหลัง | Critical |
| daily summary / insight อาจ drift จากสิ่งที่ user เห็นตอนบันทึก | High |
| audit ย้อนหลังไม่ได้ว่า user บันทึกจากข้อมูล version ไหน | High |

การแก้:

```sql
DROP TRIGGER IF EXISTS trg_foods_sync_detail_items ON cleangoal.foods;
DROP FUNCTION IF EXISTS cleangoal.fn_sync_detail_items_from_foods();
```

---

### 2.2 ไม่มี food version history

ก่อนแก้ `foods` มีค่า current เพียงชุดเดียว เช่น:

```text
foods.food_name
foods.calories
foods.protein
foods.carbs
foods.fat
```

เมื่อแก้เมนู ไม่มีประวัติ version เก่าให้ trace

การแก้: เพิ่ม `food_versions`

---

### 2.3 detail_items มี snapshot บางส่วน แต่ไม่มี version pointer

เดิม `detail_items` มี:

```text
food_name
cal_per_unit
protein_per_unit
carbs_per_unit
fat_per_unit
```

ถือว่าถูกทาง เพราะเป็น snapshot ต่อ log แต่ยังขาด:

| สิ่งที่ขาด | ผลกระทบ |
|---|---|
| `food_version_id` | ไม่รู้ว่าบันทึกจาก food version ไหน |
| `food_snapshot` | ไม่มี snapshot รวมแบบ JSON สำหรับ audit |

การแก้:

```text
detail_items.food_version_id -> food_versions.food_version_id
detail_items.food_snapshot JSONB
```

---

### 2.4 Hard delete food เสี่ยงกับ historical data

เดิม `DELETE /foods/{food_id}` ใช้ hard delete:

```sql
DELETE FROM foods WHERE food_id = %s
```

ข้อเสีย:

| ปัญหา | ผลกระทบ |
|---|---|
| ถ้าเมนูเคยถูกใช้ใน log แล้วลบจริง | FK อาจ fail หรือข้อมูลอ้างอิงหาย |
| recipe/ingredients/favorites อาจ cascade หาย | audit เสีย |
| user history ไม่ควรถูกกระทบจาก admin cleanup | UX และ trust เสีย |

การแก้ใน backend:

```sql
UPDATE foods
SET deleted_at = COALESCE(deleted_at, NOW()),
    updated_at = NOW()
WHERE food_id = %s
  AND deleted_at IS NULL
```

และ `GET /foods`, `GET /recommended-food`, `GET /recipes/{food_id}` จะกรอง `deleted_at IS NULL`

---

### 2.5 POST/PUT foods ยังไม่บังคับ admin

พบว่า:

| Endpoint | สถานะเดิม |
|---|---|
| `POST /foods` | ไม่บังคับ admin |
| `PUT /foods/{food_id}` | ไม่บังคับ admin |
| `PATCH /foods/{food_id}` | บังคับ admin |
| `DELETE /foods/{food_id}` | บังคับ admin |

การแก้:

```python
current_user: dict = Depends(get_current_admin)
```

เพิ่มให้ `POST /foods` และ `PUT /foods/{food_id}`

---

## 3. Schema ที่เพิ่ม

ไฟล์ migration:

```text
backend/migrations/v26_food_versioning_and_log_snapshots.sql
```

### 3.1 `food_versions`

เก็บ version ของ `foods` ทุกครั้งที่มีการสร้างหรือแก้ไขข้อมูลสำคัญ

| Column | ความหมาย |
|---|---|
| `food_version_id` | PK ของ version |
| `food_id` | FK กลับไป `foods` |
| `version_number` | ลำดับ version ต่อเมนู |
| `food_name` | snapshot ชื่อเมนู |
| `calories/protein/carbs/fat` | snapshot nutrition |
| `serving_quantity/serving_unit_id` | snapshot serving |
| `is_current` | version ปัจจุบันของเมนู |
| `effective_from` | เริ่มใช้ version นี้ |
| `effective_to` | สิ้นสุด version นี้ |
| `source` | backfill/insert/update |
| `change_reason` | เหตุผลการเปลี่ยน |

### 3.2 `foods.current_version_id`

ชี้ไป version ปัจจุบัน:

```text
foods.current_version_id -> food_versions.food_version_id
```

### 3.3 `detail_items.food_version_id`

ชี้ว่า log นี้ถูกบันทึกจาก food version ใด:

```text
detail_items.food_version_id -> food_versions.food_version_id
```

### 3.4 `detail_items.food_snapshot`

เก็บ JSON snapshot ตอนบันทึก เช่น:

```json
{
  "food_id": 1,
  "food_version_id": 14,
  "food_name": "ข้าวมันไก่ต้ม",
  "amount": 1,
  "cal_per_unit": 596,
  "protein_per_unit": 20,
  "carbs_per_unit": 50,
  "fat_per_unit": 10,
  "snapshot_source": "detail_item_insert"
}
```

---

## 4. Trigger ใหม่

### 4.1 `trg_foods_create_version_insert`

เมื่อ insert food ใหม่:

```text
INSERT foods
-> create food_versions version 1
-> foods.current_version_id = version 1
```

### 4.2 `trg_foods_create_version_update`

เมื่อ update field สำคัญของ food:

```text
UPDATE foods nutrition/name/serving
-> mark old food_versions.is_current = false
-> set old effective_to = now()
-> insert new food_versions version_number + 1
-> foods.current_version_id = new version
```

### 4.3 `trg_detail_items_set_food_snapshot`

เมื่อ insert detail item:

```text
if food_version_id is null:
  food_version_id = foods.current_version_id

if food_snapshot is null:
  food_snapshot = JSON จากค่าที่ insert เข้า detail_items
```

ข้อสำคัญ: trigger นี้ไม่ดึง nutrition จาก `foods` ไปทับค่าใน log แต่ snapshot จากค่าที่กำลังถูกบันทึก

---

## 5. QA Verification ที่ทำแล้ว

### 5.1 หลัง apply migration

ผลตรวจ Supabase:

| Check | Result |
|---|---:|
| `food_versions` | 113 rows |
| `foods` ที่ไม่มี `current_version_id` | 0 rows |
| `detail_items` ที่ไม่มี `food_snapshot` | 0 rows |
| migration version | `v26_food_versioning_and_log_snapshots` |

### 5.2 ตรวจ trigger

Trigger ที่เหลือ:

| Trigger | Event |
|---|---|
| `trg_foods_create_version_insert` | INSERT on foods |
| `trg_foods_create_version_update` | UPDATE on foods |
| `trg_detail_items_set_food_snapshot` | INSERT on detail_items |

Trigger ที่ถูกเอาออก:

```text
trg_foods_sync_detail_items
```

### 5.3 Rollback test: update food

ทดสอบใน transaction แล้ว rollback:

```text
ก่อนแก้ food_id=1 calories=596, versions=1
update calories = 597
เกิด food_versions version 2
version 1 is_current=false
version 2 is_current=true
rollback สำเร็จ
```

### 5.4 Rollback test: insert detail_items

ทดสอบ insert detail item แล้ว rollback:

```text
detail_items.food_version_id = current food version
detail_items.food_snapshot ถูกสร้างอัตโนมัติ
rollback สำเร็จ
```

---

## 6. Technical Debt เพิ่มเติมที่ยังแนะนำให้แก้

| ID | Debt | ความเสี่ยง | แนวทางแก้ |
|---|---|---|---|
| TD-001 | `recipes` ยังผูกกับ `foods` current ไม่ใช่ `food_versions` | ถ้า recipe/ingredients เปลี่ยนตามเมนู อาจไม่รู้ว่าสูตร version ไหน | เพิ่ม `recipe_versions` หรือผูก recipe กับ `food_version_id` ใน phase ถัดไป |
| TD-002 | `food_ingredients` ยังผูก `food_id` | composition ปัจจุบันอาจเปลี่ยน โดยไม่มี version composition | เพิ่ม `food_version_ingredients` หรือ version group ของ ingredients |
| TD-003 | `foods` ยังเป็นทั้ง current cache และ master catalog | อาจมี data drift ระหว่าง `foods` กับ `food_versions` | ระยะยาวให้ `foods` เป็น lightweight identity/current pointer และอ่านค่าจาก `food_versions` |
| TD-004 | `detail_items` ยังอนุญาต update snapshot ได้ | Admin/bug อาจแก้ log ย้อนหลัง | เพิ่ม audit trigger หรือ policy ห้าม update nutrition fields หลัง insert ยกเว้น explicit correction flow |
| TD-005 | `food_snapshot` เป็น JSONB ไม่มี schema validation | อาจมี key ไม่ครบ | เพิ่ม check ผ่าน trigger หรือ generated read view |
| TD-006 | `POST /foods/auto-add` ยังรับ `user_id` จาก body | ผู้ใช้ปลอม user_id ได้ | ใช้ `get_current_user` และ user_id จาก token |
| TD-007 | `POST /recipes/{food_id}/review` ยังรับ `user_id` จาก body | รีวิวแทน user อื่นได้ | ใช้ current user จาก auth |
| TD-008 | AI modules ใน workspace หายแต่ router ยัง import | backend อาจ start fail ในบาง environment | restore module หรือ lazy import เมื่อ `AI_ENABLED=true` |

---

## 7. Recommendation Roadmap

### P0: เสร็จแล้วในรอบนี้

| งาน | สถานะ |
|---|---|
| หยุด trigger ที่ rewrite `detail_items` | Done |
| เพิ่ม `food_versions` | Done |
| เพิ่ม `foods.current_version_id` | Done |
| เพิ่ม `detail_items.food_version_id` | Done |
| เพิ่ม `detail_items.food_snapshot` | Done |
| เปลี่ยน delete food เป็น soft delete | Done |
| ปิด POST/PUT foods ให้ admin-only | Done |

### P1: ควรทำถัดไป

| งาน | เหตุผล |
|---|---|
| เพิ่ม `recipe_versions` | กันสูตรอาหารเปลี่ยนย้อนหลัง |
| เพิ่ม `food_version_ingredients` | กัน composition/ingredient เปลี่ยนย้อนหลัง |
| เพิ่ม audit log สำหรับ admin food changes | รู้ว่าใครแก้อะไรเมื่อไร |
| ปรับ recipe API ให้แสดง version info | QA/debug ง่ายขึ้น |

### P2: Long-term

| งาน | เหตุผล |
|---|---|
| สร้าง admin workflow: draft -> review -> publish version | ลดการแก้ production catalog ผิด |
| เพิ่ม data quality checks | ตรวจ kcal จาก macro/ingredient sum เทียบ `foods.calories` |
| เพิ่ม monitoring query | แจ้งเตือนถ้า food ไม่มี current version หรือ detail item ไม่มี snapshot |

---

## 8. Query สำหรับตรวจ Production

### 8.1 หา food ที่ไม่มี current version

```sql
SELECT food_id, food_name
FROM cleangoal.foods
WHERE deleted_at IS NULL
  AND current_version_id IS NULL;
```

### 8.2 หา detail item ที่ไม่มี snapshot

```sql
SELECT item_id, food_id, food_name
FROM cleangoal.detail_items
WHERE food_snapshot IS NULL;
```

### 8.3 ดู version history ของเมนู

```sql
SELECT
    food_id,
    version_number,
    food_name,
    calories,
    protein,
    carbs,
    fat,
    is_current,
    effective_from,
    effective_to
FROM cleangoal.food_versions
WHERE food_id = 1
ORDER BY version_number;
```

### 8.4 ตรวจว่า trigger เก่าไม่อยู่แล้ว

```sql
SELECT trigger_name
FROM information_schema.triggers
WHERE event_object_schema = 'cleangoal'
  AND event_object_table = 'foods'
  AND trigger_name = 'trg_foods_sync_detail_items';
```

ควรได้ 0 rows

---

## 9. สรุป

การแก้ครั้งนี้ทำให้ระบบแยก master data กับ historical fact ชัดเจน:

```text
แก้เมนูใหม่ -> สร้าง food_versions ใหม่
บันทึกอาหารใหม่ -> detail_items เก็บ food_version_id + food_snapshot
ประวัติเก่า -> ไม่ถูก rewrite จาก foods อีกต่อไป
ลบเมนู -> soft delete ไม่ทำลาย history
```

นี่เป็นฐานที่จำเป็นก่อนขยายไปสู่ `recipe_versions` และ `food_version_ingredients` ใน phase ต่อไป

