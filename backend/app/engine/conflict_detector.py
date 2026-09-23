"""
AgriMind - Agricultural Engineering Conflict Detector
Domain-specific rules for irrigation system feasibility analysis.

Rules cover:
1. Motor HP vs Acreage + Borewell Total Dynamic Head (TDH)
2. Water discharge vs crop water requirement
3. Soil infiltration rate vs emitter discharge
4. Power hours vs irrigation cycle coverage
5. Budget vs system cost estimation
"""
from __future__ import annotations

import math
from typing import Any, Dict, List, Optional, Tuple


# ─── Agricultural Engineering Constants ──────────────────────────────────────

# Crop water requirement (litres per acre per day) during peak season
CROP_WATER_REQ_LPD = {
    "Sugarcane": 38000,
    "Banana": 28000,
    "Coconut": 12000,
    "Paddy": 60000,
    "Turmeric": 18000,
    "Ginger": 16000,
    "Tomato": 22000,
    "Onion": 14000,
    "Chilli": 16000,
    "Cotton": 20000,
    "Maize": 18000,
    "Groundnut": 14000,
    "Vegetables": 20000,
    "Mango": 10000,
    "Flowers": 12000,
    "Default": 20000,
}

# System flow rate requirement: litres per hour per acre
SYSTEM_LPH_PER_ACRE = {
    "Drip": 800,          # Drip: ~800 LPH/acre at 6-8 hr operation
    "Sprinkler": 1200,    # Sprinkler: higher application rate
    "Micro Sprinkler": 900,
    "Flood": 3000,        # Flood: very high volume
    "Furrow": 2000,
    "Overhead": 1500,
    "Default": 1200,
}

# Pump output (LPH) per HP at various total dynamic heads
# TDH buckets: 0-150 ft, 151-300 ft, 301-450 ft, 451-600 ft
PUMP_LPH_PER_HP = {
    (0, 150): 1800,
    (151, 300): 1400,
    (301, 450): 1000,
    (451, 600): 700,
    (601, 1000): 450,
}

# Minimum recommended HP per acre for various crops
MIN_HP_PER_ACRE = {
    "Sugarcane": 0.8,
    "Paddy": 0.5,
    "Banana": 0.6,
    "Coconut": 0.3,
    "Default": 0.5,
}

# Approximate system installation cost per acre (INR)
SYSTEM_COST_PER_ACRE = {
    "Drip": 35000,
    "Sprinkler": 28000,
    "Micro Sprinkler": 32000,
    "Flood": 8000,
    "Furrow": 6000,
    "Overhead": 40000,
    "Default": 30000,
}


# ─── Conflict Detector ────────────────────────────────────────────────────────

class ConflictDetector:

    def analyze(self, slots: Dict[str, Any]) -> Tuple[List[Dict], float, Dict]:
        """
        Analyze extracted slots for engineering conflicts.

        Returns:
            conflicts: list of conflict dicts with type, severity, message, recommendation
            feasibility_score: 0-100
            feasibility_details: dict with component analysis
        """
        conflicts: List[Dict] = []
        details: Dict[str, str] = {}
        score_components: List[float] = []

        land_size = slots.get("land_size")
        crop_types = slots.get("crop_types") or []
        water_source = slots.get("water_source")
        borewell_depth = slots.get("borewell_depth_ft")
        open_well_depth = slots.get("open_well_depth_ft")
        motor_hp = slots.get("motor_hp")
        power_phase = slots.get("power_supply_phase")
        power_hours = slots.get("power_hours_per_day")
        irrigation_type = slots.get("irrigation_type", "Default")
        soil_type = slots.get("soil_type")
        budget = slots.get("budget_inr")

        # Determine primary crop
        primary_crop = crop_types[0] if crop_types else "Default"
        crop_water_req = CROP_WATER_REQ_LPD.get(primary_crop, CROP_WATER_REQ_LPD["Default"])
        irrigation_key = irrigation_type if irrigation_type in SYSTEM_LPH_PER_ACRE else "Default"

        # ── Rule 1: Motor HP vs Acreage + Borewell TDH ────────────────────────
        if land_size and motor_hp:
            min_hp = (MIN_HP_PER_ACRE.get(primary_crop, 0.5)) * land_size

            # Calculate Total Dynamic Head (TDH)
            depth = borewell_depth or open_well_depth or 0
            elevation_head = 10  # Assumed field delivery head (ft)
            friction_loss = depth * 0.05  # ~5% friction in pipes
            tdh = depth + elevation_head + friction_loss

            # Pump output at this TDH
            pump_lph = self._get_pump_lph_per_hp(tdh) * motor_hp
            required_lph = SYSTEM_LPH_PER_ACRE[irrigation_key] * land_size

            hp_score = 100.0
            if motor_hp < min_hp * 0.8:
                rec_hp = math.ceil(min_hp * 1.2 / 0.5) * 0.5  # Round up to nearest 0.5 HP
                severity = "high" if motor_hp < min_hp * 0.6 else "medium"
                conflicts.append({
                    "type": "motor_undersized",
                    "severity": severity,
                    "message": f"{motor_hp} HP motor is insufficient for {land_size} acres of {primary_crop}. "
                               f"Minimum recommended: {min_hp:.1f} HP (TDH: {tdh:.0f} ft).",
                    "recommendation": f"Upgrade to at least {rec_hp} HP submersible pump. "
                                      f"Consider zoning into {math.ceil(land_size/3)} zones if budget is constrained."
                })
                hp_score = 30.0
            elif pump_lph < required_lph * 0.9:
                deficit_pct = ((required_lph - pump_lph) / required_lph) * 100
                conflicts.append({
                    "type": "pump_flow_insufficient",
                    "severity": "medium",
                    "message": f"Pump output (~{pump_lph:.0f} LPH) is {deficit_pct:.0f}% below the {required_lph:.0f} LPH "
                               f"required for {land_size} acres {irrigation_key} of {primary_crop}.",
                    "recommendation": f"Extend daily irrigation hours or divide field into zones for sequential irrigation."
                })
                hp_score = 60.0
            else:
                details["motor_adequacy"] = f"Adequate ({motor_hp} HP, pump output ~{pump_lph:.0f} LPH)"
                hp_score = 100.0

            if not any(c["type"] in ["motor_undersized", "pump_flow_insufficient"] for c in conflicts):
                details.setdefault("motor_adequacy", f"Adequate")

            score_components.append(hp_score * 0.35)  # 35% weight

        # ── Rule 2: Power Hours vs Irrigation Cycle Coverage ──────────────────
        if land_size and power_hours and motor_hp:
            required_lph = SYSTEM_LPH_PER_ACRE[irrigation_key] * land_size
            daily_volume_required = (crop_water_req * land_size)  # total litres/day
            pump_lph_approx = self._get_pump_lph_per_hp(
                (borewell_depth or open_well_depth or 50) + 20
            ) * motor_hp
            hours_needed = daily_volume_required / pump_lph_approx if pump_lph_approx > 0 else 999

            power_score = 100.0
            if power_hours < hours_needed * 0.75:
                conflicts.append({
                    "type": "power_hours_insufficient",
                    "severity": "medium",
                    "message": f"Only {power_hours}h/day power is insufficient. "
                               f"{hours_needed:.1f}h/day is needed to irrigate {land_size} acres of {primary_crop}.",
                    "recommendation": f"Apply for extended TANGEDCO agricultural supply (Night scheme), "
                                      f"use solar pump for supplemental hours, or reduce irrigation frequency."
                })
                power_score = 50.0
            else:
                details["power_coverage"] = f"Sufficient ({power_hours}h/day available, {hours_needed:.1f}h needed)"
                power_score = 100.0

            score_components.append(power_score * 0.25)  # 25% weight

        # ── Rule 3: Soil vs Irrigation Type Compatibility ─────────────────────
        soil_score = 85.0
        if soil_type and irrigation_type:
            if soil_type == "Sandy" and irrigation_type == "Flood":
                conflicts.append({
                    "type": "soil_irrigation_mismatch",
                    "severity": "medium",
                    "message": f"Sandy soil has high infiltration rate. Flood irrigation will cause severe water losses.",
                    "recommendation": "Switch to Drip irrigation for 40-60% water savings on sandy soil."
                })
                soil_score = 40.0
            elif soil_type == "Black Cotton" and irrigation_type == "Drip":
                # Black cotton is fine with drip, but warn about clogging
                details["soil_compatibility"] = "Black cotton soil compatible with drip; use disc filter to prevent clogging"
                soil_score = 90.0
            elif soil_type in ["Alluvial Clay", "Clay"] and irrigation_type == "Sprinkler":
                conflicts.append({
                    "type": "waterlogging_risk",
                    "severity": "low",
                    "message": f"Clay/alluvial soil has low permeability. Sprinkler irrigation may cause surface waterlogging.",
                    "recommendation": "Reduce sprinkler application rate or use drip irrigation for better root-zone control."
                })
                soil_score = 65.0
            else:
                details["soil_compatibility"] = f"{soil_type} soil is compatible with {irrigation_type} irrigation"

        score_components.append(soil_score * 0.20)  # 20% weight

        # ── Rule 4: Budget Adequacy ────────────────────────────────────────────
        budget_score = 85.0
        if budget and land_size and irrigation_type:
            cost_per_acre = SYSTEM_COST_PER_ACRE.get(irrigation_type, SYSTEM_COST_PER_ACRE["Default"])
            estimated_cost = cost_per_acre * land_size
            if budget < estimated_cost * 0.7:
                shortfall = estimated_cost - budget
                conflicts.append({
                    "type": "budget_insufficient",
                    "severity": "low",
                    "message": f"Budget of ₹{budget:,.0f} may be insufficient. "
                               f"Estimated cost for {land_size} acres {irrigation_type}: ₹{estimated_cost:,.0f}.",
                    "recommendation": f"Consider PMKSY subsidy (50-90% for small farmers), "
                                      f"Drip/Sprinkler subsidy schemes, or phased implementation over 2 years."
                })
                budget_score = 50.0
            else:
                details["budget_adequacy"] = f"Budget adequate (₹{budget:,.0f} vs estimated ₹{estimated_cost:,.0f})"

        score_components.append(budget_score * 0.20)  # 20% weight

        # ── Water Source Check ─────────────────────────────────────────────────
        if water_source:
            details["water_source"] = f"{water_source} - verified"
            if borewell_depth and borewell_depth > 500:
                conflicts.append({
                    "type": "very_deep_borewell",
                    "severity": "low",
                    "message": f"Borewell depth of {borewell_depth}ft is very high. High power consumption expected.",
                    "recommendation": "Consider energy-efficient solar submersible pump to reduce operating costs."
                })

        # ── Final Score ────────────────────────────────────────────────────────
        if not score_components:
            feasibility_score = 70.0  # Neutral when insufficient data
        else:
            feasibility_score = sum(score_components)
            # Scale to account for partial component coverage
            coverage = len(score_components) / 4.0
            feasibility_score = min(100.0, feasibility_score + (1 - coverage) * 30)

        # Build recommended system description
        if land_size and irrigation_type and motor_hp:
            details["recommended_system"] = self._recommend_system(
                land_size, irrigation_type, motor_hp,
                borewell_depth or open_well_depth or 50, primary_crop
            )

        return conflicts, round(feasibility_score, 1), details

    def _get_pump_lph_per_hp(self, tdh: float) -> float:
        for (low, high), lph in PUMP_LPH_PER_HP.items():
            if low <= tdh <= high:
                return lph
        return 400  # Very deep well

    def _recommend_system(self, land: float, irrigation: str, hp: float, depth: float, crop: str) -> str:
        if irrigation == "Drip":
            if crop in ["Sugarcane", "Banana"]:
                return f"Inline drip with 2 LPH drippers @ 0.6m × 1.5m, {hp} HP submersible, sand filter + disc filter"
            elif crop in ["Coconut", "Mango"]:
                return f"Online drip with 4 LPH button drippers, 2 per tree, {hp} HP pump"
            else:
                return f"Inline drip with 1.6 LPH drippers @ 0.4m × {1.0 if land <= 3 else 1.2}m row spacing"
        elif irrigation == "Sprinkler":
            return f"Mini sprinkler @ 12m × 12m grid, {hp} HP centrifugal/submersible pump"
        elif irrigation == "Micro Sprinkler":
            return f"Micro sprinkler (45 LPH) @ 6m spacing on risers, {hp} HP pump"
        else:
            return f"{irrigation} irrigation system, {hp} HP pump for {land} acres"


# Singleton
conflict_detector = ConflictDetector()
