"""
AgriMind - PDF/Requirement LLM Analyzer
Used by the Admin Dashboard to check submitted requirements for missing fields,
conflicts, and data quality issues using Gemini AI.
"""
from __future__ import annotations

import os
import json
import re
import logging
from typing import Any, Dict, List, Optional

import httpx

logger = logging.getLogger(__name__)

REQUIRED_FIELD_LABELS = {
    "land_size": "Land Size (area of farm)",
    "land_unit": "Land Unit (acres/hectares/cents)",
    "crop_types": "Crop Types (what is being grown)",
    "water_source": "Water Source (borewell/open well/canal etc)",
    "motor_hp": "Motor Horsepower (HP rating)",
    "irrigation_type": "Irrigation Type (drip/sprinkler etc)",
}

OPTIONAL_FIELD_LABELS = {
    "soil_type": "Soil Type",
    "borewell_depth_ft": "Borewell Depth (feet)",
    "open_well_depth_ft": "Open Well Depth (feet)",
    "power_supply_phase": "Power Phase (single/three phase)",
    "power_hours_per_day": "Power Hours per Day",
    "district": "District (location)",
    "budget_inr": "Budget (INR)",
}

ALL_FIELD_LABELS = {**REQUIRED_FIELD_LABELS, **OPTIONAL_FIELD_LABELS}


async def analyze_requirement(
    slots: Dict[str, Any],
    conflicts: List[Dict],
    farmer_name: str,
    gemini_api_key: str = "",
    gemini_model: str = "gemini-1.5-flash",
) -> Dict[str, Any]:
    """
    Analyze a farmer requirement submission for missing fields and issues.
    Returns: {present_fields, missing_required, missing_optional, warnings, analysis_text}
    """
    # Always do a rule-based check first
    rule_result = _rule_based_check(slots, conflicts, farmer_name)

    # Try LLM enhancement
    if gemini_api_key and gemini_api_key not in ("your_gemini_api_key_here", ""):
        try:
            llm_text = await _gemini_analyze(slots, conflicts, farmer_name, gemini_api_key, gemini_model)
            rule_result["analysis_text"] = llm_text
        except Exception as e:
            logger.warning(f"LLM analysis failed, using rule-based: {e}")

    return rule_result


def _rule_based_check(slots: Dict[str, Any], conflicts: List[Dict], farmer_name: str) -> Dict[str, Any]:
    """Deterministic field presence check."""
    missing_required = []
    missing_optional = []
    present_fields = []

    for key, label in REQUIRED_FIELD_LABELS.items():
        val = slots.get(key)
        if val is None or val == "" or val == []:
            missing_required.append({"field": key, "label": label})
        else:
            present_fields.append({"field": key, "label": label, "value": val})

    for key, label in OPTIONAL_FIELD_LABELS.items():
        val = slots.get(key)
        if val is None or val == "":
            missing_optional.append({"field": key, "label": label})
        else:
            present_fields.append({"field": key, "label": label, "value": val})

    warnings = []
    for c in conflicts:
        warnings.append({
            "type": c.get("type", ""),
            "severity": c.get("severity", "medium"),
            "message": c.get("message", ""),
            "recommendation": c.get("recommendation", ""),
        })

    analysis_text = _build_analysis_text(present_fields, missing_required, missing_optional, warnings, farmer_name)

    return {
        "present_fields": present_fields,
        "missing_required": missing_required,
        "missing_optional": missing_optional,
        "warnings": warnings,
        "analysis_text": analysis_text,
    }


def _build_analysis_text(present_fields, missing_required, missing_optional, warnings, farmer_name) -> str:
    lines = [f"## Requirement Analysis for {farmer_name}", ""]

    if not missing_required:
        lines.append("All required fields are present.")
    else:
        lines.append(f"{len(missing_required)} required field(s) missing:")
        for f in missing_required:
            lines.append(f"  - MISSING: {f['label']}")

    lines.append("")
    if missing_optional:
        lines.append(f"{len(missing_optional)} optional field(s) not provided:")
        for f in missing_optional:
            lines.append(f"  - Optional: {f['label']}")
    else:
        lines.append("All optional fields provided.")

    lines.append("")
    if warnings:
        lines.append(f"{len(warnings)} engineering conflict(s) detected:")
        for w in warnings:
            lines.append(f"  - [{w['severity'].upper()}] {w['message']}")
            lines.append(f"    Recommendation: {w['recommendation']}")
    else:
        lines.append("No engineering conflicts detected.")

    return "\n".join(lines)


async def _gemini_analyze(
    slots: Dict[str, Any],
    conflicts: List[Dict],
    farmer_name: str,
    gemini_api_key: str,
    gemini_model: str,
) -> str:
    """Call Gemini to generate a detailed narrative analysis."""
    slot_summary = {k: v for k, v in slots.items() if not k.startswith("_") and v is not None}
    prompt = (
        f"You are an agricultural infrastructure expert reviewing a farmer requirement submission.\n\n"
        f"Farmer: {farmer_name}\n\n"
        f"Submitted Data:\n{json.dumps(slot_summary, indent=2, default=str)}\n\n"
        f"Engineering Conflicts:\n{json.dumps(conflicts, indent=2)}\n\n"
        f"Please analyze this submission in 3-5 professional sentences. Comment on data completeness, "
        f"any engineering concerns, and whether it is ready for quotation."
    )

    url = f"https://generativelanguage.googleapis.com/v1beta/models/{gemini_model}:generateContent"
    payload = {
        "contents": [{"parts": [{"text": prompt}]}],
        "generationConfig": {"temperature": 0.3, "maxOutputTokens": 512},
    }
    async with httpx.AsyncClient(timeout=30) as client:
        resp = await client.post(url, params={"key": gemini_api_key}, json=payload)
        resp.raise_for_status()
        data = resp.json()
        return data["candidates"][0]["content"]["parts"][0]["text"]
