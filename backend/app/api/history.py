import json
from typing import List
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.database import get_db
from app.models.db_models import MealRecord, GlucoseLog
from app.models.schemas import MealAnalysisResponse, DishItem, CGMReading

router = APIRouter(prefix="/history", tags=["History & Logs"])

@router.get("", response_model=List[MealAnalysisResponse])
def get_meal_history(
    limit: int = 10,
    db: Session = Depends(get_db)
):
    """
    Returns recorded historical meals with calculated carbs, fiber, and review flags.
    """
    records = db.query(MealRecord).order_by(MealRecord.timestamp.desc()).limit(limit).all()
    results = []
    
    for r in records:
        raw_dishes = json.loads(r.dishes_json) if r.dishes_json else []
        dishes = [DishItem(**d) for d in raw_dishes]
        ts = r.timestamp
        if ts and ts.tzinfo is None:
            from datetime import timezone
            ts = ts.replace(tzinfo=timezone.utc)
        results.append(
            MealAnalysisResponse(
                meal_id=r.id,
                timestamp=ts,
                detected_dishes=dishes,
                total_net_carbs=r.total_net_carbs,
                total_fiber=r.total_fiber,
                meal_glycemic_load=r.glycemic_load,
                review_recommended=r.review_flag,
                latency_ms=0.0,
                disclaimer=settings.DISCLAIMER_TEXT
            )
        )
    return results
