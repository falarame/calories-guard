from ai_models.food_analyzer import analyze_nutrition_gap, find_frequent_foods


_TARGET = {
    "target_calories": 2000,
    "target_protein": 100,
    "target_carbs": 250,
    "target_fat": 70,
}


def test_no_data_returns_no_data_status():
    result = analyze_nutrition_gap(_TARGET, [])
    assert result["status"] == "no_data"
    assert result["critical_issues"] == []


def test_balanced_within_threshold():
    logs = [{"calories": 2000, "protein": 100, "carbs": 250, "fat": 70}]
    result = analyze_nutrition_gap(_TARGET, logs)
    assert result["status"] == "balanced"
    assert result["critical_issues"] == []


def test_protein_deficit_flagged():
    logs = [{"calories": 1900, "protein": 50, "carbs": 240, "fat": 65}]
    result = analyze_nutrition_gap(_TARGET, logs)
    assert result["status"] == "deficit"
    assert any("โปรตีน" in issue for issue in result["critical_issues"])


def test_calorie_surplus_flagged():
    logs = [{"calories": 2700, "protein": 110, "carbs": 260, "fat": 75}]
    result = analyze_nutrition_gap(_TARGET, logs)
    assert result["status"] == "surplus"
    assert any("พลังงาน" in issue for issue in result["critical_issues"])


def test_mixed_deficit_and_surplus():
    logs = [{"calories": 2700, "protein": 50, "carbs": 260, "fat": 75}]
    result = analyze_nutrition_gap(_TARGET, logs)
    assert result["status"] == "mixed"


def test_find_frequent_foods_orders_by_count():
    rows = [
        {"food_name": "ข้าวผัด"},
        {"food_name": "ส้มตำ"},
        {"food_name": "ข้าวผัด"},
        {"food_name": "ข้าวผัด"},
        {"food_name": "ส้มตำ"},
    ]
    out = find_frequent_foods(rows, top_n=2)
    assert out[0]["food_name"] == "ข้าวผัด"
    assert out[0]["count"] == 3
    assert out[1]["food_name"] == "ส้มตำ"


def test_find_frequent_foods_skips_blank():
    rows = [{"food_name": ""}, {"food_name": None}, {"food_name": "ลาบ"}]
    out = find_frequent_foods(rows)
    assert out == [{"food_name": "ลาบ", "count": 1}]
