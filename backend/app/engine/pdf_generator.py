"""
AgriMind - PDF Requirement Report Generator
Generates publication-quality Agricultural Infrastructure Requirement Reports
using ReportLab.
"""
from __future__ import annotations

import os
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional

from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER, TA_LEFT, TA_RIGHT
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import cm, mm
from reportlab.platypus import (
    HRFlowable, Image, PageBreak, Paragraph, SimpleDocTemplate,
    Spacer, Table, TableStyle,
)

# ─── Brand Colors ─────────────────────────────────────────────────────────────
EMERALD = colors.HexColor("#064e3b")
JADE = colors.HexColor("#10b981")
MINT = colors.HexColor("#d1fae5")
AMBER = colors.HexColor("#d97706")
AMBER_LIGHT = colors.HexColor("#fef3c7")
DANGER = colors.HexColor("#dc2626")
DANGER_LIGHT = colors.HexColor("#fee2e2")
SLATE = colors.HexColor("#1e293b")
SLATE_LIGHT = colors.HexColor("#f8fafc")
GRAY = colors.HexColor("#64748b")
WHITE = colors.white

OUTPUT_DIR = os.path.join(os.path.dirname(__file__), "..", "..", "..", "reports")


def ensure_output_dir():
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    return OUTPUT_DIR


def generate_report(
    requirement_id: int,
    farmer_name: str,
    farmer_phone: Optional[str],
    slots: Dict[str, Any],
    conflicts: List[Dict],
    feasibility_score: float,
    feasibility_details: Dict[str, Any],
    status: str = "pending",
) -> str:
    """
    Generate a PDF report and return the file path.
    """
    out_dir = ensure_output_dir()
    filename = f"agrimind_report_{requirement_id:04d}_{datetime.now(timezone.utc).strftime('%Y%m%d_%H%M%S')}.pdf"
    filepath = os.path.join(out_dir, filename)

    doc = SimpleDocTemplate(
        filepath,
        pagesize=A4,
        rightMargin=1.5 * cm,
        leftMargin=1.5 * cm,
        topMargin=2 * cm,
        bottomMargin=2 * cm,
    )

    styles = getSampleStyleSheet()

    # ── Custom Styles ─────────────────────────────────────────────────────────
    title_style = ParagraphStyle(
        "AgriTitle",
        parent=styles["Title"],
        fontName="Helvetica-Bold",
        fontSize=20,
        textColor=EMERALD,
        spaceAfter=4,
        alignment=TA_CENTER,
    )
    subtitle_style = ParagraphStyle(
        "AgriSubtitle",
        parent=styles["Normal"],
        fontName="Helvetica",
        fontSize=11,
        textColor=GRAY,
        spaceAfter=2,
        alignment=TA_CENTER,
    )
    section_header_style = ParagraphStyle(
        "SectionHeader",
        parent=styles["Heading2"],
        fontName="Helvetica-Bold",
        fontSize=13,
        textColor=WHITE,
        backColor=EMERALD,
        spaceBefore=12,
        spaceAfter=6,
        leftIndent=-5,
        rightIndent=-5,
        leading=20,
    )
    body_style = ParagraphStyle(
        "Body",
        parent=styles["Normal"],
        fontName="Helvetica",
        fontSize=10,
        textColor=SLATE,
        spaceAfter=4,
    )
    bold_body = ParagraphStyle(
        "BoldBody",
        parent=body_style,
        fontName="Helvetica-Bold",
    )
    small_style = ParagraphStyle(
        "Small",
        parent=styles["Normal"],
        fontName="Helvetica",
        fontSize=8,
        textColor=GRAY,
    )
    conflict_style = ParagraphStyle(
        "Conflict",
        parent=body_style,
        textColor=DANGER,
        fontName="Helvetica-Bold",
    )
    ok_style = ParagraphStyle(
        "OK",
        parent=body_style,
        textColor=colors.HexColor("#16a34a"),
        fontName="Helvetica-Bold",
    )

    story = []

    # ══════════════════════════════════════════════════════════════════════════
    # HEADER BLOCK
    # ══════════════════════════════════════════════════════════════════════════
    story.append(Spacer(1, 0.3 * cm))
    story.append(Paragraph("🌿 AgriMind", title_style))
    story.append(Paragraph("AI-Powered Agricultural Infrastructure Requirement Report", subtitle_style))
    story.append(Paragraph("Sri Ramakrishna Engineering College · Dept. of Artificial Intelligence & Data Science", small_style))
    story.append(HRFlowable(width="100%", thickness=2, color=EMERALD, spaceAfter=8))

    # Report metadata table
    now = datetime.now(timezone.utc)
    meta_data = [
        [
            Paragraph(f"<b>Report ID:</b> AGM-{requirement_id:04d}", body_style),
            Paragraph(f"<b>Date:</b> {now.strftime('%d %B %Y')}", body_style),
            Paragraph(f"<b>Status:</b> {status.replace('_', ' ').title()}", body_style),
        ]
    ]
    meta_table = Table(meta_data, colWidths=["34%", "33%", "33%"])
    meta_table.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, -1), MINT),
        ("ROWBACKGROUNDS", (0, 0), (-1, -1), [MINT]),
        ("BOX", (0, 0), (-1, -1), 1, JADE),
        ("INNERGRID", (0, 0), (-1, -1), 0.5, JADE),
        ("TOPPADDING", (0, 0), (-1, -1), 5),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 5),
        ("LEFTPADDING", (0, 0), (-1, -1), 8),
        ("RIGHTPADDING", (0, 0), (-1, -1), 8),
    ]))
    story.append(meta_table)
    # Check for missing required slots and display audit notice if incomplete
    missing_req = []
    if not slots.get("land_size"): missing_req.append("Land Area")
    if not slots.get("crop_types"): missing_req.append("Crop Types")
    if not slots.get("water_source"): missing_req.append("Water Source")
    if not slots.get("motor_hp"): missing_req.append("Motor HP")
    if not slots.get("irrigation_type"): missing_req.append("Irrigation Type")

    if missing_req:
        alert_style = ParagraphStyle(
            "MissingAlert",
            parent=body_style,
            textColor=colors.HexColor("#991b1b"),
            fontSize=9,
            leading=13,
        )
        alert_data = [[
            Paragraph(
                f"<b>⚠️ AUDIT NOTICE: INCOMPLETE DATA HIGHLIGHTED IN PDF</b><br/>"
                f"Missing required specifications: <b>{', '.join(missing_req)}</b>.<br/>"
                f"Highlighted with <font color='#dc2626'><b>⚠️ MISSING</b></font> below. "
                f"Admin can trigger follow-up form request to complete these parameters.",
                alert_style
            )
        ]]
        alert_table = Table(alert_data, colWidths=["100%"])
        alert_table.setStyle(TableStyle([
            ("BACKGROUND", (0, 0), (-1, -1), DANGER_LIGHT),
            ("BOX", (0, 0), (-1, -1), 1.5, DANGER),
            ("TOPPADDING", (0, 0), (-1, -1), 7),
            ("BOTTOMPADDING", (0, 0), (-1, -1), 7),
            ("LEFTPADDING", (0, 0), (-1, -1), 10),
            ("RIGHTPADDING", (0, 0), (-1, -1), 10),
        ]))
        story.append(alert_table)
        story.append(Spacer(1, 0.3 * cm))

    # ══════════════════════════════════════════════════════════════════════════
    # FARMER IDENTITY
    # ══════════════════════════════════════════════════════════════════════════
    story.append(Paragraph("  FARMER PROFILE", section_header_style))
    farmer_rows = [
        ["Farmer Name", farmer_name or "<font color='#dc2626'><b>⚠️ MISSING</b></font>", "Contact", farmer_phone or "<font color='#d97706'>⚠️ Not Specified</font>"],
        ["District", slots.get("district") or "<font color='#d97706'>⚠️ Not Specified</font>", "Language", slots.get("_language", "English").title()],
        ["Session ID", f"AGM-{requirement_id:04d}", "Report Generated", now.strftime("%d/%m/%Y %H:%M UTC")],
    ]
    farmer_table = _make_detail_table(farmer_rows, body_style)
    story.append(farmer_table)
    story.append(Spacer(1, 0.4 * cm))

    # ══════════════════════════════════════════════════════════════════════════
    # FARM & CROP SPECIFICATIONS
    # ══════════════════════════════════════════════════════════════════════════
    story.append(Paragraph("  FARM & CROP SPECIFICATIONS", section_header_style))
    crops_val = slots.get("crop_types")
    crops_str = ", ".join(crops_val) if crops_val else "<font color='#dc2626'><b>⚠️ MISSING (Required)</b></font>"
    land_str = f"{slots.get('land_size')} {slots.get('land_unit', 'acres')}" if slots.get("land_size") else "<font color='#dc2626'><b>⚠️ MISSING (Required)</b></font>"
    soil_str = slots.get("soil_type") or "<font color='#d97706'>⚠️ Not specified</font>"
    irrig_str = slots.get("irrigation_type") or "<font color='#dc2626'><b>⚠️ MISSING (Required)</b></font>"
    budget_str = f"₹{slots.get('budget_inr', 0):,.0f}" if slots.get("budget_inr") else "<font color='#d97706'>⚠️ Not specified</font>"

    farm_rows = [
        ["Land Area", land_str, "Primary Crop(s)", crops_str],
        ["Soil Type", soil_str, "Irrigation Type", irrig_str],
        ["Budget (INR)", budget_str, "", ""],
    ]
    farm_table = _make_detail_table(farm_rows, body_style)
    story.append(farm_table)
    story.append(Spacer(1, 0.4 * cm))

    # ══════════════════════════════════════════════════════════════════════════
    # WATER & POWER INFRASTRUCTURE
    # ══════════════════════════════════════════════════════════════════════════
    story.append(Paragraph("  WATER & POWER INFRASTRUCTURE", section_header_style))
    water_str = slots.get("water_source") or "<font color='#dc2626'><b>⚠️ MISSING (Required)</b></font>"
    bore_depth = slots.get("borewell_depth_ft")
    well_depth = slots.get("open_well_depth_ft")
    depth_str = (
        f"{bore_depth} ft (Borewell)" if bore_depth else
        f"{well_depth} ft (Open Well)" if well_depth else
        "<font color='#d97706'>⚠️ Not specified</font>"
    )
    motor_str = f"{slots.get('motor_hp')} HP" if slots.get("motor_hp") else "<font color='#dc2626'><b>⚠️ MISSING (Required)</b></font>"
    phase_str = slots.get("power_supply_phase") or "<font color='#d97706'>⚠️ Not specified</font>"
    power_hours_str = f"{slots.get('power_hours_per_day')} hours" if slots.get("power_hours_per_day") else "<font color='#d97706'>⚠️ Not specified</font>"
    discharge_str = f"{slots.get('water_discharge_lph')} LPH" if slots.get("water_discharge_lph") else "Est. from HP"

    infra_rows = [
        ["Water Source", water_str, "Depth", depth_str],
        ["Motor HP", motor_str, "Power Phase", phase_str],
        ["Power Hours/Day", power_hours_str, "Discharge", discharge_str],
    ]
    infra_table = _make_detail_table(infra_rows, body_style)
    story.append(infra_table)
    story.append(Spacer(1, 0.4 * cm))

    # ══════════════════════════════════════════════════════════════════════════
    # FEASIBILITY ASSESSMENT
    # ══════════════════════════════════════════════════════════════════════════
    story.append(Paragraph("  ENGINEERING FEASIBILITY ASSESSMENT", section_header_style))

    # Feasibility score bar
    score_color = (
        colors.HexColor("#16a34a") if feasibility_score >= 75 else
        AMBER if feasibility_score >= 50 else
        DANGER
    )
    score_label = (
        "FEASIBLE ✅" if feasibility_score >= 75 else
        "CONDITIONAL ⚠️" if feasibility_score >= 50 else
        "REQUIRES REVIEW ❌"
    )
    score_data = [[
        Paragraph(f"<b>Overall Feasibility Score</b>", body_style),
        Paragraph(f"<b>{feasibility_score:.1f} / 100</b>", ParagraphStyle(
            "Score", parent=body_style,
            textColor=score_color, fontSize=16, alignment=TA_CENTER
        )),
        Paragraph(f"<b>{score_label}</b>", ParagraphStyle(
            "ScoreLabel", parent=body_style,
            textColor=score_color, alignment=TA_RIGHT
        )),
    ]]
    score_table = Table(score_data, colWidths=["40%", "30%", "30%"])
    score_table.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, -1), SLATE_LIGHT),
        ("BOX", (0, 0), (-1, -1), 2, score_color),
        ("TOPPADDING", (0, 0), (-1, -1), 10),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 10),
        ("LEFTPADDING", (0, 0), (-1, -1), 10),
    ]))
    story.append(score_table)
    story.append(Spacer(1, 0.3 * cm))

    # Feasibility detail rows
    if feasibility_details:
        feas_rows = []
        detail_labels = {
            "motor_adequacy": "Motor Adequacy",
            "water_sufficiency": "Water Sufficiency",
            "power_coverage": "Power Coverage",
            "soil_compatibility": "Soil Compatibility",
            "budget_adequacy": "Budget Adequacy",
            "recommended_system": "Recommended System",
            "water_source": "Water Source",
        }
        for key, label in detail_labels.items():
            if key in feasibility_details:
                feas_rows.append([label, feasibility_details[key]])

        if feas_rows:
            feas_table = Table(feas_rows, colWidths=["35%", "65%"])
            feas_table.setStyle(TableStyle([
                ("FONT", (0, 0), (0, -1), "Helvetica-Bold", 9),
                ("FONT", (1, 0), (1, -1), "Helvetica", 9),
                ("TEXTCOLOR", (0, 0), (-1, -1), SLATE),
                ("ROWBACKGROUNDS", (0, 0), (-1, -1), [WHITE, SLATE_LIGHT]),
                ("BOX", (0, 0), (-1, -1), 0.5, JADE),
                ("INNERGRID", (0, 0), (-1, -1), 0.25, colors.HexColor("#e2e8f0")),
                ("TOPPADDING", (0, 0), (-1, -1), 5),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 5),
                ("LEFTPADDING", (0, 0), (-1, -1), 8),
                ("RIGHTPADDING", (0, 0), (-1, -1), 8),
            ]))
            story.append(feas_table)

    story.append(Spacer(1, 0.4 * cm))

    # ══════════════════════════════════════════════════════════════════════════
    # CONFLICT ANALYSIS
    # ══════════════════════════════════════════════════════════════════════════
    story.append(Paragraph("  ENGINEERING CONFLICT ANALYSIS", section_header_style))

    if not conflicts:
        story.append(Paragraph("✅ No engineering conflicts detected. System specifications are coherent.", ok_style))
    else:
        for i, conflict in enumerate(conflicts, 1):
            severity = conflict.get("severity", "medium")
            sev_color = DANGER if severity == "high" else AMBER if severity == "medium" else GRAY
            sev_bg = DANGER_LIGHT if severity == "high" else AMBER_LIGHT if severity == "medium" else SLATE_LIGHT
            conflict_data = [
                [
                    Paragraph(f"<b>#{i} {conflict.get('type', '').replace('_', ' ').upper()}</b>", ParagraphStyle(
                        "ct", parent=body_style, textColor=sev_color, fontSize=10
                    )),
                    Paragraph(f"<b>SEVERITY: {severity.upper()}</b>", ParagraphStyle(
                        "sv", parent=body_style, textColor=sev_color, alignment=TA_RIGHT, fontSize=9
                    )),
                ],
                [Paragraph(f"<b>Issue:</b> {conflict.get('message', '')}", body_style), ""],
                [Paragraph(f"<b>Recommendation:</b> {conflict.get('recommendation', '')}", ParagraphStyle(
                    "rec", parent=body_style, textColor=colors.HexColor("#065f46")
                )), ""],
            ]
            conflict_table = Table(conflict_data, colWidths=["70%", "30%"])
            conflict_table.setStyle(TableStyle([
                ("BACKGROUND", (0, 0), (-1, 0), sev_bg),
                ("BOX", (0, 0), (-1, -1), 1, sev_color),
                ("INNERGRID", (0, 0), (-1, -1), 0.25, colors.HexColor("#e2e8f0")),
                ("SPAN", (0, 1), (1, 1)),
                ("SPAN", (0, 2), (1, 2)),
                ("TOPPADDING", (0, 0), (-1, -1), 6),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 6),
                ("LEFTPADDING", (0, 0), (-1, -1), 8),
                ("RIGHTPADDING", (0, 0), (-1, -1), 8),
            ]))
            story.append(conflict_table)
            story.append(Spacer(1, 0.25 * cm))

    story.append(Spacer(1, 0.4 * cm))

    # ══════════════════════════════════════════════════════════════════════════
    # FOOTER & SIGNATURE BLOCK
    # ══════════════════════════════════════════════════════════════════════════
    story.append(HRFlowable(width="100%", thickness=1, color=JADE, spaceAfter=8))
    footer_data = [[
        Paragraph("<b>Farmer Signature / Confirmation:</b>\n\n\n_______________________", body_style),
        Paragraph("<b>Company Engineer Signature:</b>\n\n\n_______________________", body_style),
        Paragraph(
            f"<b>AgriMind System</b><br/>Report AGM-{requirement_id:04d}<br/>"
            f"Generated: {now.strftime('%d/%m/%Y')}<br/>"
            "<i>Powered by AI · SREC ADS Dept.</i>",
            small_style
        ),
    ]]
    footer_table = Table(footer_data, colWidths=["35%", "35%", "30%"])
    footer_table.setStyle(TableStyle([
        ("TOPPADDING", (0, 0), (-1, -1), 10),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 10),
        ("LEFTPADDING", (0, 0), (-1, -1), 5),
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
    ]))
    story.append(footer_table)
    story.append(Spacer(1, 0.3 * cm))
    story.append(Paragraph(
        "This report is generated by AgriMind AI System. For validation, contact your authorised agricultural infrastructure provider. "
        "Government subsidy schemes (PMKSY, TNAU drip subsidy) may apply. All recommendations are advisory.",
        small_style,
    ))

    doc.build(story)
    return filepath


# ─── Helper ──────────────────────────────────────────────────────────────────

def _make_detail_table(rows: List[List], body_style: ParagraphStyle) -> Table:
    """Build a styled 4-column label-value table with cell highlights for missing fields."""
    formatted_rows = []
    cell_styles = [
        ("ROWBACKGROUNDS", (0, 0), (-1, -1), [MINT, WHITE]),
        ("BOX", (0, 0), (-1, -1), 0.5, JADE),
        ("INNERGRID", (0, 0), (-1, -1), 0.25, colors.HexColor("#d1fae5")),
        ("TOPPADDING", (0, 0), (-1, -1), 5),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 5),
        ("LEFTPADDING", (0, 0), (-1, -1), 8),
        ("RIGHTPADDING", (0, 0), (-1, -1), 8),
        ("TEXTCOLOR", (0, 0), (-1, -1), SLATE),
        ("FONTNAME", (0, 0), (0, -1), "Helvetica-Bold"),
        ("FONTNAME", (2, 0), (2, -1), "Helvetica-Bold"),
    ]
    for r_idx, row in enumerate(rows):
        formatted = []
        for c_idx, cell in enumerate(row):
            if not cell:
                formatted.append("")
            elif c_idx % 2 == 0:  # Label column
                formatted.append(Paragraph(f"<b>{cell}</b>", body_style))
            else:  # Value column
                cell_str = str(cell)
                formatted.append(Paragraph(cell_str, body_style))
                if "MISSING" in cell_str:
                    cell_styles.append(("BACKGROUND", (c_idx, r_idx), (c_idx, r_idx), DANGER_LIGHT))
        formatted_rows.append(formatted)

    table = Table(formatted_rows, colWidths=["22%", "28%", "22%", "28%"])
    table.setStyle(TableStyle(cell_styles))
    return table
