from pydantic import BaseModel, Field


class DeviceTokenCreate(BaseModel):
    token: str = Field(..., min_length=1)
    platform: str = Field(..., pattern="^(ios|android)$")
    language: str = Field(default="zh", pattern="^(ko|en|zh)$")


class DeviceTokenDelete(BaseModel):
    token: str = Field(..., min_length=1)
