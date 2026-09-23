"""
AgriMind - API Routes
"""
from __future__ import annotations

import os
import secrets
from datetime import datetime, timezone
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import FileResponse
from sqlalchemy.orm import Session

from ..models.database import ConversationLog, FarmerRequirement, get_db
from ..models.schemas import (
    AnalysisResponse,
    ChatRequest,
    ChatResponse,
    FillMissingRequest,
    FillMissingResponse,
    LLMConfigRequest,
    RequestMissingResponse,
    RequirementListResponse,
    RequirementResponse,
    RequirementSubmitRequest,
    StatusUpdateRequest,
    SubmitResponse,
)
from ..engine.nlu_extractor import nlu_extractor
from ..engine.dialogue_tracker import dialogue_tracker
from ..engine.conflict_detector import conflict_detector
from ..engine.adaptive_questioner import adaptive_questioner
from ..engine.pdf_generator import generate_report
from ..engine.pdf_analyzer import analyze_requirement

router = APIRouter()

APP_BASE_URL = os.getenv("APP_BASE_URL", "http://localhost:8000")
TWILIO_ACCOUNT_SID = os.getenv("TWILIO_ACCOUNT_SID", "")
TWILIO_AUTH_TOKEN = os.getenv("TWILIO_AUTH_TOKEN", "")
TWILIO_FROM_NUMBER = os.getenv("TWILIO_FROM_NUMBER", "")


def _send_sms(to_phone: str, body: str) -> bool:
    """Send SMS via Twilio. Returns True on success."""
    try:
        if not all([TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN, TWILIO_FROM_NUMBER]):
            return False
        from twilio.rest import Client
        client = Client(TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN)
        client.messages.create(to=to_phone, from_=TWILIO_FROM_NUMBER, body=body)
        return True
    except Exception as e:
        print(f"[AgriMind] SMS failed: {e}")
        return False


# ─── Health ───────────────────────────────────────────────────────────────────

@router.get("/health")
def health_check():
    return {
        "status": "ok",
        "service": "AgriMind API",
        "version": "2.0.0",
        "llm_provider": nlu_extractor.llm_provider,
    }


# ─── LLM Config ───────────────────────────────────────────────────────────────

@router.post("/config/llm")
def configure_llm(config: LLMConfigRequest):
    nlu_extractor.set_provider(config.provider, config.api_key or "", config.model or "")
    os.environ["LLM_PROVIDER"] = config.provider
    if config.api_key:
        if config.provider == "gemini":
            os.environ["GEMINI_API_KEY"] = config.api_key
        elif config.provider == "openai":
            os.environ["OPENAI_API_KEY"] = config.api_key
    return {"success": True, "provider": config.provider}


@router.get("/config/llm")
def get_llm_config():
    return {
        "provider": nlu_extractor.llm_provider,
        "gemini_model": nlu_extractor.gemini_model,
        "openai_model": nlu_extractor.openai_model,
        "gemini_configured": bool(
            nlu_extractor.gemini_api_key
            and nlu_extractor.gemini_api_key != "your_gemini_api_key_here"
        ),
        "openai_configured": bool(
            nlu_extractor.openai_api_key
            and nlu_extractor.openai_api_key != "your_openai_api_key_here"
        ),
    }


# ─── Chat ─────────────────────────────────────────────────────────────────────

@router.post("/chat", response_model=ChatResponse)
async def chat(req: ChatRequest, db: Session = Depends(get_db)):
    if req.llm_provider and req.llm_provider != nlu_extractor.llm_provider:
        nlu_extractor.llm_provider = req.llm_provider.lower()

    session = dialogue_tracker.get_or_create(req.session_id)
    is_first = session.turn_index == 0
    context_history = session.get_last_n_turns(6)

    extracted = await nlu_extractor.extract(req.message, context_history=context_history)
    extraction_method = extracted.pop("_extraction_method", "rule_based")
    language_detected = extracted.pop("_language", "english")

    session.language = language_detected
    session.update_slots(extracted)
    session.add_turn("user", req.message)

    new_slots = {k: v for k, v in extracted.items() if v is not None}
    conflicts, feasibility_score, feasibility_details = conflict_detector.analyze(session.slots)
    missing_required = session.get_missing_required_slots()
    missing_optional = session.get_missing_optional_slots()

    reply = adaptive_questioner.generate_response(
        slots=session.slots,
        missing_required=missing_required,
        missing_optional=missing_optional,
        conflicts=conflicts,
        language=language_detected,
        is_first_turn=is_first,
        turn_index=session.turn_index,
        extracted_this_turn=new_slots,
    )
    session.add_turn("assistant", reply)

    try:
        log = ConversationLog(
            session_id=req.session_id,
            turn_index=session.turn_index,
            role="user",
            message=req.message,
            language_detected=language_detected,
            slots_extracted=new_slots,
        )
        db.add(log)
        db.commit()
    except Exception:
        pass

    return ChatResponse(
        session_id=req.session_id,
        reply=reply,
        language_detected=language_detected,
        extracted_slots=session.slots,
        missing_slots=missing_required + missing_optional,
        conflicts=conflicts,
        completion_pct=session.get_completion_pct(),
        is_complete=session.is_complete(),
        next_question=None,
        turn_index=session.turn_index,
    )


# ─── Requirement Submission ───────────────────────────────────────────────────

@router.post("/requirements/submit", response_model=SubmitResponse)
async def submit_requirement(req: RequirementSubmitRequest, db: Session = Depends(get_db)):
    session = dialogue_tracker.get(req.session_id)
    if not session:
        raise HTTPException(status_code=404, detail="Session not found. Please start a new conversation.")

    slots = session.slots
    conflicts, feasibility_score, feasibility_details = conflict_detector.analyze(slots)

    record = FarmerRequirement(
        session_id=req.session_id,
        farmer_name=req.farmer_name,
        farmer_phone=req.farmer_phone,
        district=slots.get("district"),
        language=session.language,
        land_size=slots.get("land_size"),
        land_unit=slots.get("land_unit"),
        crop_types=slots.get("crop_types"),
        soil_type=slots.get("soil_type"),
        water_source=slots.get("water_source"),
        borewell_depth_ft=slots.get("borewell_depth_ft"),
        open_well_depth_ft=slots.get("open_well_depth_ft"),
        water_discharge_lph=slots.get("water_discharge_lph"),
        motor_hp=slots.get("motor_hp"),
        power_supply_phase=slots.get("power_supply_phase"),
        power_hours_per_day=slots.get("power_hours_per_day"),
        irrigation_type=slots.get("irrigation_type"),
        budget_inr=slots.get("budget_inr"),
        extracted_slots=slots,
        conflicts=conflicts,
        feasibility_score=feasibility_score,
        feasibility_details=feasibility_details,
        status="pending",
        pdf_version=1,
        submitted_at=datetime.now(timezone.utc),
    )
    db.add(record)
    db.commit()
    db.refresh(record)

    pdf_path = None
    try:
        pdf_path = generate_report(
            requirement_id=record.id,
            farmer_name=req.farmer_name,
            farmer_phone=req.farmer_phone,
            slots={**slots, "_language": session.language},
            conflicts=conflicts,
            feasibility_score=feasibility_score,
            feasibility_details=feasibility_details,
            status="pending",
        )
        record.pdf_path = pdf_path
        db.commit()
    except Exception as e:
        print(f"PDF generation error (non-fatal): {e}")

    return SubmitResponse(
        success=True,
        requirement_id=record.id,
        session_id=req.session_id,
        message=f"Requirement AGM-{record.id:04d} submitted successfully! Our team will contact you within 24 hours.",
        feasibility_score=feasibility_score,
        conflicts_count=len(conflicts),
        pdf_available=pdf_path is not None,
    )


# ─── Requirements CRUD ────────────────────────────────────────────────────────

@router.get("/requirements", response_model=RequirementListResponse)
def list_requirements(
    status: Optional[str] = None,
    district: Optional[str] = None,
    skip: int = 0,
    limit: int = 50,
    db: Session = Depends(get_db),
):
    query = db.query(FarmerRequirement)
    if status:
        query = query.filter(FarmerRequirement.status == status)
    if district:
        query = query.filter(FarmerRequirement.district.ilike(f"%{district}%"))
    total = query.count()
    items = query.order_by(FarmerRequirement.created_at.desc()).offset(skip).limit(limit).all()
    return RequirementListResponse(total=total, items=items)


@router.get("/requirements/{req_id}", response_model=RequirementResponse)
def get_requirement(req_id: int, db: Session = Depends(get_db)):
    record = db.query(FarmerRequirement).filter(FarmerRequirement.id == req_id).first()
    if not record:
        raise HTTPException(status_code=404, detail="Requirement not found")
    return record


@router.get("/requirements/{req_id}/pdf")
def download_pdf(req_id: int, db: Session = Depends(get_db)):
    record = db.query(FarmerRequirement).filter(FarmerRequirement.id == req_id).first()
    if not record:
        raise HTTPException(status_code=404, detail="Requirement not found")
    if not record.pdf_path or not os.path.exists(record.pdf_path):
        try:
            pdf_path = generate_report(
                requirement_id=record.id,
                farmer_name=record.farmer_name or "Unknown Farmer",
                farmer_phone=record.farmer_phone,
                slots={**(record.extracted_slots or {}), "_language": record.language or "english"},
                conflicts=record.conflicts or [],
                feasibility_score=record.feasibility_score or 0.0,
                feasibility_details=record.feasibility_details or {},
                status=record.status or "pending",
            )
            record.pdf_path = pdf_path
            db.commit()
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"PDF generation failed: {str(e)}")
    return FileResponse(
        path=record.pdf_path,
        media_type="application/pdf",
        filename=f"AgriMind_Report_AGM-{req_id:04d}.pdf",
    )


@router.post("/requirements/{req_id}/status")
def update_status(req_id: int, req: StatusUpdateRequest, db: Session = Depends(get_db)):
    record = db.query(FarmerRequirement).filter(FarmerRequirement.id == req_id).first()
    if not record:
        raise HTTPException(status_code=404, detail="Requirement not found")
    record.status = req.status
    if req.company_notes:
        record.company_notes = req.company_notes
    record.updated_at = datetime.now(timezone.utc)
    db.commit()
    return {"success": True, "new_status": req.status}


# ─── Admin: LLM Analysis ─────────────────────────────────────────────────────

@router.post("/requirements/{req_id}/analyze", response_model=AnalysisResponse)
async def analyze_submission(req_id: int, db: Session = Depends(get_db)):
    record = db.query(FarmerRequirement).filter(FarmerRequirement.id == req_id).first()
    if not record:
        raise HTTPException(status_code=404, detail="Requirement not found")

    result = await analyze_requirement(
        slots=record.extracted_slots or {},
        conflicts=record.conflicts or [],
        farmer_name=record.farmer_name or "Unknown",
        gemini_api_key=nlu_extractor.gemini_api_key,
        gemini_model=nlu_extractor.gemini_model,
    )

    record.missing_fields = result["missing_required"] + result["missing_optional"]
    record.llm_analysis_text = result["analysis_text"]
    record.updated_at = datetime.now(timezone.utc)
    db.commit()

    return AnalysisResponse(
        requirement_id=req_id,
        present_fields=result["present_fields"],
        missing_required=result["missing_required"],
        missing_optional=result["missing_optional"],
        warnings=result["warnings"],
        analysis_text=result["analysis_text"],
    )


# ─── Admin: Request Missing Data (token + SMS) ───────────────────────────────

@router.post("/requirements/{req_id}/request-missing", response_model=RequestMissingResponse)
async def request_missing_data(req_id: int, db: Session = Depends(get_db)):
    record = db.query(FarmerRequirement).filter(FarmerRequirement.id == req_id).first()
    if not record:
        raise HTTPException(status_code=404, detail="Requirement not found")

    token = secrets.token_urlsafe(24)
    record.follow_up_token = token
    record.follow_up_sent_at = datetime.now(timezone.utc)
    db.commit()

    form_url = f"{APP_BASE_URL}/form.html?token={token}"

    # Run analysis to get missing fields if not already done
    if not record.missing_fields:
        result = await analyze_requirement(
            slots=record.extracted_slots or {},
            conflicts=record.conflicts or [],
            farmer_name=record.farmer_name or "Farmer",
        )
        missing_fields = result["missing_required"]
        record.missing_fields = result["missing_required"] + result["missing_optional"]
        db.commit()
    else:
        req_keys = {"land_size", "land_unit", "crop_types", "water_source", "motor_hp", "irrigation_type"}
        missing_fields = [f for f in record.missing_fields if f.get("field") in req_keys]

    # Send SMS
    sms_sent = False
    if record.farmer_phone:
        name = record.farmer_name or "Farmer"
        sms_body = (
            f"Dear {name}, AgriMind requires additional information "
            f"for your form AGM-{req_id:04d}. "
            f"Please complete it here: {form_url}"
        )
        sms_sent = _send_sms(record.farmer_phone, sms_body)

    sms_note = f"SMS sent to {record.farmer_phone}" if sms_sent else "SMS not sent (check Twilio config)"
    return RequestMissingResponse(
        success=True,
        requirement_id=req_id,
        follow_up_token=token,
        form_url=form_url,
        missing_fields=missing_fields,
        sms_sent=sms_sent,
        message=f"Follow-up form ready. {sms_note}.",
    )


# ─── Farmer: Get form by token ────────────────────────────────────────────────

_FIELD_LABELS = {
    "land_size": "Farm Land Area",
    "land_unit": "Land Unit (acres/hectares)",
    "crop_types": "Crop Types",
    "water_source": "Water Source",
    "motor_hp": "Motor HP",
    "irrigation_type": "Irrigation Type",
    "soil_type": "Soil Type",
    "borewell_depth_ft": "Borewell Depth (feet)",
    "open_well_depth_ft": "Open Well Depth (feet)",
    "power_supply_phase": "Power Phase",
    "power_hours_per_day": "Power Hours / Day",
    "district": "District",
    "budget_inr": "Budget (INR)",
}


@router.get("/form/{token}")
def get_form_by_token(token: str, db: Session = Depends(get_db)):
    record = db.query(FarmerRequirement).filter(FarmerRequirement.follow_up_token == token).first()
    if not record:
        raise HTTPException(status_code=404, detail="Invalid or expired form token")

    slots = record.extracted_slots or {}
    missing_keys = [
        k for k in _FIELD_LABELS
        if slots.get(k) is None or slots.get(k) == [] or slots.get(k) == ""
    ]
    return {
        "requirement_id": record.id,
        "farmer_name": record.farmer_name,
        "report_id": f"AGM-{record.id:04d}",
        "missing_fields": [{"field": k, "label": _FIELD_LABELS[k]} for k in missing_keys],
        "current_slots": {k: v for k, v in slots.items() if not k.startswith("_")},
    }


# ─── Farmer: Fill Missing Data ────────────────────────────────────────────────

@router.patch("/requirements/{req_id}/fill-missing", response_model=FillMissingResponse)
async def fill_missing_data(req_id: int, req: FillMissingRequest, db: Session = Depends(get_db)):
    record = db.query(FarmerRequirement).filter(FarmerRequirement.id == req_id).first()
    if not record:
        raise HTTPException(status_code=404, detail="Requirement not found")
    if record.follow_up_token != req.token:
        raise HTTPException(status_code=403, detail="Invalid token")

    slots = dict(record.extracted_slots or {})
    updated_fields = []

    for key, value in req.filled_data.items():
        if key in _FIELD_LABELS and value is not None and value != "":
            slots[key] = value
            if hasattr(record, key):
                try:
                    setattr(record, key, value)
                except Exception:
                    pass
            updated_fields.append(key)

    record.extracted_slots = slots
    record.follow_up_filled_at = datetime.now(timezone.utc)
    record.updated_at = datetime.now(timezone.utc)

    # Regenerate PDF with updated data
    try:
        conflicts, feasibility_score, feasibility_details = conflict_detector.analyze(slots)
        record.conflicts = conflicts
        record.feasibility_score = feasibility_score
        record.feasibility_details = feasibility_details
        pdf_path = generate_report(
            requirement_id=record.id,
            farmer_name=record.farmer_name or "Farmer",
            farmer_phone=record.farmer_phone,
            slots={**slots, "_language": record.language or "english"},
            conflicts=conflicts,
            feasibility_score=feasibility_score,
            feasibility_details=feasibility_details,
            status=record.status or "pending",
        )
        record.pdf_path = pdf_path
        record.pdf_version = (record.pdf_version or 1) + 1
    except Exception as e:
        print(f"PDF regeneration error (non-fatal): {e}")

    db.commit()
    return FillMissingResponse(
        success=True,
        requirement_id=req_id,
        updated_fields=updated_fields,
        message=f"Thank you! {len(updated_fields)} field(s) updated. Your updated report is ready.",
    )


# ─── Admin: Regenerate PDF ────────────────────────────────────────────────────

@router.post("/requirements/{req_id}/regenerate-pdf")
def regenerate_pdf(req_id: int, db: Session = Depends(get_db)):
    record = db.query(FarmerRequirement).filter(FarmerRequirement.id == req_id).first()
    if not record:
        raise HTTPException(status_code=404, detail="Requirement not found")

    slots = record.extracted_slots or {}
    conflicts, feasibility_score, feasibility_details = conflict_detector.analyze(slots)

    try:
        pdf_path = generate_report(
            requirement_id=record.id,
            farmer_name=record.farmer_name or "Farmer",
            farmer_phone=record.farmer_phone,
            slots={**slots, "_language": record.language or "english"},
            conflicts=conflicts,
            feasibility_score=feasibility_score,
            feasibility_details=feasibility_details,
            status=record.status or "pending",
        )
        record.pdf_path = pdf_path
        record.pdf_version = (record.pdf_version or 1) + 1
        record.conflicts = conflicts
        record.feasibility_score = feasibility_score
        record.updated_at = datetime.now(timezone.utc)
        db.commit()
        return {"success": True, "pdf_version": record.pdf_version, "message": "PDF regenerated."}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"PDF regeneration failed: {str(e)}")


# ─── Stats ────────────────────────────────────────────────────────────────────

@router.get("/stats")
def get_stats(db: Session = Depends(get_db)):
    total = db.query(FarmerRequirement).count()
    pending = db.query(FarmerRequirement).filter(FarmerRequirement.status == "pending").count()
    feasible = db.query(FarmerRequirement).filter(FarmerRequirement.status == "feasible").count()
    quoted = db.query(FarmerRequirement).filter(FarmerRequirement.status == "quoted").count()
    under_review = db.query(FarmerRequirement).filter(FarmerRequirement.status == "under_review").count()
    scores = [r.feasibility_score for r in db.query(FarmerRequirement).all() if r.feasibility_score]
    avg_score = round(sum(scores) / len(scores), 1) if scores else 0
    return {
        "total_requirements": total,
        "pending": pending,
        "under_review": under_review,
        "feasible": feasible,
        "quoted": quoted,
        "avg_feasibility_score": avg_score,
    }
