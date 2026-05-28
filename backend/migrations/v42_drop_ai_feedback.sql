-- v42: ลบตาราง ai_feedback (ฟีเจอร์ AI thumbs up/down ที่เลิกใช้แล้ว)
--
-- บริบท
-- -----
-- แอปไม่ใช้ AI ช่วยแล้ว ฟีเจอร์โหวต 👍/👎 ต่อคำตอบ AI (endpoint /api/feedback) จึงเป็นซากที่ตายแล้ว
-- ตรวจสอบก่อนลบ:
--   * ตาราง ai_feedback มี 0 แถว
--   * แอป Flutter ไม่เรียก /api/feedback เลย
--   * ไม่มี test / ไฟล์ n8n / โค้ด backend อื่นอ้างถึง
-- ลบควบคู่กันในโค้ด backend แล้ว:
--   * ลบ router app/routers/feedback.py และการ register ใน main.py
--   * ลบบล็อก CREATE TABLE IF NOT EXISTS ai_feedback ใน main.py (สำคัญ มิฉะนั้นจะถูกสร้างใหม่ตอน startup)
--
-- หมายเหตุ: v41 เพิ่งเปิด RLS ให้ ai_feedback ไป แต่ v42 นี้ลบทั้งตารางจึงไม่ต้องสนใจ RLS อีก

BEGIN;

DROP TABLE IF EXISTS cleangoal.ai_feedback;

INSERT INTO cleangoal.schema_migrations(version) VALUES ('v42_drop_ai_feedback')
    ON CONFLICT (version) DO NOTHING;

COMMIT;

-- ROLLBACK (ถ้าจำเป็นต้องนำฟีเจอร์ AI กลับมา ต้องสร้างตารางใหม่และคืน router/CREATE TABLE):
-- BEGIN;
-- CREATE TABLE IF NOT EXISTS cleangoal.ai_feedback (
--     id               BIGSERIAL PRIMARY KEY,
--     user_id          BIGINT REFERENCES cleangoal.users(user_id) ON DELETE SET NULL,
--     query            TEXT NOT NULL,
--     response         TEXT NOT NULL,
--     rating           VARCHAR(4) NOT NULL CHECK (rating IN ('up', 'down')),
--     context_type     VARCHAR(20) DEFAULT 'chat',
--     used_in_training BOOLEAN DEFAULT FALSE,
--     created_at       TIMESTAMP DEFAULT NOW()
-- );
-- DELETE FROM cleangoal.schema_migrations WHERE version = 'v42_drop_ai_feedback';
-- COMMIT;
