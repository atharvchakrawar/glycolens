from typing import Optional
from fastapi import APIRouter
from app.models.schemas import AlertInfo, CGMReading
from app.services.safety_service import safety_engine

router = APIRouter(prefix="/alerts", tags=["Safety & Alerts"])

@router.post("/evaluate", response_model=Optional[AlertInfo])
def evaluate_alert(
    current_glucose: float,
    forecast_30m: float,
    forecast_60m: float,
    velocity: float = 0.0,
    time_to_low_min: Optional[int] = None
):
    """
    Evaluates hypoglycemia risk and returns clinical safety alert with Rule of 15 instructions.
    """
    _, alert = safety_engine.evaluate_safety(
        current_glucose=current_glucose,
        forecast_30m=forecast_30m,
        forecast_60m=forecast_60m,
        velocity=velocity,
        time_to_low_min=time_to_low_min
    )
    return alert
