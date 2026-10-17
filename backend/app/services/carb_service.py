import json
import logging
from pathlib import Path
from typing import Dict, List, Optional, Tuple
import pandas as pd

from app.core.config import settings
from app.models.schemas import DishItem

logger = logging.getLogger("glycolens.carb_service")

class CarbNutritionEngine:
    """
    Indian Food Composition Table (IFCT) nutrition calculation engine
    with reference-object calibration and portion estimation.
    """
    def __init__(self, ifct_csv_path: Optional[Path] = None, calibration_json_path: Optional[Path] = None):
        self.ifct_csv_path = ifct_csv_path or settings.IFCT_CSV_PATH
        self.calibration_json_path = calibration_json_path or settings.CALIBRATION_JSON_PATH
        self.food_db: Dict[str, dict] = {}
        self.calibration_config: dict = {}
        self._load_datasets()

    def _load_datasets(self):
        """Loads IFCT dataset and reference calibration constants into memory."""
        # Load IFCT CSV
        if not self.ifct_csv_path.exists():
            raise FileNotFoundError(f"IFCT database not found at {self.ifct_csv_path}")
        
        df = pd.read_csv(self.ifct_csv_path)
        for _, row in df.iterrows():
            item_data = {
                "food_id": str(row["food_id"]),
                "name": str(row["name"]),
                "hindi_name": str(row.get("hindi_name", "")),
                "category": str(row.get("category", "")),
                "serving_unit": str(row.get("serving_unit", "piece")),
                "standard_serving_grams": float(row.get("standard_serving_grams", 100.0)),
                "carbs_per_100g": float(row["carbs_per_100g"]),
                "dietary_fiber_per_100g": float(row.get("dietary_fiber_per_100g", 0.0)),
                "net_carbs_per_100g": float(row.get("net_carbs_per_100g", row["carbs_per_100g"])),
                "glycemic_index": float(row.get("glycemic_index", 55.0)),
                "glycemic_load_per_serving": float(row.get("glycemic_load_per_serving", 10.0)),
            }
            # Index primary name
            self.food_db[item_data["name"].lower()] = item_data
            # Index hindi name
            if item_data["hindi_name"]:
                self.food_db[item_data["hindi_name"].lower()] = item_data

        logger.info(f"Loaded {len(df)} curated IFCT food records into memory.")

        # Load Calibration JSON
        if self.calibration_json_path.exists():
            with open(self.calibration_json_path, "r", encoding="utf-8") as f:
                self.calibration_config = json.load(f)
            logger.info("Loaded reference calibration configuration.")
        else:
            self.calibration_config = {
                "reference_objects": {
                    "katori": {"reference_volume_ml": 150.0, "standard_dense_curry_grams": 150.0}
                },
                "confidence_thresholds": {"auto_accept_min": 0.70}
            }

    def match_food(self, query_name: str) -> Optional[dict]:
        """Finds closest matching food in the curated IFCT database."""
        clean_q = query_name.strip().lower()
        
        # 1. Direct match
        if clean_q in self.food_db:
            return self.food_db[clean_q]
            
        # 2. Substring match
        for key, food in self.food_db.items():
            if clean_q in key or key in clean_q:
                return food
                
        # 3. Keyword heuristic for common Indian terms
        synonyms = {
            "roti": "roti (whole wheat)",
            "chapati": "roti (whole wheat)",
            "phulka": "roti (whole wheat)",
            "rice": "steamed basmati rice",
            "chawal": "steamed basmati rice",
            "dal": "dal tadka (yellow lentil)",
            "yellow dal": "dal tadka (yellow lentil)",
            "paneer": "paneer butter masala",
            "rajma": "rajma masala (kidney beans)",
            "chole": "chhole (chickpeas masala)",
            "chana": "chhole (chickpeas masala)",
            "dosa": "plain dosa",
            "idli": "idli (steamed rice-urad)",
            "salad": "cucumber tomato salad",
            "curd": "curd / dahi (plain)",
            "dahi": "curd / dahi (plain)",
            "sweet": "gulab jamun",
        }
        
        for syn, target in synonyms.items():
            if syn in clean_q and target in self.food_db:
                return self.food_db[target]
                
        return None

    def estimate_portion_grams(
        self,
        food_name: str,
        bbox: Optional[List[float]] = None,
        ref_bbox: Optional[List[float]] = None,
        reference_type: str = "katori"
    ) -> Tuple[float, bool]:
        """
        Estimates portion in grams using bounding box area ratio against reference object.
        Returns (estimated_grams, requires_review).
        """
        food = self.match_food(food_name)
        default_serving = food["standard_serving_grams"] if food else 100.0

        if not bbox or len(bbox) != 4:
            # No bbox available, fallback to default serving size
            return default_serving, True

        # Calculate bounding box area (normalized or pixel coords)
        dish_w = abs(bbox[2] - bbox[0])
        dish_h = abs(bbox[3] - bbox[1])
        dish_area = dish_w * dish_h

        if ref_bbox and len(ref_bbox) == 4:
            ref_w = abs(ref_bbox[2] - ref_bbox[0])
            ref_h = abs(ref_bbox[3] - ref_bbox[1])
            ref_area = max(ref_w * ref_h, 1e-6)
            
            # Area ratio relative to reference object (e.g., standard 150ml katori)
            area_ratio = dish_area / ref_area
            
            # Density adjustment
            density = self.calibration_config.get("density_factors_g_per_sq_cm", {}).get("default", 1.0)
            clean_name = food_name.lower()
            if "rice" in clean_name:
                base_grams = 120.0
            elif "dal" in clean_name or "curry" in clean_name:
                base_grams = 150.0
            elif "roti" in clean_name or "chapati" in clean_name:
                # Rotis are flat discs: area ratio vs katori translates to piece count
                pieces = max(1.0, round(area_ratio / 1.8))
                return round(pieces * 35.0, 1), False
            else:
                base_grams = default_serving
                
            estimated_grams = round(area_ratio * base_grams * 0.9, 1)
            # Bound within plausible single-dish range [15g, 600g]
            estimated_grams = max(15.0, min(estimated_grams, 600.0))
            
            # Flag if ratio is extreme (>2.2x or <0.35x standard serving)
            ratio_vs_standard = estimated_grams / default_serving
            requires_review = ratio_vs_standard > 2.2 or ratio_vs_standard < 0.35
            return estimated_grams, requires_review

        # Bbox given without reference object
        return default_serving, True

    def calculate_nutrition(
        self,
        food_name: str,
        grams: float,
        confidence: float = 1.0,
        bbox: Optional[List[float]] = None
    ) -> DishItem:
        """Computes carbs, fiber, glycemic load, and review flag for a given dish & portion."""
        food = self.match_food(food_name)
        
        if not food:
            # Fallback for unrecognized dish
            logger.warning(f"Unrecognized food item: '{food_name}'. Using generic Indian curry baseline.")
            food = {
                "name": food_name.title(),
                "hindi_name": None,
                "category": "Generic",
                "carbs_per_100g": 15.0,
                "dietary_fiber_per_100g": 2.0,
                "net_carbs_per_100g": 13.0,
                "glycemic_index": 55.0,
                "standard_serving_grams": 100.0
            }
            review_flag = True
        else:
            min_conf = self.calibration_config.get("confidence_thresholds", {}).get("auto_accept_min", 0.70)
            review_flag = confidence < min_conf

        ratio = grams / 100.0
        carbs_100g = food["carbs_per_100g"]
        fiber_100g = food["dietary_fiber_per_100g"]
        gi = food["glycemic_index"]

        net_carbs_100g = max(0.0, carbs_100g - fiber_100g)
        portion_net_carbs = round(net_carbs_100g * ratio, 1)
        portion_fiber = round(fiber_100g * ratio, 1)
        portion_gl = round((portion_net_carbs * gi) / 100.0, 1)

        return DishItem(
            name=food["name"],
            hindi_name=food.get("hindi_name"),
            category=food.get("category"),
            confidence=round(confidence, 2),
            bbox=bbox or [],
            estimated_grams=round(grams, 1),
            carbs_per_100g=carbs_100g,
            net_carbs=portion_net_carbs,
            dietary_fiber=portion_fiber,
            glycemic_index=gi,
            glycemic_load=portion_gl,
            review_flag=review_flag
        )

# Global singleton instance
carb_engine = CarbNutritionEngine()
