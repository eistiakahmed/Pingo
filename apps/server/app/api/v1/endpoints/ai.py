from fastapi import APIRouter, Depends, status
from app.core.exceptions import AppException
from app.core.rate_limit import check_ai_rate_limit
from app.schemas.ai import ParseReminderRequest, ParseReminderResponse
from app.services.ai_service import AIService

router = APIRouter()


@router.post(
    "/parse-reminder",
    response_model=ParseReminderResponse,
    status_code=status.HTTP_200_OK,
    summary="Parse natural language reminder into structured entity",
    tags=["AI Gateway"],
    dependencies=[Depends(check_ai_rate_limit)],
)
async def parse_reminder(request: ParseReminderRequest) -> ParseReminderResponse:
    """Parses natural language input (English, Bengali, Banglish) using Gemini API."""
    try:
        parsed_data = await AIService.parse_reminder(request)
        return ParseReminderResponse(
            success=True,
            data=parsed_data,
        )
    except AppException:
        raise
    except RuntimeError as re:
        raise AppException(
            title="AI Service Unavailable",
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=str(re),
            type_url="https://api.pingo.app/errors/ai-unavailable",
        )
    except Exception as e:
        # Avoid leaking internal stack trace or API credentials to client
        raise AppException(
            title="AI Extraction Failed",
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Failed to process natural language input. Please verify your request and try again.",
            type_url="https://api.pingo.app/errors/ai-processing-error",
        )

