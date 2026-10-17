from datetime import datetime, timezone
from sqlalchemy import Column, Integer, Float, String, DateTime, Boolean, Text
from app.core.database import Base

def utc_now():
    return datetime.now(timezone.utc)


class MealRecord(Base):
    __tablename__ = "meals"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    timestamp = Column(DateTime, default=utc_now, index=True)
    image_name = Column(String(255), nullable=True)
    total_net_carbs = Column(Float, nullable=False, default=0.0)
    total_fiber = Column(Float, nullable=False, default=0.0)
    glycemic_load = Column(Float, nullable=False, default=0.0)
    review_flag = Column(Boolean, default=False)
    dishes_json = Column(Text, nullable=True)  # JSON-encoded array of dishes
    notes = Column(String(500), nullable=True)

class GlucoseLog(Base):
    __tablename__ = "glucose_logs"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    timestamp = Column(DateTime, default=utc_now, index=True)
    glucose_mg_dl = Column(Float, nullable=False)
    trend_arrow = Column(String(10), default="FLAT")  # DOUBLE_UP, SINGLE_UP, FLAT, SINGLE_DOWN, DOUBLE_DOWN
    rate_of_change = Column(Float, default=0.0)       # mg/dL per min
    source = Column(String(50), default="cgm")        # "cgm", "simulated", "manual"

class AlertEvent(Base):
    __tablename__ = "alert_events"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    timestamp = Column(DateTime, default=utc_now, index=True)
    alert_level = Column(String(20), nullable=False)   # "WATCH", "WARNING", "CRITICAL"
    trigger_reason = Column(String(255), nullable=False)
    glucose_reading = Column(Float, nullable=False)
    rule_of_15_shown = Column(Boolean, default=True)
