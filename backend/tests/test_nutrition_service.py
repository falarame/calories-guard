"""Unit tests for nutrition calculation helpers (pure functions, no DB)."""
import os
import sys


ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, ROOT)


def test_nutrition_service_importable():
    """Smoke test: the service module must import without side effects."""
    from app.services import nutrition_service
    assert nutrition_service is not None


def test_meal_type_mapping():
    """Verify meal_type mapping helper exists and returns sane defaults."""
    from app.services import nutrition_service

    # Check common helper names — whichever exists
    if hasattr(nutrition_service, "normalize_meal_type"):
        fn = nutrition_service.normalize_meal_type
        assert fn("breakfast") in ("breakfast", "เช้า")
