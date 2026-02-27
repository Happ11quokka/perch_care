from pydantic import BaseModel, Field


class DeviceTokenCreate(BaseModel):
    token: str = Field(..., min_length=1)
    platform: str = Field(..., pattern="^(ios|android)$")


class DeviceTokenDelete(BaseModel):
    token: str = Field(..., min_length=1)
