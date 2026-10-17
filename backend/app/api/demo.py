from datetime import datetime, timezone, timedelta
from typing import List
from fastapi import APIRouter, Query, HTTPException
from app.models.schemas import CGMReading

router = APIRouter(prefix="/demo", tags=["Demo Simulation Replay"])

@router.get("/cgm", response_model=List[CGMReading])
def get_demo_cgm_stream(
    scenario: str = Query("post_meal_low", description="Scenario: 'post_meal_low', 'post_meal_stable', 'overnight_low'")
):
    """
    Returns realistic 2-hour scripted CGM streams (sampled every 5 minutes = 24 points).
    Enables instant reproducible on-camera demonstration without waiting for real CGM hardware.
    """
    now = datetime.now(timezone.utc)

    readings: List[CGMReading] = []
    
    # 24 steps = 120 minutes (5 min intervals)
    # Timestamps from (now - 115m) up to (now)
    if scenario == "post_meal_low":
        # Meal eaten 90m ago (carbs overestimated or bolus too high):
        # Glucose peaked at 165 mg/dL, now plummeting through 82, 74, 65 mg/dL
        values = [
            110, 125, 142, 158, 165, 162, 155, 144, 130, 118,
            108, 98, 90, 84, 78, 72, 67, 63, 60, 58, 59, 63, 68, 72
        ]
        arrows = [
            "SINGLE_UP"] * 4 + ["FLAT"] * 3 + ["SINGLE_DOWN"] * 5 + ["DOUBLE_DOWN"] * 6 + ["SINGLE_DOWN"] * 2 + ["SINGLE_UP"] * 4
            
    elif scenario == "post_meal_stable":
        # Well matched meal bolus: rises gently from 105 to 138, then recovers to 112
        values = [
            105, 108, 114, 122, 130, 136, 138, 135, 131, 128,
            124, 120, 118, 116, 115, 114, 113, 112, 112, 111, 112, 111, 112, 113
        ]
        arrows = ["FLAT"] * 3 + ["SINGLE_UP"] * 4 + ["FLAT"] * 17
        
    elif scenario == "overnight_low":
        # Basal mismatch / post-exercise nighttime drop: starts at 115, gradually drifts into 65
        values = [
            120, 118, 115, 112, 108, 104, 100, 96, 92, 88,
            85, 82, 79, 76, 73, 70, 68, 66, 64, 63, 62, 63, 64, 65
        ]
        arrows = ["FLAT"] * 6 + ["SINGLE_DOWN"] * 18
    else:
        raise HTTPException(
            status_code=400,
            detail=f"Unknown scenario '{scenario}'. Allowed: 'post_meal_low', 'post_meal_stable', 'overnight_low'"
        )

    for i in range(24):
        t = now - timedelta(minutes=(23 - i) * 5)
        # Compute velocity vs previous reading
        vel = round((values[i] - values[i-1]) / 5.0, 2) if i > 0 else 0.0
        readings.append(
            CGMReading(
                timestamp=t,
                glucose_mg_dl=float(values[i]),
                trend_arrow=arrows[i],
                rate_of_change=vel
            )
        )
        
    return readings
