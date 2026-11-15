from typing import Optional
from pydantic import BaseModel, Field


class DeviceTokenRegisterRequest(BaseModel):
    token: str = Field(..., min_length=10, max_length=512, description="FCM device registration token")
    platform: str = Field(default="android", max_length=32, description="Target OS (android, ios, web)")


class DeviceTokenResponse(BaseModel):
    status: str = "success"
    message: str = "Device token registered successfully"


class TestPushRequest(BaseModel):
    token: Optional[str] = Field(default=None, description="Optional explicit FCM token to test")
    title: str = Field(default="Pingo Test Alert", description="Notification title")
    body: str = Field(default="Backend push notification is active and working!", description="Notification body")


class TestPushResponse(BaseModel):
    status: str
    message: str
    sent_count: int
    details: Optional[list] = None
