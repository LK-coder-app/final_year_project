"""
AgriMind - Pydantic Request/Response Schemas
"""
from __future__ import annotations

from datetime import datetime
from typing import Any, Dict, List, Optional

from pydantic import BaseModel, Field


class ChatRequest(BaseModel):
    session_id: str = Field(..., description="Unique session identifier")
    message: str = Field(..., description="User message in Tamil, English, or Tanglish")
    language: Optional[str] = Field("auto", description="Language hint")
    llm_provider: Optional[str] = Field("local", description="LLM provider")

class ChatResponse(BaseModel):
    session_id: str
    reply: str
    language_detected: str
    extracted_slots: Dict[str, Any]
    missing_slots: List[str]
    conflicts: List[Dict[str, Any]]
    completion_pct: float
    is_complete: bool
    next_question: Optional[str] = None
    turn_index: int

class RequirementSubmitRequest(BaseModel):
    session_id: str
    farmer_name: str
    farmer_phone: Optional[str] = None
    confirm: bool = True

class SlotData(BaseModel):
    land_size: Optional[float] = None
    land_unit: Optional[str] = None
    crop_types: Optional[List[str]] = None
    soil_type: Optional[str] = None
    water_source: Optional[str] = None
    borewell_depth_ft: Optional[float] = None
    open_well_depth_ft: Optional[float] = None
    water_discharge_lph: Optional[float] = None
    motor_hp: Optional[float] = None
    power_supply_phase: Optional[str] = None
    power_hours_per_day: Optional[float] = None
    irrigation_type: Optional[str] = None
    district: Optional[str] = None
    budget_inr: Optional[float] = None

class ConflictDetail(BaseModel):
    type: str
    severity: str
    message: str
    recommendation: str

class FeasibilityDetails(BaseModel):
    motor_adequacy: str
    water_sufficiency: str
    power_coverage: str
    recommended_system: str

class RequirementResponse(BaseModel):
    id: int
    session_id: str
    farmer_name: Optional[str] = None
    farmer_phone: Optional[str] = None
    district: Optional[str] = None
    language: Optional[str] = None
    land_size: Optional[float] = None
    land_unit: Optional[str] = None
    crop_types: Optional[List[str]] = None
    soil_type: Optional[str] = None
    water_source: Optional[str] = None
    borewell_depth_ft: Optional[float] = None
    open_well_depth_ft: Optional[float] = None
    motor_hp: Optional[float] = None
    power_supply_phase: Optional[str] = None
    power_hours_per_day: Optional[float] = None
    irrigation_type: Optional[str] = None
    budget_inr: Optional[float] = None
    conflicts: Optional[List[Dict[str, Any]]] = None
    feasibility_score: Optional[float] = None
    feasibility_details: Optional[Dict[str, Any]] = None
    status: Optional[str] = None
    pdf_version: Optional[int] = 1
    missing_fields: Optional[List[Any]] = None
    llm_analysis_text: Optional[str] = None
    follow_up_token: Optional[str] = None
    follow_up_filled_at: Optional[datetime] = None
    created_at: Optional[datetime] = None
    submitted_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None

    class Config:
        from_attributes = True

class RequirementListResponse(BaseModel):
    total: int
    items: List[RequirementResponse]

class StatusUpdateRequest(BaseModel):
    status: str
    company_notes: Optional[str] = None

class SubmitResponse(BaseModel):
    success: bool
    requirement_id: int
    session_id: str
    message: str
    feasibility_score: float
    conflicts_count: int
    pdf_available: bool

class LLMConfigRequest(BaseModel):
    provider: str
    api_key: Optional[str] = None
    model: Optional[str] = None

class AnalysisResponse(BaseModel):
    requirement_id: int
    present_fields: List[Dict[str, Any]]
    missing_required: List[Dict[str, Any]]
    missing_optional: List[Dict[str, Any]]
    warnings: List[Dict[str, Any]]
    analysis_text: str

class RequestMissingResponse(BaseModel):
    success: bool
    requirement_id: int
    follow_up_token: str
    form_url: str
    missing_fields: List[Dict[str, Any]]
    sms_sent: bool
    message: str

class FillMissingRequest(BaseModel):
    token: str
    filled_data: Dict[str, Any]

class FillMissingResponse(BaseModel):
    success: bool
    requirement_id: int
    updated_fields: List[str]
    message: str
