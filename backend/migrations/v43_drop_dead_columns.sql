-- v43: ลบคอลัมน์ที่ "ตายชัดเจน" จากผล dead-column audit
--
-- เกณฑ์ที่ใช้ตัดสิน (ทุกคอลัมน์ผ่านครบทั้งหมด):
--   * ข้อมูลจริง non-null = 0 (NULL 100%)
--   * ไม่มีโค้ด backend อ้างถึง (grep)
--   * ไม่มีโค้ด Flutter อ้างถึง (grep) และ backend ไม่ได้ใช้ SELECT *
--   * ไม่มี trigger/function ใน DB อ้างถึง (pg_proc.prosrc)
--   * ไม่มี view อ้างถึง (view_column_usage)
--
-- คอลัมน์ที่ลบ:
--   1. daily_summaries.goal_calories  (integer)        — เป้าแคลอรีคำนวณจาก users แทน
--   2. detail_items.day_number        (integer)        — ฟีเจอร์ meal-plan ที่ไม่ได้ใช้
--   3. detail_items.plan_id           (bigint, FK)     — FK→user_meal_plans ไม่เคยถูกเซ็ต
--   4. detail_items.summary_id        (bigint, FK)     — FK→daily_summaries ไม่เคยถูกเซ็ต
--   5. recipes.source_reference       (varchar)        — ไม่ถูกอ้างถึงที่ใดเลย
--
-- หมายเหตุ: DROP COLUMN จะลบ FK constraint/index ที่ผูกกับคอลัมน์นั้นให้อัตโนมัติ
--   (fk_detail_items_plan, detail_items_summary_id_fkey)
-- ไม่แตะแถวข้อมูลใด ๆ — ลบเฉพาะนิยามคอลัมน์ที่ว่างเปล่า

BEGIN;

ALTER TABLE cleangoal.daily_summaries DROP COLUMN IF EXISTS goal_calories;
ALTER TABLE cleangoal.detail_items     DROP COLUMN IF EXISTS day_number;
ALTER TABLE cleangoal.detail_items     DROP COLUMN IF EXISTS plan_id;
ALTER TABLE cleangoal.detail_items     DROP COLUMN IF EXISTS summary_id;
ALTER TABLE cleangoal.recipes          DROP COLUMN IF EXISTS source_reference;

INSERT INTO cleangoal.schema_migrations(version) VALUES ('v43_drop_dead_columns')
    ON CONFLICT (version) DO NOTHING;

COMMIT;

-- ROLLBACK (เพิ่มคอลัมน์กลับเป็น NULL ได้ แต่ข้อมูลเดิมเป็น NULL อยู่แล้วจึงไม่มีอะไรให้กู้):
-- BEGIN;
-- ALTER TABLE cleangoal.daily_summaries ADD COLUMN IF NOT EXISTS goal_calories integer;
-- ALTER TABLE cleangoal.detail_items    ADD COLUMN IF NOT EXISTS day_number integer;
-- ALTER TABLE cleangoal.detail_items    ADD COLUMN IF NOT EXISTS plan_id bigint REFERENCES cleangoal.user_meal_plans(plan_id);
-- ALTER TABLE cleangoal.detail_items    ADD COLUMN IF NOT EXISTS summary_id bigint REFERENCES cleangoal.daily_summaries(summary_id);
-- ALTER TABLE cleangoal.recipes         ADD COLUMN IF NOT EXISTS source_reference varchar;
-- DELETE FROM cleangoal.schema_migrations WHERE version = 'v43_drop_dead_columns';
-- COMMIT;
