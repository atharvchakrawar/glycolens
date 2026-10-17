import logging
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from app.core.config import settings
from app.core.database import Base, engine
from app.core.logger import LatencyLoggingMiddleware, logger
from app.services.carb_service import carb_engine
from app.api.meal import router as meal_router
from app.api.forecast import router as forecast_router
from app.api.demo import router as demo_router
from app.api.history import router as history_router
from app.api.alerts import router as alerts_router

@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    Startup & shutdown lifecycles:
    Initializes SQLite tables and loads IFCT/calibration data once into memory.
    """
    logger.info("Initializing GlycoLens backend database tables...")
    Base.metadata.create_all(bind=engine)
    logger.info("Verifying IFCT food composition database...")
    if not carb_engine.food_db:
        carb_engine._load_datasets()
    logger.info("Pre-loading and warming up YOLOv8 food detector & PyTorch forecaster...")
    from app.services.detector_service import detector_engine
    from app.services.forecast_service import forecaster_service
    # Warm up detector once so request latency is <50ms
    _ = detector_engine.analyze()
    logger.info("GlycoLens backend initialized successfully and ready for inference.")
    yield
    logger.info("Shutting down GlycoLens backend.")


app = FastAPI(
    title=settings.PROJECT_NAME,
    version=settings.VERSION,
    description=(
        "GlycoLens: AI-powered hypoglycemia early-warning & Indian meal carb estimator. "
        "Decision-support only. Not a medical device."
    ),
    lifespan=lifespan
)

# CORS configuration
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Allow all for hackathon mobile dev / emulator testing
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Latency Measurement Middleware
app.add_middleware(LatencyLoggingMiddleware)

# Prevent stale caching on mobile browsers & PWAs
@app.middleware("http")
async def add_no_cache_headers(request, call_next):
    response = await call_next(request)
    response.headers["Cache-Control"] = "no-cache, no-store, must-revalidate"
    response.headers["Pragma"] = "no-cache"
    response.headers["Expires"] = "0"
    return response

# Include Routers
app.include_router(meal_router)
app.include_router(forecast_router)
app.include_router(demo_router)
app.include_router(history_router)
app.include_router(alerts_router)

@app.get("/health", tags=["Health Check"])
def health_check():
    return {
        "status": "healthy",
        "database": "sqlite_connected",
        "ifct_records_loaded": len(carb_engine.food_db),
        "disclaimer": settings.DISCLAIMER_TEXT
    }

# Mount Flutter Web Mobile App if built
mobile_web_dir = settings.BASE_DIR / "mobile" / "build" / "web"
if mobile_web_dir.exists():
    from fastapi.staticfiles import StaticFiles
    app.mount("/", StaticFiles(directory=str(mobile_web_dir), html=True), name="mobile_web")
else:
    @app.get("/", tags=["Health Check"])
    def root():
        return {
            "status": "online",
            "service": settings.PROJECT_NAME,
            "version": settings.VERSION,
            "disclaimer": settings.DISCLAIMER_TEXT
        }

