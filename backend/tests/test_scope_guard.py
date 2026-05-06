from ai_models.scope_guard import REJECT_MSG, is_in_scope


def test_rejects_off_topic():
    assert not is_in_scope("เขียนโค้ด python ให้หน่อย")
    assert not is_in_scope("what is 1 + 1?")
    assert not is_in_scope("ข่าววันนี้")
    assert not is_in_scope("")


def test_accepts_thai_nutrition_questions():
    assert is_in_scope("ข้าวผัดกะเพรากี่แคล")
    assert is_in_scope("แนะนำเมนูลดน้ำหนัก")
    assert is_in_scope("BMI ของผม")
    assert is_in_scope("วิ่งเผาผลาญเยอะไหม")
    assert is_in_scope("วันนี้กินอะไรดี")


def test_accepts_english_nutrition_questions():
    assert is_in_scope("how many calories in pad thai")
    assert is_in_scope("what's a good diet for me")


def test_reject_message_mentions_scope():
    assert "โภชนาการ" in REJECT_MSG or "อาหาร" in REJECT_MSG
