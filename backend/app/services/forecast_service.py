import json
import logging
from pathlib import Path
from typing import List, Optional, Tuple
import numpy as np

from app.core.config import settings
from app.models.schemas import CGMReading, GlucoseForecastResponse
from app.services.safety_service import safety_engine

logger = logging.getLogger("glycolens.forecast_service")

class ForecasterService:
    def __init__(self):
        self.model = None
        self.model_type = "baseline"
        self.config = {}
        self.rmse_30m = 12.5
        self.rmse_60m = 22.0
        self._load_model()

    def _load_model(self):
        """Loads trained PyTorch model and metadata if available."""
        model_path = settings.BASE_DIR / "data" / "models" / "best_glucose_forecaster.pt"
        config_path = settings.BASE_DIR / "data" / "models" / "forecaster_config.json"

        if not model_path.exists() or not config_path.exists():
            logger.info("Trained PyTorch weights not found yet. Using physics-kinetic baseline.")
            self.model_type = "baseline"
            return

        try:
            import torch
            with open(config_path, "r") as f:
                self.config = json.load(f)

            self.model_type = self.config.get("model_type", "lstm")
            self.rmse_30m = self.config.get("metrics", {}).get("rmse_30m", 12.5)
            self.rmse_60m = self.config.get("metrics", {}).get("rmse_60m", 22.0)

            # Lazy load models from ml package
            from ml.training.models import MLPForecaster, LSTMForecaster, TCNForecaster
            if self.model_type == "lstm":
                self.model = LSTMForecaster()
            elif self.model_type == "tcn":
                self.model = TCNForecaster()
            else:
                self.model = MLPForecaster()

            self.model.load_state_dict(torch.load(model_path, map_location=torch.device("cpu")))
            self.model.eval()
            logger.info(f"Loaded trained {self.model_type.upper()} forecaster weights from {model_path}.")
        except Exception as e:
            logger.warning(f"Could not load PyTorch weights ({e}). Falling back to baseline.")
            self.model = None
            self.model_type = "baseline"

    def predict(
        self,
        readings: List[CGMReading],
        active_insulin: float = 0.0,
        confirmed_carbs: float = 0.0
    ) -> Tuple[float, float, float, float, float, float]:
        """
        Predicts glucose at +30m and +60m along with confidence bands.
        Returns: (pred_30, pred_60, band_low_30, band_high_30, band_low_60, band_high_60)
        """
        current = readings[-1].glucose_mg_dl
        velocity = safety_engine.calculate_velocity(readings)

        # PyTorch model inference if loaded
        if self.model is not None:
            try:
                import torch
                # Build (1, 12, 4) tensor
                # If fewer than 12 readings, pad or interpolate
                seq_len = 12
                cgm_vals = [r.glucose_mg_dl for r in readings[-seq_len:]]
                while len(cgm_vals) < seq_len:
                    cgm_vals.insert(0, cgm_vals[0])

                feats = []
                for idx, g in enumerate(cgm_vals):
                    v = (g - cgm_vals[idx - 1]) / 5.0 if idx > 0 else velocity
                    ins = active_insulin if idx == (seq_len - 1) else 0.0
                    carb = confirmed_carbs if idx == (seq_len - 1) else 0.0
                    feats.append([g, ins, carb, v])

                x_tensor = torch.tensor([feats], dtype=torch.float32)
                with torch.no_grad():
                    preds = self.model(x_tensor).cpu().numpy()[0]
                pred_30 = float(np.clip(preds[0], 35.0, 500.0))
                pred_60 = float(np.clip(preds[1], 35.0, 500.0))
            except Exception as ex:
                logger.warning(f"Inference error in PyTorch forecaster ({ex}). Falling back to baseline.")
                pred_30, pred_60 = self._baseline_predict(current, velocity, active_insulin, confirmed_carbs)
        else:
            pred_30, pred_60 = self._baseline_predict(current, velocity, active_insulin, confirmed_carbs)

        # Confidence bounds (+/- 1.96 * RMSE)
        band_low_30 = max(30.0, round(pred_30 - self.rmse_30m, 1))
        band_high_30 = round(pred_30 + self.rmse_30m, 1)
        band_low_60 = max(30.0, round(pred_60 - self.rmse_60m, 1))
        band_high_60 = round(pred_60 + self.rmse_60m, 1)

        return round(pred_30, 1), round(pred_60, 1), band_low_30, band_high_30, band_low_60, band_high_60

    def _baseline_predict(self, current: float, velocity: float, insulin: float, carbs: float) -> Tuple[float, float]:
        pred_30 = current + (velocity * 30.0 * 0.75) + (carbs * 0.3) - (insulin * 8.0)
        pred_60 = current + (velocity * 60.0 * 0.50) + (carbs * 0.7) - (insulin * 15.0)
        return max(35.0, min(500.0, pred_30)), max(35.0, min(500.0, pred_60))

forecaster_service = ForecasterService()
