"""
AgriMind - Authentication & User Management Pydantic Schemas
"""
from __future__ import annotations
from datetime import datetime
from typing import List, Optional
from pydantic import BaseModel, EmailStr, Field


class UserRegisterRequest(BaseModel):
    full_name: str = Field(..., min_length=2, max_length=100, description="Farmer full name")
    email: str = Field(..., description="Email address or username")
    phone: Optional[str] = Field(None, max_length=25, description="Mobile number")
    password: str = Field(..., min_length=4, description="Password")
    firebase_uid: Optional[str] = Field(None, description="Optional Firebase UID")


class UserLoginRequest(BaseModel):
    username: str = Field(..., description="Email or phone number")
    password: str = Field(..., min_length=1, description="Password")
    firebase_token: Optional[str] = Field(None, description="Optional Firebase ID Token")


class UserResponse(BaseModel):
    id: int
    email: str
    phone: Optional[str] = None
    full_name: str
    role: str
    firebase_uid: Optional[str] = None
    is_active: bool
    created_at: Optional[datetime] = None
    last_login: Optional[datetime] = None

    class Config:
        from_attributes = True


class TokenResponse(BaseModel):
    success: bool
    access_token: str
    token_type: str = "bearer"
    user: UserResponse
    message: str = "Authenticated successfully."


class UserStatusUpdateRequest(BaseModel):
    is_active: bool


class FarmerListResponse(BaseModel):
    total: int
    farmers: List[UserResponse]
