import pytest
from app.services.carb_service import carb_engine

def test_ifct_database_loaded():
    assert len(carb_engine.food_db) > 10, "IFCT database must have loaded records."
    assert "roti (whole wheat)" in carb_engine.food_db or "chapati" in carb_engine.food_db

def test_food_matching_synonyms():
    # Test English direct
    food_rice = carb_engine.match_food("Steamed Basmati Rice")
    assert food_rice is not None
    assert food_rice["carbs_per_100g"] == 28.2

    # Test Hindi alias
    food_chawal = carb_engine.match_food("chawal")
    assert food_chawal is not None
    assert food_chawal["food_id"] == "IFCT_003"

    # Test shorthand synonym
    food_roti = carb_engine.match_food("roti")
    assert food_roti is not None
    assert "roti" in food_roti["name"].lower()

def test_net_carbs_and_glycemic_load_math():
    # 2 Rotis (~70g total):
    # Roti per 100g: carbs=46.1, fiber=10.2 => net_carbs=35.9g per 100g, GI=62
    # For 70g: net_carbs = 35.9 * 0.7 = 25.13 -> 25.1g
    # Fiber = 10.2 * 0.7 = 7.14 -> 7.1g
    # GL = (25.1 * 62) / 100 = 15.56 -> 15.6
    item = carb_engine.calculate_nutrition("Roti (Whole Wheat)", grams=70.0, confidence=0.95)
    
    assert item.net_carbs == pytest.approx(25.1, abs=0.2)
    assert item.dietary_fiber == pytest.approx(7.1, abs=0.2)
    assert item.glycemic_load == pytest.approx(15.6, abs=0.2)
    assert item.review_flag is False

def test_low_confidence_triggers_review_flag():
    # Confidence 0.60 is below default threshold 0.70
    item = carb_engine.calculate_nutrition("Dal Tadka (Yellow Lentil)", grams=150.0, confidence=0.60)
    assert item.review_flag is True

def test_portion_estimation_with_katori_reference():
    # Dish bbox: area 0.25 (e.g. 0.5 x 0.5)
    # Ref bbox: area 0.25 (katori)
    # Area ratio = 1.0 => standard serving of dal (~150g * 0.9 = ~135g)
    dish_bbox = [0.0, 0.0, 0.5, 0.5]
    ref_bbox = [0.5, 0.5, 1.0, 1.0]
    
    grams, review = carb_engine.estimate_portion_grams(
        food_name="Dal Tadka (Yellow Lentil)",
        bbox=dish_bbox,
        ref_bbox=ref_bbox,
        reference_type="katori"
    )
    assert 100.0 <= grams <= 160.0
    assert review is False

def test_extreme_portion_triggers_review():
    # Extremely large dish relative to katori (3x katori area)
    dish_bbox = [0.0, 0.0, 0.9, 0.9] # area 0.81
    ref_bbox = [0.0, 0.0, 0.3, 0.3]  # area 0.09 -> ratio = 9.0x
    
    grams, review = carb_engine.estimate_portion_grams(
        food_name="Dal Tadka (Yellow Lentil)",
        bbox=dish_bbox,
        ref_bbox=ref_bbox
    )
    assert review is True
