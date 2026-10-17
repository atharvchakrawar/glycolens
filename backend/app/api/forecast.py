import time
from typing import Optional
from fastapi import APIRouter
from app.core.config import settings
from app.models.schemas import GlucoseForecastRequest, GlucoseForecastResponse
from app.services.safety_service import safety_engine
from app.services.forecast_service import forecaster_service

router = APIRouter(prefix="/glucose", tags=["Glucose Forecasting"])

@router.post("/forecast", response_model=GlucoseForecastResponse)
def forecast_glucose(payload: GlucoseForecastRequest):
    """
    Predicts blood glucose at +30 and +60 minutes using the PyTorch Forecaster
    (with biological baseline fallback), computes confidence bands, and attaches
    Rule-of-15 clinical safety alerts if hypoglycemia is anticipated.
    """
    start_time = time.perf_counter()
    readings = payload.recent_readings
    
    if not readings:
        raise ValueError("At least one CGM reading is required for forecasting.")
        
    current = readings[-1].glucose_mg_dl
    velocity = safety_engine.calculate_velocity(readings)

    # Predict via forecaster_service (PyTorch model or baseline)
    (
        pred_30m,
        pred_60m,
        band_low_30m,
        band_high_30m,
        band_low_60m,
        band_high_60m
    ) = forecaster_service.predict(
        readings=readings,
        active_insulin=payload.active_insulin_units,
        confirmed_carbs=payload.confirmed_carbs_grams
    )

    # Check estimated time to low (< 70 mg/dL)
    time_to_low: Optional[int] = None
    if pred_30m < 70.0:
        time_to_low = max(5, int(30 * (current - 70.0) / max(current - pred_30m, 1.0)))
    elif pred_60m < 70.0:
        time_to_low = max(30, int(30 + 30 * (pred_30m - 70.0) / max(pred_30m - pred_60m, 1.0)))

    # Evaluate safety rules
    is_hypo_risk, alert = safety_engine.evaluate_safety(
        current_glucose=current,
        forecast_30m=pred_30m,
        forecast_60m=pred_60m,
        velocity=velocity,
        time_to_low_min=time_to_low
    )
    
    latency_ms = round((time.perf_counter() - start_time) * 1000.0, 2)
    
    return GlucoseForecastResponse(
        current_glucose=current,
        forecast_30m=pred_30m,
        forecast_60m=pred_60m,
        confidence_band_low_30m=band_low_30m,
        confidence_band_high_30m=band_high_30m,
        confidence_band_low_60m=band_low_60m,
        confidence_band_high_60m=band_high_60m,
        hypo_risk=is_hypo_risk,
        time_to_low_min=time_to_low,
        alert=alert,
        latency_ms=latency_ms,
        disclaimer=settings.DISCLAIMER_TEXT
    )

