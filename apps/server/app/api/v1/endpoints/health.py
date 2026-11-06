from fastapi import APIRouter
from pydantic import BaseModel

router = APIRouter()


class HealthResponse(BaseModel):
    status: str
    service: str
    version: str


@router.get("/health", response_model=HealthResponse, tags=["Health"])
async def get_health():
    """System health check endpoint."""
    return HealthResponse(
        status="healthy",
        service="pingo-backend",
        version="1.0.0",
    )
