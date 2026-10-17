import json
import logging
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.database import get_db
from app.models.db_models import MealRecord
from app.models.schemas import (
    MealAnalysisRequest,
    MealAnalysisResponse,
    MealUpdateRequest,
    DishItem,
    ManualMealLogRequest,
)
from app.services.detector_service import detector_engine
from app.services.carb_service import carb_engine

logger = logging.getLogger("glycolens.api.meal")

router = APIRouter(prefix="/meal", tags=["Meal Analysis"])

@router.get("/foods")
def get_ifct_foods():
    """
    Returns curated ICMR IFCT Indian food items with standard household serving units
    (rotis, katoris, pieces) and nutrient profiles.
    """
    seen_ids = set()
    foods = []
    for item in carb_engine.food_db.values():
        if item["food_id"] not in seen_ids:
            seen_ids.add(item["food_id"])
            foods.append(item)
    foods.sort(key=lambda x: (x.get("category", ""), x.get("name", "")))
    return foods

@router.post("/log", response_model=MealAnalysisResponse)
def log_manual_meal(
    payload: ManualMealLogRequest,
    db: Session = Depends(get_db)
):
    """
    Logs a manually assembled Indian meal directly into SQLite history.
    """
    total_carbs = round(sum(d.net_carbs for d in payload.dishes), 1)
    total_fiber = round(sum(d.dietary_fiber for d in payload.dishes), 1)
    total_gl = round(sum(d.glycemic_load for d in payload.dishes), 1)

    meal_record = MealRecord(
        image_name="manual_log.jpg",
        total_net_carbs=total_carbs,
        total_fiber=total_fiber,
        glycemic_load=total_gl,
        review_flag=False,
        dishes_json=json.dumps([d.model_dump() for d in payload.dishes])
    )
    db.add(meal_record)
    db.commit()
    db.refresh(meal_record)

    ts = meal_record.timestamp
    if ts and ts.tzinfo is None:
        from datetime import timezone
        ts = ts.replace(tzinfo=timezone.utc)

    return MealAnalysisResponse(
        meal_id=meal_record.id,
        timestamp=ts,
        detected_dishes=payload.dishes,
        total_net_carbs=total_carbs,
        total_fiber=total_fiber,
        meal_glycemic_load=total_gl,
        review_recommended=False,
        latency_ms=1.0,
        disclaimer=settings.DISCLAIMER_TEXT
    )

@router.post("/analyze", response_model=MealAnalysisResponse)
def analyze_meal(
    payload: MealAnalysisRequest,
    db: Session = Depends(get_db)
):
    """
    Analyzes Indian meal image via Base64 or URL, detects food items and reference tableware (katori/plate),
    calibrates portion size, and computes net carbs, dietary fiber, and glycemic load from IFCT.
    """
    response = detector_engine.analyze(
        image_base64=payload.image_base64,
        preferred_ref=payload.reference_object
    )

    # Persist record to SQLite
    meal_record = MealRecord(
        image_name="meal_capture.jpg",
        total_net_carbs=response.total_net_carbs,
        total_fiber=response.total_fiber,
        glycemic_load=response.meal_glycemic_load,
        review_flag=response.review_recommended,
        dishes_json=json.dumps([d.model_dump() for d in response.detected_dishes])
    )
    db.add(meal_record)
    db.commit()
    db.refresh(meal_record)

    response.meal_id = meal_record.id
    return response

@router.post("/upload", response_model=MealAnalysisResponse)
async def upload_meal_photo(
    file: UploadFile = File(...),
    reference_object: str = Form("katori"),
    db: Session = Depends(get_db)
):
    """
    Accepts direct image file upload (multipart/form-data) from mobile camera or gallery.
    """
    image_bytes = await file.read()
    response = detector_engine.analyze(
        image_bytes=image_bytes,
        preferred_ref=reference_object
    )

    meal_record = MealRecord(
        image_name=file.filename or "upload.jpg",
        total_net_carbs=response.total_net_carbs,
        total_fiber=response.total_fiber,
        glycemic_load=response.meal_glycemic_load,
        review_flag=response.review_recommended,
        dishes_json=json.dumps([d.model_dump() for d in response.detected_dishes])
    )
    db.add(meal_record)
    db.commit()
    db.refresh(meal_record)

    response.meal_id = meal_record.id
    return response

@router.put("/{meal_id}/portions", response_model=MealAnalysisResponse)
def update_meal_portions(
    meal_id: int,
    payload: MealUpdateRequest,
    db: Session = Depends(get_db)
):
    """
    Allows user to edit estimated portion grams with 1 tap on the mobile screen.
    Recalculates carbs, fiber, and glycemic load instantly.
    """
    record = db.query(MealRecord).filter(MealRecord.id == meal_id).first()
    if not record:
        raise HTTPException(status_code=404, detail=f"Meal with ID {meal_id} not found.")

    updated_dishes: List[DishItem] = []
    for update in payload.dish_updates:
        item = carb_engine.calculate_nutrition(
            food_name=update.name,
            grams=update.updated_grams,
            confidence=1.0  # User manually confirmed
        )
        item.review_flag = False
        updated_dishes.append(item)

    total_carbs = round(sum(d.net_carbs for d in updated_dishes), 1)
    total_fiber = round(sum(d.dietary_fiber for d in updated_dishes), 1)
    total_gl = round(sum(d.glycemic_load for d in updated_dishes), 1)

    record.total_net_carbs = total_carbs
    record.total_fiber = total_fiber
    record.glycemic_load = total_gl
    record.review_flag = False
    record.dishes_json = json.dumps([d.model_dump() for d in updated_dishes])
    db.commit()

    return MealAnalysisResponse(
        meal_id=record.id,
        timestamp=record.timestamp,
        detected_dishes=updated_dishes,
        total_net_carbs=total_carbs,
        total_fiber=total_fiber,
        meal_glycemic_load=total_gl,
        review_recommended=False,
        latency_ms=1.0,
        disclaimer=settings.DISCLAIMER_TEXT
    )
