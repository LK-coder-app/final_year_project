"""
AgriMind - Firebase Authentication Integration
Interacts with Firebase Authentication using Firebase Identity Toolkit REST API.
Allows registering users directly in Firebase, verifying passwords with Firebase,
and linking Firebase UIDs with local database profiles.
"""
from __future__ import annotations

import os
from typing import Any, Dict, Optional, Tuple
import httpx

FIREBASE_API_KEY = os.getenv("FIREBASE_WEB_API_KEY", "").strip()
FIREBASE_PROJECT_ID = os.getenv("FIREBASE_PROJECT_ID", "final-year-project").strip()

FIREBASE_SIGNUP_URL = "https://identitytoolkit.googleapis.com/v1/accounts:signUp"
FIREBASE_SIGNIN_URL = "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword"
FIREBASE_LOOKUP_URL = "https://identitytoolkit.googleapis.com/v1/accounts:lookup"


def is_firebase_configured() -> bool:
    """Check if Firebase Web API Key is present in environment."""
    key = os.getenv("FIREBASE_WEB_API_KEY", "").strip()
    return bool(key and key != "your_firebase_web_api_key_here")


def firebase_sign_up(email: str, password: str) -> Tuple[bool, Optional[str], Optional[str]]:
    """
    Register a user in Firebase Auth.
    Returns (success: bool, firebase_uid_or_error: str, id_token: str).
    """
    api_key = os.getenv("FIREBASE_WEB_API_KEY", "").strip()
    if not api_key or api_key == "your_firebase_web_api_key_here":
        # Firebase not configured yet, return None for uid
        return True, None, None

    url = f"{FIREBASE_SIGNUP_URL}?key={api_key}"
    payload = {
        "email": email.strip().lower(),
        "password": password,
        "returnSecureToken": True,
    }

    try:
        with httpx.Client(timeout=10.0) as client:
            resp = client.post(url, json=payload)
            data = resp.json()
            if resp.status_code == 200:
                uid = data.get("localId")
                id_token = data.get("idToken")
                return True, uid, id_token
            else:
                err_msg = data.get("error", {}).get("message", "Firebase registration failed")
                return False, err_msg, None
    except Exception as e:
        print(f"[AgriMind Firebase Error] Failed to connect to Firebase: {e}")
        return False, str(e), None


def firebase_sign_in(email: str, password: str) -> Tuple[bool, Optional[str], Optional[str], Optional[str]]:
    """
    Authenticate a user against Firebase Auth.
    Returns (success: bool, firebase_uid: str, id_token: str, error_message: str).
    """
    api_key = os.getenv("FIREBASE_WEB_API_KEY", "").strip()
    if not api_key or api_key == "your_firebase_web_api_key_here":
        # Pass through to local auth
        return False, None, None, "Firebase API Key not configured"

    url = f"{FIREBASE_SIGNIN_URL}?key={api_key}"
    payload = {
        "email": email.strip().lower(),
        "password": password,
        "returnSecureToken": True,
    }

    try:
        with httpx.Client(timeout=10.0) as client:
            resp = client.post(url, json=payload)
            data = resp.json()
            if resp.status_code == 200:
                uid = data.get("localId")
                id_token = data.get("idToken")
                return True, uid, id_token, None
            else:
                err_msg = data.get("error", {}).get("message", "Invalid credentials")
                return False, None, None, err_msg
    except Exception as e:
        print(f"[AgriMind Firebase Error] Failed to authenticate with Firebase: {e}")
        return False, None, None, str(e)
