import logging
from datetime import datetime, timezone
from typing import List, Optional, Tuple
from app.core.config import settings
from app.models.schemas import AlertInfo, CGMReading, RuleOf15Guidance

logger = logging.getLogger("glycolens.safety_service")

class SafetyRuleEngine:
    """
    Clinical decision-support safety engine for hypoglycemia early-warning.
    Evaluates:
      1. Projected forecast < 70 mg/dL within 60 min
      2. Current reading < 80 mg/dL and falling > 2.0 mg/dL/min
      3. Critical threshold < 54 mg/dL
    Generates structured Rule-of-15 guidance and safe cautious recommendations.
    """

    @staticmethod
    def calculate_velocity(readings: List[CGMReading]) -> float:
        """
        Computes rate of change (velocity in mg/dL per min) from recent readings.
        Uses the last 2-3 readings if available.
        """
        if len(readings) < 2:
            return 0.0

        r1 = readings[-2]
        r2 = readings[-1]

        # Calculate delta time in minutes
        delta_seconds = (r2.timestamp - r1.timestamp).total_seconds()
        delta_minutes = delta_seconds / 60.0 if delta_seconds > 0 else 5.0

        delta_glucose = r2.glucose_mg_dl - r1.glucose_mg_dl
        velocity = delta_glucose / delta_minutes
        return round(velocity, 2)

    def evaluate_safety(
        self,
        current_glucose: float,
        forecast_30m: float,
        forecast_60m: float,
        velocity: float = 0.0,
        time_to_low_min: Optional[int] = None
    ) -> Tuple[bool, Optional[AlertInfo]]:
        """
        Evaluates clinical hazard criteria and returns (is_hypo_risk, alert_info).
        """
        rule_of_15 = RuleOf15Guidance()
        
        # 1. CRITICAL: Current glucose < 54 mg/dL (Severe Hypoglycemia)
        if current_glucose < settings.SEVERE_HYPO_THRESHOLD_MG_DL:
            alert = AlertInfo(
                level="CRITICAL",
                title="Critical Low Glucose Alert",
                message=(
                    f"Current glucose is critically low ({current_glucose:.0f} mg/dL). "
                    "Immediately consume 15g fast-acting carbs. If unresponsive, seek emergency medical assistance."
                ),
                glucose_reading=current_glucose,
                time_to_low_min=0,
                rule_of_15_guidance=rule_of_15,
                timestamp=datetime.now(timezone.utc),
                disclaimer=settings.DISCLAIMER_TEXT
            )
            return True, alert

        # 2. WARNING: Current < 80 mg/dL and falling rapidly (> 2 mg/dL/min)
        if current_glucose < settings.HYPO_ALERT_THRESHOLD_MG_DL and velocity <= settings.RAPID_FALL_VELOCITY_THRESHOLD:
            est_time = max(5, int((current_glucose - 70.0) / abs(velocity))) if velocity < 0 else 10
            alert = AlertInfo(
                level="WARNING",
                title="Rapid Drop Hypoglycemia Warning",
                message=(
                    f"Glucose is {current_glucose:.0f} mg/dL and dropping rapidly. "
                    f"Hypoglycemia (<70 mg/dL) anticipated in ~{est_time} minutes. "
                    "Eat a fruit (banana/apple) or 15g fast carbs (juice/glucose) now to control and stabilize!"
                ),
                glucose_reading=current_glucose,
                time_to_low_min=est_time,
                rule_of_15_guidance=rule_of_15,
                timestamp=datetime.now(timezone.utc),
                disclaimer=settings.DISCLAIMER_TEXT
            )
            return True, alert

        # 3. WARNING: Forecast crosses below 70 mg/dL within 30-60 min
        min_forecast = min(forecast_30m, forecast_60m)
        if min_forecast < settings.HYPO_THRESHOLD_MG_DL:
            ttl = time_to_low_min or (30 if forecast_30m < 70.0 else 60)
            alert = AlertInfo(
                level="WARNING",
                title="Early Hypoglycemia Warning",
                message=(
                    f"Glucose will reach {min_forecast:.0f} mg/dL (hypo) in ~{ttl} minutes. "
                    "Eat a fruit (banana/apple) or 15g fast carbs (juice/sugar) now to control and prevent a crash!"
                ),
                glucose_reading=current_glucose,
                time_to_low_min=ttl,
                rule_of_15_guidance=rule_of_15,
                timestamp=datetime.now(timezone.utc),
                disclaimer=settings.DISCLAIMER_TEXT
            )
            return True, alert

        # 4. WATCH: Current glucose in borderline buffer zone (70 - 80 mg/dL)
        if current_glucose < settings.HYPO_ALERT_THRESHOLD_MG_DL:
            alert = AlertInfo(
                level="WATCH",
                title="Low-Normal Glucose Watch",
                message=(
                    f"Glucose is {current_glucose:.0f} mg/dL. Monitor trend closely before exercise or sleeping."
                ),
                glucose_reading=current_glucose,
                time_to_low_min=None,
                rule_of_15_guidance=None,
                timestamp=datetime.now(timezone.utc),
                disclaimer=settings.DISCLAIMER_TEXT
            )
            return False, alert

        # 5. NORMAL / STABLE
        return False, None

safety_engine = SafetyRuleEngine()
