"""
AgriMind - Email OTP Service
Handles generating, sending, and verifying 6-digit one-time passwords for email verification.
Supports standard SMTP (Gmail App Password, SendGrid, etc.) and safe developer preview mode.
"""
from __future__ import annotations

import os
import random
import secrets
import smtplib
import time
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from typing import Dict, Optional, Tuple

# In-memory storage for active OTPs: email.lower() -> (otp, expiry_timestamp)
_OTP_CACHE: Dict[str, Tuple[str, float]] = {}

# In-memory storage for verified email tokens: token -> (email.lower(), expiry_timestamp)
_VERIFIED_TOKENS: Dict[str, Tuple[str, float]] = {}

OTP_EXPIRY_SECONDS = 600  # 10 minutes
TOKEN_EXPIRY_SECONDS = 1800  # 30 minutes


def generate_otp() -> str:
    """Generate a cryptographically secure 6-digit numeric OTP."""
    return f"{secrets.randbelow(900000) + 100000}"


def send_otp_email(to_email: str, otp: str, user_name: Optional[str] = None) -> Tuple[bool, str]:
    """
    Send verification OTP to the target email via SMTP.
    Returns (success: bool, status_message: str).
    """
    smtp_host = os.getenv("SMTP_HOST", "").strip()
    smtp_port = int(os.getenv("SMTP_PORT", "587"))
    smtp_user = os.getenv("SMTP_USER", "").strip()
    smtp_password = os.getenv("SMTP_PASSWORD", "").strip()
    from_email = os.getenv("SMTP_FROM_EMAIL", smtp_user or "noreply@agrimind.ai").strip()

    name_greeting = f"Hello {user_name}," if user_name else "Hello,"

    subject = f"AgriMind Verification Code: {otp}"

    html_content = f"""
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <title>AgriMind Verification Code</title>
      <style>
        body {{ font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #f8fafc; margin: 0; padding: 20px; }}
        .container {{ max-width: 520px; margin: 0 auto; background: #ffffff; border-radius: 16px; border: 1px solid #e2e8f0; overflow: hidden; box-shadow: 0 4px 12px rgba(0,0,0,0.05); }}
        .header {{ background: linear-gradient(135deg, #059669 0%, #10b981 100%); padding: 28px 24px; text-align: center; color: #ffffff; }}
        .header h1 {{ margin: 0; font-size: 24px; font-weight: 700; letter-spacing: -0.5px; }}
        .header p {{ margin: 6px 0 0 0; opacity: 0.9; font-size: 14px; }}
        .content {{ padding: 32px 28px; color: #334155; line-height: 1.6; }}
        .otp-box {{ background: #f0fdf4; border: 2px dashed #059669; border-radius: 12px; padding: 20px; text-align: center; margin: 24px 0; }}
        .otp-code {{ font-size: 36px; font-weight: 800; color: #047857; letter-spacing: 8px; font-family: monospace; }}
        .expiry {{ font-size: 12px; color: #64748b; margin-top: 8px; }}
        .footer {{ background: #f1f5f9; padding: 16px 28px; text-align: center; font-size: 12px; color: #94a3b8; border-top: 1px solid #e2e8f0; }}
      </style>
    </head>
    <body>
      <div class="container">
        <div class="header">
          <h1>🌾 AgriMind</h1>
          <p>AI Farmer Portal Account Verification</p>
        </div>
        <div class="content">
          <p>{name_greeting}</p>
          <p>Thank you for signing up for AgriMind. Please use the verification code below to verify your email address and complete your registration:</p>
          <div class="otp-box">
            <div class="otp-code">{otp}</div>
            <div class="expiry">Valid for 10 minutes. Do not share this code with anyone.</div>
          </div>
          <p style="font-size: 13px; color: #64748b;">If you did not request this verification code, you can safely ignore this email.</p>
        </div>
        <div class="footer">
          &copy; 2026 AgriMind AI Agricultural Advisory Platform. All rights reserved.
        </div>
      </div>
    </body>
    </html>
    """

    # If SMTP is configured, attempt sending via SMTP
    if smtp_host and smtp_user and smtp_password:
        try:
            msg = MIMEMultipart("alternative")
            msg["Subject"] = subject
            msg["From"] = f"AgriMind Verification <{from_email}>"
            msg["To"] = to_email

            text_part = MIMEText(f"Your AgriMind verification code is: {otp}. Valid for 10 minutes.", "plain")
            html_part = MIMEText(html_content, "html")

            msg.attach(text_part)
            msg.attach(html_part)

            if smtp_port == 465:
                with smtplib.SMTP_SSL(smtp_host, smtp_port, timeout=10) as server:
                    server.login(smtp_user, smtp_password)
                    server.sendmail(from_email, [to_email], msg.as_string())
            else:
                with smtplib.SMTP(smtp_host, smtp_port, timeout=10) as server:
                    server.starttls()
                    server.login(smtp_user, smtp_password)
                    server.sendmail(from_email, [to_email], msg.as_string())

            print(f"[AgriMind Email] Successfully sent OTP to {to_email}")
            return True, f"Verification code sent to {to_email}"
        except Exception as e:
            print(f"[AgriMind Email ERROR] Failed to send email via SMTP ({smtp_host}): {e}")
            # Fallback to local dev logging
            return True, f"Code generated (SMTP issue: {e})"
    else:
        # Developer / Preview Mode
        print(f"[AgriMind Email DEV PREVIEW] OTP for {to_email} is: {otp}")
        return True, f"Verification code generated for {to_email}"


def request_email_otp(email: str, name: Optional[str] = None) -> Tuple[bool, str, Optional[str]]:
    """
    Generate, cache, and dispatch OTP to target email.
    Returns (success, message, debug_otp_if_dev).
    """
    email_clean = email.strip().lower()
    otp = generate_otp()
    expiry = time.time() + OTP_EXPIRY_SECONDS
    _OTP_CACHE[email_clean] = (otp, expiry)

    success, msg = send_otp_email(email_clean, otp, user_name=name)

    # If SMTP is not configured or in debug mode, provide debug_otp
    is_dev = not bool(os.getenv("SMTP_HOST") and os.getenv("SMTP_USER"))
    debug_code = otp if is_dev else None

    return success, msg, debug_code


def verify_email_otp(email: str, entered_otp: str) -> Tuple[bool, str, Optional[str]]:
    """
    Validate entered OTP for an email.
    If valid, returns (True, success_msg, verification_token).
    """
    email_clean = email.strip().lower()
    entered_clean = entered_otp.strip()

    cached = _OTP_CACHE.get(email_clean)
    if not cached:
        return False, "No verification code requested for this email, or code has expired.", None

    stored_otp, expiry = cached
    if time.time() > expiry:
        _OTP_CACHE.pop(email_clean, None)
        return False, "Verification code has expired. Please request a new code.", None

    if stored_otp != entered_clean:
        return False, "Incorrect verification code. Please check and try again.", None

    # Code is valid! Consume it
    _OTP_CACHE.pop(email_clean, None)

    # Issue a verification token valid for 30 minutes
    token = f"agm_verified_{secrets.token_urlsafe(24)}"
    _VERIFIED_TOKENS[token] = (email_clean, time.time() + TOKEN_EXPIRY_SECONDS)

    return True, "Email verified successfully!", token


def is_email_verified(email: str, token: Optional[str] = None) -> bool:
    """
    Check if email was verified by either:
    1. A valid non-expired verification token, OR
    2. Token matches email record in _VERIFIED_TOKENS.
    """
    if not token:
        return False

    record = _VERIFIED_TOKENS.get(token)
    if not record:
        return False

    verified_email, expiry = record
    if time.time() > expiry:
        _VERIFIED_TOKENS.pop(token, None)
        return False

    return verified_email.lower() == email.strip().lower()
