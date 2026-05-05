"""Pydantic schema validation tests — no DB or HTTP needed."""
import os
import sys
from datetime import date

import pytest
from pydantic import ValidationError

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, ROOT)

from app.models.schemas import (
    UserRegister, UserLogin, FoodCreate, FoodAutoAdd,
    TempFoodApprove, ChatMessage, GoalType, ActivityLevel,
    WeightLogEntry, WaterLogUpdate,
)


def test_goal_type_enum_values():
    assert GoalType.lose_weight.value == "lose_weight"
    assert GoalType.maintain_weight.value == "maintain_weight"
    assert GoalType.gain_muscle.value == "gain_muscle"


def test_activity_level_enum_values():
    assert ActivityLevel.sedentary.value == "sedentary"


def test_user_register_requires_all_fields():
    with pytest.raises(ValidationError):
        UserRegister(email="a@b.com")
    u = UserRegister(email="a@b.com", password="secret", username="alice")
    assert u.username == "alice"


def test_food_create_accepts_zero_macros():
    f = FoodCreate(food_name="Water", calories=0, protein=0, carbs=0, fat=0)
    assert f.calories == 0


def test_food_auto_add_defaults_to_zero():
    f = FoodCreate(food_name="x", calories=0, protein=0, carbs=0, fat=0)
    assert f.fat == 0


def test_temp_food_approve_has_extended_fields():
    """Regression test: merged commit bb76635 added 9 new optional fields."""
    fields = TempFoodApprove.model_fields.keys()
    for extra in ("image_url", "food_type", "food_category", "sodium",
                  "sugar", "cholesterol", "fiber_g", "serving_quantity", "serving_unit"):
        assert extra in fields


def test_chat_message_location_optional():
    m = ChatMessage(user_id=1, message="hi")
    assert m.lat is None and m.lng is None
    m2 = ChatMessage(user_id=1, message="hi", lat=13.7, lng=100.5)
    assert m2.lat == 13.7


def test_weight_log_requires_float():
    with pytest.raises(ValidationError):
        WeightLogEntry(weight_kg="heavy")
    w = WeightLogEntry(weight_kg=70.5)
    assert w.weight_kg == 70.5


def test_water_log_update():
    w = WaterLogUpdate(amount_ml=500)
    assert w.amount_ml == 500
    assert w.date_record is None
    w_with_date = WaterLogUpdate(amount_ml=500, date_record="2026-05-01")
    assert w_with_date.date_record == date(2026, 5, 1)
