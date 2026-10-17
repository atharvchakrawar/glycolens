import time
import logging
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import Response

# Configure structured logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] [%(name)s] %(message)s"
)
logger = logging.getLogger("glycolens")

class LatencyLoggingMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        start_time = time.perf_counter()
        response: Response = await call_next(request)
        process_time_ms = (time.perf_counter() - start_time) * 1000.0
        
        response.headers["X-Process-Time-Ms"] = f"{process_time_ms:.2f}"
        
        log_msg = f"{request.method} {request.url.path} completed in {process_time_ms:.2f}ms with status {response.status_code}"
        if process_time_ms > 2000.0:
            logger.warning(f"⚠️ LATENCY SLA EXCEEDED (>2000ms): {log_msg}")
        else:
            logger.info(log_msg)
            
        return response
