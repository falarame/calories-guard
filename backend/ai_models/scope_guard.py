"""
Cheap pre-LLM filter so we don't burn Ollama cycles on out-of-scope questions
("write me python", "tell me a joke"). Returns True if the message contains
*any* nutrition/health keyword — that's intentionally permissive; the
COACH_SYSTEM_PROMPT does the harder boundary enforcement.
"""
from __future__ import annotations


SCOPE_KEYWORDS: tuple[str, ...] = (
    # อาหาร / โภชนาการ
    "กิน", "ทาน", "อาหาร", "เมนู", "แคลอรี", "โภชนาการ", "สารอาหาร",
    "โปรตีน", "คาร์บ", "ไขมัน", "วิตามิน", "น้ำตาล", "ใยอาหาร", "เกลือ",
    "สูตร", "วิธีทำ", "ส่วนผสม", "recipe",
    # น้ำหนัก / สุขภาพ
    "น้ำหนัก", "ลดน้ำหนัก", "เพิ่มน้ำหนัก", "อ้วน", "ผอม",
    "BMI", "BMR", "TDEE", "สุขภาพ", "โรค", "เบาหวาน", "ความดัน", "คอเลสเตอรอล",
    # กิจกรรม
    "ออกกำลัง", "วิ่ง", "เดิน", "ว่ายน้ำ", "โยคะ", "กีฬา", "เผาผลาญ",
    # อื่น ๆ
    "น้ำ", "ดื่ม", "นอน", "พัก", "เป้าหมาย", "แพ้", "แนะนำ", "ควร",
    "เท่าไหร่", "กี่แคล", "ร้าน", "restaurant",
    # English fallback
    "calories", "protein", "carbs", "fat",
    "diet", "nutrition", "exercise", "health", "weight", "food",
)


REJECT_MSG = (
    "ขออภัยครับ ผมเป็นโค้ชด้านโภชนาการและสุขภาพของ Calories Guard เท่านั้น "
    "ไม่สามารถตอบคำถามที่ไม่เกี่ยวข้องกับอาหาร โภชนาการ สุขภาพ หรือการออกกำลังกายได้ครับ\n\n"
    "ลองถามเรื่องเหล่านี้ได้นะครับ:\n"
    "- วันนี้กินอะไรดี?\n"
    "- ข้าวผัดกะเพรากี่แคล?\n"
    "- แนะนำเมนูลดน้ำหนักหน่อย\n"
    "- ออกกำลังกายอะไรเผาผลาญเยอะ?"
)


def is_in_scope(text: str) -> bool:
    if not text:
        return False
    lowered = text.lower()
    return any(kw.lower() in lowered for kw in SCOPE_KEYWORDS)
