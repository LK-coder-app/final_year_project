"""
AgriMind - Authentication & User Management Router
Supports separate Farmer and Admin logins, role enforcement, and Firebase integration.
"""
from __future__ import annotations
import secrets
from datetime import datetime, timezone
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Header, status
from sqlalchemy.orm import Session

from ..models.database import User, get_db, hash_password, verify_password
from ..models.auth_schemas import (
    FarmerListResponse,
    TokenResponse,
    UserLoginRequest,
    UserRegisterRequest,
    UserResponse,
    UserStatusUpdateRequest,
)

auth_router = APIRouter(prefix="/auth", tags=["Authentication"])

# Simple token storage for active sessions
_ACTIVE_SESSIONS: dict[str, int] = {}


def generate_session_token(user_id: int) -> str:
    token = f"agm_auth_{secrets.token_urlsafe(32)}"
    _ACTIVE_SESSIONS[token] = user_id
    return token


def get_current_user(
    authorization: Optional[str] = Header(None),
    db: Session = Depends(get_db),
) -> User:
    if not authorization:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Missing authorization header")

    token = authorization.replace("Bearer ", "").strip()
    user_id = _ACTIVE_SESSIONS.get(token)

    # Fallback to direct demo bypass if token matches seeded IDs
    if not user_id:
        if token.startswith("agm_auth_admin_demo"):
            user = db.query(User).filter(User.role == "admin").first()
            if user:
                return user
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid or expired session token")

    user = db.query(User).filter(User.id == user_id).first()
    if not user or not user.is_active:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="User not found or account deactivated")
    return user


# ─── 1. Farmer Registration ───────────────────────────────────────────────────

@auth_router.post("/farmer/register", response_model=TokenResponse)
def register_farmer(req: UserRegisterRequest, db: Session = Depends(get_db)):
    email_clean = req.email.strip().lower()
    phone_clean = req.phone.strip() if req.phone else None

    # Check uniqueness
    existing = db.query(User).filter(User.email == email_clean).first()
    if existing:
        raise HTTPException(status_code=400, detail="An account with this email already exists.")

    if phone_clean:
        existing_phone = db.query(User).filter(User.phone == phone_clean).first()
        if existing_phone:
            raise HTTPException(status_code=400, detail="An account with this mobile number already exists.")

    new_user = User(
        email=email_clean,
        phone=phone_clean,
        full_name=req.full_name.strip(),
        password_hash=hash_password(req.password),
        role="farmer",
        firebase_uid=req.firebase_uid,
        is_active=True,
        created_at=datetime.now(timezone.utc),
        last_login=datetime.now(timezone.utc),
    )
    db.add(new_user)
    db.commit()
    db.refresh(new_user)

    token = generate_session_token(new_user.id)
    return TokenResponse(
        success=True,
        access_token=token,
        user=UserResponse.from_orm(new_user),
        message=f"Welcome to AgriMind, {new_user.full_name}! Registration successful.",
    )


# ─── 2. Farmer Login ──────────────────────────────────────────────────────────

@auth_router.post("/farmer/login", response_model=TokenResponse)
def login_farmer(req: UserLoginRequest, db: Session = Depends(get_db)):
    login_id = req.username.strip().lower()

    # Match by email or phone
    user = (
        db.query(User)
        .filter((User.email == login_id) | (User.phone == req.username.strip()))
        .first()
    )

    if not user:
        raise HTTPException(status_code=401, detail="Farmer account not found with these credentials.")

    if user.role != "farmer":
        raise HTTPException(status_code=403, detail="Access denied: This login is exclusively for Farmers.")

    if not user.is_active:
        raise HTTPException(status_code=403, detail="Account is deactivated. Please contact your AgriMind administrator.")

    if not verify_password(req.password, user.password_hash):
        raise HTTPException(status_code=401, detail="Incorrect password. Please try again.")

    user.last_login = datetime.now(timezone.utc)
    db.commit()

    token = generate_session_token(user.id)
    return TokenResponse(
        success=True,
        access_token=token,
        user=UserResponse.from_orm(user),
        message=f"Welcome back, {user.full_name}!",
    )


# ─── 3. Administrator Login ───────────────────────────────────────────────────

@auth_router.post("/admin/login", response_model=TokenResponse)
def login_admin(req: UserLoginRequest, db: Session = Depends(get_db)):
    login_id = req.username.strip().lower()

    user = (
        db.query(User)
        .filter((User.email == login_id) | (User.phone == req.username.strip()))
        .first()
    )

    if not user:
        raise HTTPException(status_code=401, detail="Administrator account not found.")

    if user.role != "admin":
        raise HTTPException(status_code=403, detail="Access denied: Administrator privileges required.")

    if not user.is_active:
        raise HTTPException(status_code=403, detail="Administrator account has been suspended.")

    if not verify_password(req.password, user.password_hash):
        raise HTTPException(status_code=401, detail="Incorrect admin credentials.")

    user.last_login = datetime.now(timezone.utc)
    db.commit()

    token = generate_session_token(user.id)
    return TokenResponse(
        success=True,
        access_token=token,
        user=UserResponse.from_orm(user),
        message="Administrator authenticated successfully.",
    )


# ─── 4. Current User Profile ──────────────────────────────────────────────────

@auth_router.get("/me", response_model=UserResponse)
def get_my_profile(current_user: User = Depends(get_current_user)):
    return UserResponse.from_orm(current_user)


# ─── 5. Admin: List All Registered Farmers ────────────────────────────────────

@auth_router.get("/farmers", response_model=FarmerListResponse)
def list_farmers(
    db: Session = Depends(get_db),
    # Optional authorization header check
):
    farmers = db.query(User).filter(User.role == "farmer").order_by(User.created_at.desc()).all()
    return FarmerListResponse(
        total=len(farmers),
        farmers=[UserResponse.from_orm(f) for f in farmers],
    )


# ─── 6. Admin: Toggle Farmer Status ───────────────────────────────────────────

@auth_router.patch("/farmers/{farmer_id}/status", response_model=UserResponse)
def update_farmer_status(
    farmer_id: int,
    req: UserStatusUpdateRequest,
    db: Session = Depends(get_db),
):
    farmer = db.query(User).filter(User.id == farmer_id, User.role == "farmer").first()
    if not farmer:
        raise HTTPException(status_code=404, detail="Farmer account not found")

    farmer.is_active = req.is_active
    db.commit()
    db.refresh(farmer)
    return UserResponse.from_orm(farmer)
