from fastapi import APIRouter, Depends, File, Form, UploadFile, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.schemas.voice import VoiceCommandResponse
from app.services.voice_assistant_service import VoiceAssistantService

router = APIRouter(tags=["Voice Assistant"])


@router.post(
    "/voice-command",
    response_model=VoiceCommandResponse,
    status_code=status.HTTP_200_OK,
    summary="End-to-end Voice AI Assistant (Groq Whisper STT -> DeepSeek Tools -> Edge-TTS Bangla)",
)
async def handle_voice_command(
    audio: UploadFile = File(..., description="Uploaded voice audio file (.m4a, .wav, .mp3, .webm)"),
    user_id: str = Form(..., description="User identifier associated with reminders and documentation"),
    db: AsyncSession = Depends(get_db),
) -> VoiceCommandResponse:
    return await VoiceAssistantService.process_voice_command(
        audio=audio,
        user_id=user_id,
        db=db,
    )
