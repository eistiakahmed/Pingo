import logging
import os
from contextlib import asynccontextmanager
from fastapi import FastAPI, HTTPException
from fastapi.responses import HTMLResponse, FileResponse
from fastapi.staticfiles import StaticFiles
from fastapi.exceptions import RequestValidationError
from starlette.exceptions import HTTPException as StarletteHTTPException
from app.core.config import get_settings
from app.core.exceptions import (
    AppException,
    app_exception_handler,
    http_exception_handler,
    validation_exception_handler,
)
from app.core.middleware import setup_middlewares
from app.api.v1.api import api_router
from app.api.v1.endpoints.health import router as health_router
from app.api.v1.endpoints.voice import router as voice_router
from app.db.base import Base
from app.db.session import engine
import app.models  # noqa: F401 - ensure all SQLAlchemy models are registered
from app.services.fcm_service import fcm_push_service
from app.services.reminder_scheduler import reminder_scheduler

logger = logging.getLogger(__name__)
settings = get_settings()

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
STATIC_AUDIO_PATH = os.path.join(BASE_DIR, "static", "audio")
os.makedirs(STATIC_AUDIO_PATH, exist_ok=True)


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Ensure newly added tables (reminders, documentations) exist in PostgreSQL
    try:
        async with engine.begin() as conn:
            await conn.run_sync(Base.metadata.create_all)
    except Exception as exc:
        logger.warning("[Startup] Database schema check skipped/failed: %s", exc)

    # Startup: Initialize Firebase Admin SDK and start async background scheduler
    fcm_push_service.initialize()
    reminder_scheduler.start()
    yield
    # Shutdown: Stop reminder scheduler cleanly
    await reminder_scheduler.stop()


app = FastAPI(
    title=settings.APP_NAME,
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
    openapi_url="/openapi.json",
    lifespan=lifespan,
)

# Exception handlers
app.add_exception_handler(AppException, app_exception_handler)  # type: ignore[arg-type]
app.add_exception_handler(StarletteHTTPException, http_exception_handler)  # type: ignore[arg-type]
app.add_exception_handler(RequestValidationError, validation_exception_handler)  # type: ignore[arg-type]

# Middlewares
setup_middlewares(app, settings)

# Mount /static/audio for generated Edge-TTS MP3 responses
app.mount("/static/audio", StaticFiles(directory=STATIC_AUDIO_PATH), name="static_audio")

# Root level health for standard load balancers
app.include_router(health_router)

# Exact /api/voice-command route as well as versioned /api/v1 routes
app.include_router(voice_router, prefix="/api")
app.include_router(api_router, prefix=settings.API_V1_PREFIX)


@app.get("/", tags=["Root"])
async def root():
    return {
        "app": settings.APP_NAME,
        "docs": "/docs",
        "health": "/health",
        "api_v1": settings.API_V1_PREFIX,
        "voice_command": "/api/voice-command",
        "download": "/download",
    }


# APK Web Distribution
DOWNLOAD_HTML_PATH = os.path.join(BASE_DIR, "static", "download.html")
PINGO_ICON_PATH = os.path.join(BASE_DIR, "static", "pingo_icon.png")
APK_CANDIDATE_PATHS = [
    "/app/downloads/app-release.apk",
    os.path.join(BASE_DIR, "static", "app-release.apk"),
    os.path.join(os.path.dirname(BASE_DIR), "downloads", "app-release.apk"),
]


@app.get("/download/pingo_icon.png", tags=["Distribution"])
async def download_pingo_icon():
    if os.path.exists(PINGO_ICON_PATH):
        return FileResponse(path=PINGO_ICON_PATH, media_type="image/png")
    raise HTTPException(status_code=404, detail="Icon not found")


@app.get("/download", response_class=HTMLResponse, tags=["Distribution"])
@app.get("/download/", response_class=HTMLResponse, tags=["Distribution"])
async def download_portal():
    if os.path.exists(DOWNLOAD_HTML_PATH):
        with open(DOWNLOAD_HTML_PATH, "r", encoding="utf-8") as f:
            return HTMLResponse(content=f.read())
    return HTMLResponse(
        content="<h2>Pingo APK Download portal is currently initializing...</h2>",
        status_code=200,
    )


@app.get("/download/app-release.apk", tags=["Distribution"])
@app.get("/app-release.apk", tags=["Distribution"])
async def download_apk_binary():
    for apk_path in APK_CANDIDATE_PATHS:
        if os.path.exists(apk_path) and os.path.getsize(apk_path) > 1000000:
            return FileResponse(
                path=apk_path,
                filename="pingo-release.apk",
                media_type="application/vnd.android.package-archive",
            )
    raise HTTPException(status_code=404, detail="Pingo release APK binary not found on server")


