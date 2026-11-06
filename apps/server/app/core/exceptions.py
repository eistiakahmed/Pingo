from typing import Any, Dict, Optional
from fastapi import Request, status
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from starlette.exceptions import HTTPException as StarletteHTTPException


class AppException(Exception):
    """Base application exception for domain errors."""

    def __init__(
        self,
        title: str,
        status_code: int = status.HTTP_400_BAD_REQUEST,
        detail: Optional[str] = None,
        type_url: str = "about:blank",
        extra: Optional[Dict[str, Any]] = None,
    ):
        super().__init__(detail or title)
        self.title = title
        self.status_code = status_code
        self.detail = detail or title
        self.type_url = type_url
        self.extra = extra or {}


async def app_exception_handler(request: Request, exc: AppException) -> JSONResponse:
    """RFC 7807 Problem Details for AppException."""
    payload = {
        "type": exc.type_url,
        "title": exc.title,
        "status": exc.status_code,
        "detail": exc.detail,
        "instance": request.url.path,
        **exc.extra,
    }
    return JSONResponse(status_code=exc.status_code, content=payload)


async def http_exception_handler(request: Request, exc: StarletteHTTPException) -> JSONResponse:
    """RFC 7807 Problem Details for standard HTTPException."""
    payload = {
        "type": "about:blank",
        "title": exc.detail if isinstance(exc.detail, str) else "HTTP Exception",
        "status": exc.status_code,
        "detail": exc.detail if isinstance(exc.detail, str) else str(exc.detail),
        "instance": request.url.path,
    }
    return JSONResponse(status_code=exc.status_code, content=payload)


async def validation_exception_handler(request: Request, exc: RequestValidationError) -> JSONResponse:
    """RFC 7807 Problem Details for Pydantic / FastAPI request validation errors."""
    payload = {
        "type": "https://api.pingo.app/errors/validation-error",
        "title": "Unprocessable Entity",
        "status": status.HTTP_422_UNPROCESSABLE_ENTITY,
        "detail": "Request validation failed on one or more fields",
        "instance": request.url.path,
        "invalid_params": exc.errors(),
    }
    return JSONResponse(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, content=payload)

