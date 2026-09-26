"""
AgriMind - Authentication & User Management Pydantic Schemas
"""
from __future__ import annotations
from datetime import datetime
from typing import List, Optional
from pydantic import BaseModel, Field


# ─── Email OTP Schemas ────────────────────────────────────────────────────────

class SendOtpRequest(BaseModel):
    email: str = Field(..., description="Target email address for OTP")
    name: Optional[str] = Field(None, description="Optional user name for personalized email")


class SendOtpResponse(BaseModel):
    success: bool
    message: str
    email: str
    debug_otp: Optional[str] = Field(None, description="Provided during development if SMTP is not configured")


class VerifyOtpRequest(BaseModel):
    email: str = Field(..., description="Email address being verified")
    otp: str = Field(..., min_length=4, max_length=10, description="Verification code entered by user")


class VerifyOtpResponse(BaseModel):
    success: bool
    message: str
    email: str
    verification_token: str = Field(..., description="Proof token used for completing registration")


# ─── User Registration & Login ────────────────────────────────────────────────

class UserRegisterRequest(BaseModel):
    full_name: str = Field(..., min_length=2, max_length=100, description="Farmer full name")
    email: str = Field(..., description="Email address (mail id)")
    phone: Optional[str] = Field(None, max_length=25, description="Mobile number")
    password: str = Field(..., min_length=4, description="Created password")
    confirm_password: Optional[str] = Field(None, description="Confirm password")
    otp: Optional[str] = Field(None, description="OTP code entered by user")
    verification_token: Optional[str] = Field(None, description="Email verification token from OTP verify endpoint")
    firebase_uid: Optional[str] = Field(None, description="Optional Firebase UID")


class UserLoginRequest(BaseModel):
    username: str = Field(..., description="Mail ID / Email or Admin ID")
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
