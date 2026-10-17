from datetime import datetime
from typing import List, Optional
from pydantic import BaseModel, Field

class DishItem(BaseModel):
    name: str = Field(..., description="Food item name (e.g. Chapati, Dal Tadka)")
    hindi_name: Optional[str] = Field(None, description="Common Indian name")
    category: Optional[str] = Field(None, description="Category (Breads, Lentils, Curries)")
    confidence: float = Field(..., ge=0.0, le=1.0, description="Detection confidence score")
    bbox: List[float] = Field(default_factory=list, description="Bounding box [x1, y1, x2, y2]")
    estimated_grams: float = Field(..., ge=0.0, description="Estimated portion in grams")
    carbs_per_100g: float = Field(..., ge=0.0, description="Carbohydrates per 100g from IFCT")
    net_carbs: float = Field(..., ge=0.0, description="Net carbohydrates for this portion in grams")
    dietary_fiber: float = Field(..., ge=0.0, description="Dietary fiber for this portion in grams")
    glycemic_index: float = Field(..., ge=0.0, description="Glycemic Index (GI)")
    glycemic_load: float = Field(..., ge=0.0, description="Glycemic Load (GL) for this portion")
    review_flag: bool = Field(default=False, description="True if low confidence or extreme portion ratio")

class MealAnalysisRequest(BaseModel):
    image_base64: Optional[str] = Field(None, description="Base64 encoded meal photo")
    image_url: Optional[str] = Field(None, description="URL to meal photo")
    reference_object: str = Field(default="katori", description="Calibration reference: 'katori' or 'thali_plate'")
    meal_type: Optional[str] = Field(default="lunch", description="breakfast, lunch, snack, dinner")

class ManualMealLogRequest(BaseModel):
    dishes: List[DishItem]
    meal_type: Optional[str] = Field(default="lunch", description="breakfast, lunch, snack, dinner")

class MealAnalysisResponse(BaseModel):
    meal_id: Optional[int] = None
    timestamp: datetime = Field(default_factory=datetime.utcnow)
    detected_dishes: List[DishItem]
    total_net_carbs: float = Field(..., description="Sum of net carbohydrates in grams")
    total_fiber: float = Field(..., description="Sum of dietary fiber in grams")
    meal_glycemic_load: float = Field(..., description="Aggregate meal glycemic load")
    review_recommended: bool = Field(..., description="Flag if any dish needs manual portion check")
    latency_ms: float = Field(..., description="Total pipeline latency in milliseconds")
    disclaimer: str = Field(..., description="Non-medical decision support disclaimer")

class MealPortionUpdate(BaseModel):
    name: str
    updated_grams: float = Field(..., gt=0.0)

class MealUpdateRequest(BaseModel):
    dish_updates: List[MealPortionUpdate]

class CGMReading(BaseModel):
    timestamp: datetime = Field(default_factory=datetime.utcnow)
    glucose_mg_dl: float = Field(..., ge=20.0, le=600.0, description="Blood glucose reading in mg/dL")
    trend_arrow: Optional[str] = Field(default="FLAT", description="FLAT, SINGLE_UP, DOUBLE_UP, SINGLE_DOWN, DOUBLE_DOWN")
    rate_of_change: Optional[float] = Field(default=0.0, description="Velocity in mg/dL per min")

class RuleOf15Guidance(BaseModel):
    title: str = "Rule of 15 Protocol"
    step_1: str = "Consume 15 grams of fast-acting carbohydrate immediately (e.g., 1/2 cup fruit juice, 3-4 glucose tablets, or 3 tsp sugar dissolved in water)."
    step_2: str = "Wait 15 minutes without eating additional food."
    step_3: str = "Re-check blood glucose."
    step_4: str = "If still under 70 mg/dL, repeat with another 15g of fast-acting carbs. If >= 70 mg/dL, have a small snack with complex carbs & protein."
    timer_seconds: int = 900  # 15 minutes

class AlertInfo(BaseModel):
    level: str = Field(..., description="'NONE', 'WATCH', 'WARNING', 'CRITICAL'")
    title: str
    message: str
    glucose_reading: float
    time_to_low_min: Optional[int] = None
    rule_of_15_guidance: Optional[RuleOf15Guidance] = None
    timestamp: datetime = Field(default_factory=datetime.utcnow)
    disclaimer: str

class GlucoseForecastRequest(BaseModel):
    recent_readings: List[CGMReading] = Field(..., min_length=1, description="Chronological CGM readings")
    active_insulin_units: float = Field(default=0.0, ge=0.0, description="Estimated Insulin on Board (IOB)")
    confirmed_carbs_grams: float = Field(default=0.0, ge=0.0, description="Confirmed meal carbs in grams")

class GlucoseForecastResponse(BaseModel):
    current_glucose: float
    forecast_30m: float
    forecast_60m: float
    confidence_band_low_30m: float
    confidence_band_high_30m: float
    confidence_band_low_60m: float
    confidence_band_high_60m: float
    hypo_risk: bool
    time_to_low_min: Optional[int] = None
    alert: Optional[AlertInfo] = None
    latency_ms: float = 0.0
    disclaimer: str

class HistoryResponse(BaseModel):
    meals: List[MealAnalysisResponse]
    recent_readings: List[CGMReading]
