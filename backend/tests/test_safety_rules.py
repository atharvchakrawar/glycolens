from datetime import datetime, timezone, timedelta
import pytest
from app.models.schemas import CGMReading
from app.services.safety_service import safety_engine

def test_velocity_calculation():
    now = datetime.now(timezone.utc)

    # Reading 5 minutes ago: 120, now: 105 -> drop of 15 mg/dL in 5m = -3.0 mg/dL/min
    readings = [
        CGMReading(timestamp=now - timedelta(minutes=5), glucose_mg_dl=120.0),
        CGMReading(timestamp=now, glucose_mg_dl=105.0)
    ]
    vel = safety_engine.calculate_velocity(readings)
    assert vel == pytest.approx(-3.0, abs=0.1)

def test_critical_severe_hypo_below_54():
    is_hypo, alert = safety_engine.evaluate_safety(
        current_glucose=52.0,
        forecast_30m=50.0,
        forecast_60m=48.0,
        velocity=-0.5
    )
    assert is_hypo is True
    assert alert is not None
    assert alert.level == "CRITICAL"
    assert "critically low" in alert.message.lower()
    assert alert.rule_of_15_guidance is not None
    assert "Decision-support only" in alert.disclaimer

def test_rapid_fall_warning_below_80_and_falling_fast():
    # Current is 78 (< 80) and dropping at -2.5 mg/dL/min (<= -2.0)
    is_hypo, alert = safety_engine.evaluate_safety(
        current_glucose=78.0,
        forecast_30m=65.0,
        forecast_60m=60.0,
        velocity=-2.5
    )
    assert is_hypo is True
    assert alert is not None
    assert alert.level == "WARNING"
    assert "dropping rapidly" in alert.message.lower()
    assert alert.time_to_low_min is not None

def test_forecast_predicts_hypo_within_60m():
    # Current is 100 (safe right now), but forecast drops to 64 at 60m
    is_hypo, alert = safety_engine.evaluate_safety(
        current_glucose=100.0,
        forecast_30m=82.0,
        forecast_60m=64.0,
        velocity=-0.6
    )
    assert is_hypo is True
    assert alert is not None
    assert alert.level == "WARNING"
    assert "predicted glucose will reach 64" in alert.message.lower()

def test_stable_glucose_no_alert():
    # Stable at 115 mg/dL, forecast 120 and 118
    is_hypo, alert = safety_engine.evaluate_safety(
        current_glucose=115.0,
        forecast_30m=120.0,
        forecast_60m=118.0,
        velocity=0.1
    )
    assert is_hypo is False
    assert alert is None
