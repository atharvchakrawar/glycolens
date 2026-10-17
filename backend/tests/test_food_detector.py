import io
import base64
import pytest
from PIL import Image
from fastapi.testclient import TestClient
from app.main import app
from app.services.detector_service import detector_engine

@pytest.fixture
def client():
    with TestClient(app) as c:
        yield c

def test_image_decoding_and_analysis():
    # Create simple 100x100 test image in memory
    img = Image.new("RGB", (100, 100), color=(200, 200, 200))
    buf = io.BytesIO()
    img.save(buf, format="JPEG")
    img_bytes = buf.getvalue()
    b64_str = base64.b64encode(img_bytes).decode("utf-8")

    response = detector_engine.analyze(image_base64=b64_str, preferred_ref="katori")
    assert len(response.detected_dishes) > 0
    assert response.total_net_carbs > 0
    assert response.latency_ms < 2000.0, "Latency SLA violated (<2000ms)"
    assert "Decision-support only" in response.disclaimer

def test_upload_meal_photo_endpoint(client):
    img = Image.new("RGB", (200, 200), color=(180, 150, 120))
    buf = io.BytesIO()
    img.save(buf, format="JPEG")
    buf.seek(0)

    files = {"file": ("test_plate.jpg", buf, "image/jpeg")}
    data = {"reference_object": "katori"}

    res = client.post("/meal/upload", files=files, data=data)
    assert res.status_code == 200
    res_data = res.json()
    assert "detected_dishes" in res_data
    assert res_data["total_net_carbs"] > 0
    assert res_data["latency_ms"] < 2000.0

def test_one_tap_portion_editing(client):
    # First create a meal
    create_res = client.post("/meal/analyze", json={"reference_object": "katori"})
    assert create_res.status_code == 200
    meal_id = create_res.json()["meal_id"]

    # Now simulate user tapping to update portions: e.g. change Roti to 105g (3 rotis)
    update_payload = {
        "dish_updates": [
            {"name": "Roti (Whole Wheat)", "updated_grams": 105.0},
            {"name": "Dal Tadka (Yellow Lentil)", "updated_grams": 150.0}
        ]
    }
    update_res = client.put(f"/meal/{meal_id}/portions", json=update_payload)
    assert update_res.status_code == 200
    updated_data = update_res.json()
    
    # 105g roti: 35.9 net carbs per 100g * 1.05 = ~37.7g
    # 150g dal: 7.4 net carbs per 100g * 1.5 = 11.1g
    # Total carbs = ~48.8g
    assert updated_data["total_net_carbs"] == pytest.approx(48.8, abs=1.0)
    assert updated_data["review_recommended"] is False
