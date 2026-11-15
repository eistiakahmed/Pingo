from pydantic import BaseModel, Field


class DeviceTokenRegisterRequest(BaseModel):
    token: str = Field(..., min_length=10, max_length=512, description="FCM device registration token")
    platform: str = Field(default="android", max_length=32, description="Target OS (android, ios, web)")


class DeviceTokenResponse(BaseModel):
    status: str = "success"
    message: str = "Device token registered successfully"
