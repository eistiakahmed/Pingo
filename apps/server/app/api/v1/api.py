from fastapi import APIRouter
from app.api.v1.endpoints import ai, auth, health, sync

api_router = APIRouter()
api_router.include_router(health.router)
api_router.include_router(auth.router, prefix="/auth")
api_router.include_router(ai.router, prefix="/ai")
api_router.include_router(sync.router, prefix="/sync")
