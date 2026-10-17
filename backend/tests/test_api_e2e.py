from datetime import datetime, timezone, timedelta
import pytest
from fastapi.testclient import TestClient
from app.main import app
from app.core.database import init_db

@pytest.fixture(scope="session", autouse=True)
def setup_database():
    init_db()

@pytest.fixture
def client():
    with TestClient(app) as c:
        yield c

def test_health_check_endpoint(client):
    response = client.get("/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "healthy"
    assert data["ifct_records_loaded"] > 10
    assert "Decision-support only" in data["disclaimer"]

def test_meal_analyze_endpoint(client):
    payload = {
        "reference_object": "katori",
        "meal_type": "lunch"
    }
    response = client.post("/meal/analyze", json=payload)
    assert response.status_code == 200
    data = response.json()
    assert "detected_dishes" in data
    assert len(data["detected_dishes"]) > 0
    assert data["total_net_carbs"] > 0
    assert data["total_fiber"] >= 0
    assert data["latency_ms"] < 2000.0, "Latency SLA < 2000ms violated"
    assert "Decision-support only" in data["disclaimer"]

def test_glucose_forecast_endpoint_hypo_trigger(client):
    now = datetime.now(timezone.utc)
    # Scenario: Rapid drop
    readings = [
        {"timestamp": (now - timedelta(minutes=15)).isoformat(), "glucose_mg_dl": 115.0, "trend_arrow": "SINGLE_DOWN", "rate_of_change": -1.0},
        {"timestamp": (now - timedelta(minutes=10)).isoformat(), "glucose_mg_dl": 95.0, "trend_arrow": "DOUBLE_DOWN", "rate_of_change": -2.0},
        {"timestamp": (now - timedelta(minutes=5)).isoformat(), "glucose_mg_dl": 76.0, "trend_arrow": "DOUBLE_DOWN", "rate_of_change": -3.8}
    ]
    payload = {
        "recent_readings": readings,
        "active_insulin_units": 1.5,
        "confirmed_carbs_grams": 0.0
    }
    response = client.post("/glucose/forecast", json=payload)
    assert response.status_code == 200
    data = response.json()
    assert data["hypo_risk"] is True
    assert data["alert"] is not None
    assert data["alert"]["level"] in ["WARNING", "CRITICAL"]
    assert data["alert"]["rule_of_15_guidance"] is not None
    assert "Decision-support only" in data["disclaimer"]

def test_demo_cgm_scenario_endpoint(client):
    response = client.get("/demo/cgm?scenario=post_meal_low")
    assert response.status_code == 200
    readings = response.json()
    assert len(readings) == 24
    assert readings[0]["glucose_mg_dl"] > 0
    # Last few readings should be in hypoglycemia territory (<70)
    low_values = [r["glucose_mg_dl"] for r in readings if r["glucose_mg_dl"] < 70]
    assert len(low_values) > 0

def test_history_endpoint(client):
    response = client.get("/history")
    assert response.status_code == 200
    history = response.json()
    assert isinstance(history, list)
