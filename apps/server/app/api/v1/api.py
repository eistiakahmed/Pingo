from fastapi import APIRouter
from app.api.v1.endpoints import ai, auth, devices, health, sync, voice

api_router = APIRouter()
api_router.include_router(health.router)
api_router.include_router(auth.router, prefix="/auth")
api_router.include_router(ai.router, prefix="/ai")
api_router.include_router(sync.router, prefix="/sync")
api_router.include_router(devices.router, prefix="/devices")
api_router.include_router(voice.router)
