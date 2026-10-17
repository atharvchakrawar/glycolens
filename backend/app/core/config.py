from pathlib import Path
from pydantic import BaseModel

class Settings(BaseModel):
    PROJECT_NAME: str = "GlycoLens API"
    VERSION: str = "0.1.0"
    API_V1_STR: str = "/api/v1"
    
    # Base paths
    BASE_DIR: Path = Path(__file__).resolve().parent.parent.parent.parent
    DATA_DIR: Path = BASE_DIR / "data"
    IFCT_CSV_PATH: Path = DATA_DIR / "ifct_curated.csv"
    CALIBRATION_JSON_PATH: Path = DATA_DIR / "reference_calibration.json"
    DATABASE_URL: str = "sqlite:///./glycolens.db"
    
    # Latency budget (ms)
    TARGET_MAX_LATENCY_MS: float = 2000.0
    
    # Clinical Safety Defaults (ISPAD / ADA Guidelines)
    HYPO_THRESHOLD_MG_DL: float = 70.0
    HYPO_ALERT_THRESHOLD_MG_DL: float = 80.0
    RAPID_FALL_VELOCITY_THRESHOLD: float = -2.0  # mg/dL per min
    SEVERE_HYPO_THRESHOLD_MG_DL: float = 54.0
    
    DISCLAIMER_TEXT: str = (
        "Decision-support only. Not a medical device. "
        "Never adjust insulin dosage without consulting your healthcare provider."
    )

settings = Settings()
