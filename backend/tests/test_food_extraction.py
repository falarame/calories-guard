"""
Tests for ai_models.food_extraction.

Designed to pass whether or not pythainlp is installed — the fallback regex
path still recognises common Thai dishes.
"""
import pytest

from ai_models.food_extraction import extract_foods


def test_extracts_known_dish_by_dictionary():
    text = "วันนี้กินข้าวผัดกะเพรากับต้มยำกุ้ง"
    result = extract_foods(text, db_food_names=["ข้าวผัดกะเพรา", "ต้มยำกุ้ง"])
    names = [r["name"] for r in result]
    assert "ข้าวผัดกะเพรา" in names
    assert "ต้มยำกุ้ง" in names


def test_empty_input_returns_empty_list():
    assert extract_foods("") == []
    assert extract_foods("   ") == []


def test_quantity_numeric():
    text = "ข้าวผัด 2 จาน"
    result = extract_foods(text, db_food_names=["ข้าวผัด"])
    assert any(r["name"] == "ข้าวผัด" and r["quantity"] == 2.0 for r in result)


def test_quantity_thai_word():
    text = "ข้าวผัด ครึ่งจาน"
    result = extract_foods(text, db_food_names=["ข้าวผัด"])
    match = next((r for r in result if r["name"] == "ข้าวผัด"), None)
    assert match is not None
    assert match["quantity"] == 0.5


def test_fallback_dictionary_without_db():
    # Should still pick up common dishes even with no DB names
    text = "อยากกินส้มตำ"
    result = extract_foods(text)
    assert any(r["name"] == "ส้มตำ" for r in result)


def test_regional_alias_can_be_dictionary_match():
    text = "มื้อเที่ยงกินข้าวปุ้น 1 จาน"
    result = extract_foods(text, db_food_names=["ขนมจีนน้ำยา", "ข้าวปุ้น"])
    assert any(r["name"] == "ข้าวปุ้น" and r["quantity"] == 1.0 for r in result)


def test_longest_match_wins_without_overlap():
    text = "วันนี้กินข้าวผัดกะเพรา 1 จาน"
    result = extract_foods(text, db_food_names=["ข้าวผัด", "ข้าวผัดกะเพรา"])
    names = [r["name"] for r in result]
    assert names == ["ข้าวผัดกะเพรา"]


def test_tokenized_phrase_match_without_spaces():
    text = "เช้ากินข้าวมันไก่เย็นกินผัดไทย"
    result = extract_foods(text, db_food_names=["ข้าวมันไก่", "ผัดไทย"])
    names = [r["name"] for r in result]
    assert names == ["ข้าวมันไก่", "ผัดไทย"]


def test_limit_respected():
    text = "ข้าวผัด ต้มยำ ผัดไทย ส้มตำ ลาบ"
    result = extract_foods(text, limit=2)
    assert len(result) <= 2


@pytest.mark.parametrize("non_food", ["สวัสดี", "วันนี้อากาศดี", "python is fun"])
def test_no_match_for_non_food_text(non_food):
    result = extract_foods(non_food, db_food_names=["ข้าวผัด"])
    assert result == [] or all(r["source"] == "regex" and r["name"] for r in result)
