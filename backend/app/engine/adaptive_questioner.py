"""
AgriMind - Adaptive Question Generator
Generates natural, context-aware follow-up questions in Tamil and English
to guide farmers through completing their requirement specification.
"""
from __future__ import annotations

import os
import random
from typing import Any, Dict, List, Optional
import httpx
import logging

logger = logging.getLogger(__name__)


# ─── Question Templates ───────────────────────────────────────────────────────

SLOT_QUESTIONS = {
    "land_size": {
        "english": [
            "How many acres of farmland do you have?",
            "What is the total size of your farm? (in acres or hectares)",
            "Could you tell me the area of your agricultural land?",
        ],
        "tamil": [
            "உங்கள் நிலம் எத்தனை ஏக்கர் இருக்கிறது?",
            "உங்கள் விவசாய நிலத்தின் அளவு என்ன?",
            "நிலத்தின் பரப்பளவு கூறுங்கள் (ஏக்கர் அல்லது ஹெக்டேரில்)",
        ],
        "tanglish": [
            "Ungal nilam evvalavu acre irukku?",
            "Farm size enna? Acres la sollunga.",
        ],
    },
    "crop_types": {
        "english": [
            "What crops are you planning to grow or currently growing?",
            "Which crops will be irrigated? (e.g., sugarcane, banana, paddy)",
            "What is the primary crop on your farm?",
        ],
        "tamil": [
            "நீங்கள் என்ன பயிர் போட உள்ளீர்கள்?",
            "உங்கள் நிலத்தில் என்ன பயிர் வளர்க்கிறீர்கள்?",
            "முக்கிய பயிர் என்ன? (கரும்பு, வாழை, நெல் போன்றவை)",
        ],
        "tanglish": [
            "Enna payir poduvinga? Sugarcane-a, banana-va?",
            "Ungal farm la enna grow panuvinga?",
        ],
    },
    "water_source": {
        "english": [
            "What is your water source? (Borewell, Open Well, Canal, River?)",
            "How do you currently get water for irrigation?",
            "Is there a borewell or open well on your farm?",
        ],
        "tamil": [
            "தண்ணீர் எங்கிருந்து வருகிறது? (போர்வெல், கிணறு, கால்வாய்?)",
            "உங்கள் நீர் ஆதாரம் என்ன?",
            "போர்வெல் இருக்கிறதா, கிணறு இருக்கிறதா?",
        ],
        "tanglish": [
            "Thanni source enna? Borewell-a, open well-a, canal-a?",
            "Irrigation ku thanni enga irundhu varuthu?",
        ],
    },
    "borewell_depth_ft": {
        "english": [
            "How deep is your borewell? (in feet)",
            "What is the depth of your borewell? This is important for selecting the right pump.",
            "Could you share the borewell depth so we can size the motor correctly?",
        ],
        "tamil": [
            "போர்வெல் எத்தனை அடி ஆழம்?",
            "உங்கள் போர்வெல்லின் ஆழம் என்ன? (அடியில்)",
            "போர்வெல் ஆழம் தெரியுமா? சரியான மோட்டார் தேர்வுக்கு இது முக்கியம்.",
        ],
        "tanglish": [
            "Borewell evvalavu feet depth irukku?",
            "Bore depth enna? Motor size ku theriyanum.",
        ],
    },
    "motor_hp": {
        "english": [
            "What is the horsepower (HP) of your existing pump motor?",
            "Do you have an existing motor? If yes, what is its HP rating?",
            "What HP motor do you currently use for irrigation?",
        ],
        "tamil": [
            "உங்கள் மோட்டாரின் ஹார்ஸ்பவர் (HP) என்ன?",
            "இப்போது என்ன HP மோட்டார் பயன்படுத்துகிறீர்கள்?",
            "ஏற்கனவே மோட்டார் இருக்கிறதா? அதன் HP என்ன?",
        ],
        "tanglish": [
            "Motor HP evvalavu? 2 HP-a, 3 HP-a, 5 HP-a?",
            "Existing motor iruka? HP enna?",
        ],
    },
    "irrigation_type": {
        "english": [
            "What type of irrigation system are you looking for? (Drip, Sprinkler, Flood?)",
            "Have you decided on the irrigation method? Drip irrigation saves up to 60% water.",
            "Which irrigation system do you prefer for your crops?",
        ],
        "tamil": [
            "என்ன வகை பாசன முறை வேண்டும்? (சொட்டு நீர், தெளிப்பான், வெள்ளம்?)",
            "சொட்டு நீர் பாசனம் தேவையா, தெளிப்பான் முறை தேவையா?",
            "நீங்கள் விரும்பும் பாசன முறை என்ன?",
        ],
        "tanglish": [
            "Evvazhai irrigation type venum? Drip-a, sprinkler-a?",
            "Drip system venum-a illa sprinkler venum-a?",
        ],
    },
    "soil_type": {
        "english": [
            "What type of soil is on your farm? (Red, Black, Sandy, Clay?)",
            "Can you describe the soil on your land? This helps us recommend the right dripper spacing.",
            "Is your soil red/laterite, black cotton, alluvial, or sandy?",
        ],
        "tamil": [
            "உங்கள் நிலத்தில் என்ன வகை மண் உள்ளது? (செம்மண், கருப்பு மண், மணல்?)",
            "மண் வகை என்ன? சொட்டு நீர் இடைவெளி தீர்மானிக்க இது உதவும்.",
        ],
        "tanglish": [
            "Soil type enna? Red soil-a, black soil-a, sandy-a?",
        ],
    },
    "power_hours_per_day": {
        "english": [
            "How many hours of electricity do you get per day for agricultural use?",
            "What is the daily power supply duration for your farm? (in hours)",
        ],
        "tamil": [
            "நாளொன்றுக்கு எத்தனை மணி நேரம் மின்சாரம் கிடைக்கிறது?",
            "விவசாய மின்சார ஆட்டம் ஒரு நாளில் எத்தனை மணி நேரம்?",
        ],
        "tanglish": [
            "Naala evvalavu manam current varuthu? Agriculture supply.",
        ],
    },
    "power_supply_phase": {
        "english": [
            "Is your power supply Single Phase or Three Phase?",
            "What type of electrical connection do you have? (1-phase or 3-phase)",
        ],
        "tamil": [
            "உங்கள் மின் இணைப்பு ஒற்றை கட்டமா (Single Phase) அல்லது மூன்று கட்டமா (Three Phase)?",
        ],
        "tanglish": [
            "Single phase connection-a, three phase-a?",
        ],
    },
    "district": {
        "english": [
            "Which district is your farm located in?",
            "What is the district/location of your farmland?",
        ],
        "tamil": [
            "உங்கள் நிலம் எந்த மாவட்டத்தில் உள்ளது?",
        ],
        "tanglish": [
            "Farm enga district la irukku?",
        ],
    },
    "budget_inr": {
        "english": [
            "What is your approximate budget for the irrigation system? (in ₹)",
            "Could you share your budget so we can suggest the most suitable system?",
        ],
        "tamil": [
            "பாசன அமைப்புக்கு உங்கள் தோராயமான பட்ஜெட் என்ன?",
            "எவ்வளவு பணம் செலவு செய்ய தயாராக இருக்கிறீர்கள்?",
        ],
        "tanglish": [
            "Budget evvalavu? Approximate ku sollunga.",
        ],
    },
}

# Conflict explanation templates
CONFLICT_EXPLANATIONS = {
    "motor_undersized": {
        "english": "⚠️ There seems to be a mismatch between your motor HP and farm size. {message} {recommendation}",
        "tamil": "⚠️ மோட்டார் சக்தி மற்றும் நிலத்தின் அளவுக்கிடையே ஒரு பொருத்தமின்மை தெரிகிறது. {recommendation}",
    },
    "pump_flow_insufficient": {
        "english": "⚠️ Your pump may not deliver enough water per hour. {message} {recommendation}",
        "tamil": "⚠️ மோட்டார் போதுமான நீரை வழங்காமல் போகலாம். {recommendation}",
    },
    "power_hours_insufficient": {
        "english": "⚠️ Power availability concern: {message} {recommendation}",
        "tamil": "⚠️ மின்சார கிடைக்கும் நேர பிரச்சினை: {recommendation}",
    },
    "soil_irrigation_mismatch": {
        "english": "⚠️ Soil-irrigation compatibility issue: {message} {recommendation}",
        "tamil": "⚠️ மண் மற்றும் பாசன முறை பொருத்தமின்மை: {recommendation}",
    },
}

# Completion encouragement messages
COMPLETION_MESSAGES = {
    "english": [
        "Great! I have all the details needed to prepare your irrigation requirement report. ✅",
        "Excellent! Your farm details are complete. Let me generate your technical specification now. ✅",
        "Perfect! All required information has been collected. Ready to submit your requirement! ✅",
    ],
    "tamil": [
        "நல்லது! உங்கள் பாசன தேவை அறிக்கை தயாரிக்க தேவையான அனைத்து விவரங்களும் கிடைத்தன. ✅",
        "சரியாக இருக்கிறது! உங்கள் நிலம் பற்றிய விவரங்கள் முழுமையாக உள்ளன. ✅",
    ],
    "tanglish": [
        "Super! Ungal farm details complete agudhu. Report ready panrom! ✅",
    ],
}

# Greeting messages
GREETING_MESSAGES = {
    "english": "👋 Welcome to AgriMind! I'm here to help you specify your farm's irrigation system requirements. Let's start — {first_question}",
    "tamil": "👋 AgriMind-க்கு வரவேற்கிறோம்! உங்கள் பாசன தேவைகளை புரிந்துகொள்ள உதவுகிறேன். {first_question}",
    "tanglish": "👋 AgriMind-ku welcome! Ungal farm irrigation requirements pathi pesuvom. {first_question}",
}


class AdaptiveQuestioner:

    def generate_response(
        self,
        slots: Dict[str, Any],
        missing_required: List[str],
        missing_optional: List[str],
        conflicts: List[Dict],
        language: str,
        is_first_turn: bool = False,
        turn_index: int = 0,
        extracted_this_turn: Optional[Dict] = None,
    ) -> str:
        """
        Generate a natural, context-aware conversational response.
        """
        lang = language if language in ["tamil", "tanglish"] else "english"

        # First turn greeting
        if is_first_turn or turn_index == 0:
            first_q_slot = missing_required[0] if missing_required else None
            first_q = self._pick_question(first_q_slot, lang) if first_q_slot else ""
            return GREETING_MESSAGES[lang].format(first_question=first_q)

        parts = []

        # Acknowledge what was understood this turn
        if extracted_this_turn:
            ack = self._build_acknowledgement(extracted_this_turn, lang)
            if ack:
                parts.append(ack)

        # Surface conflict warnings (friendly tone)
        if conflicts:
            for conflict in conflicts[:2]:  # Max 2 warnings at once
                c_type = conflict.get("type", "")
                template = CONFLICT_EXPLANATIONS.get(c_type, {})
                if template:
                    msg = template.get(lang, template.get("english", ""))
                    if msg:
                        parts.append(msg.format(
                            message=conflict.get("message", ""),
                            recommendation=conflict.get("recommendation", "")
                        ))

        # All complete → celebration message
        if not missing_required:
            parts.append(random.choice(COMPLETION_MESSAGES.get(lang, COMPLETION_MESSAGES["english"])))
            return " ".join(parts)

        # Ask for next missing required slot
        next_slot = missing_required[0]
        question = self._pick_question(next_slot, lang)
        parts.append(question)

        # Occasionally ask an optional slot too (if only 1-2 required remaining)
        if len(missing_required) <= 2 and missing_optional:
            next_optional = missing_optional[0]
            optional_q = self._pick_question(next_optional, lang)
            if optional_q:
                parts.append(f"Also, {optional_q}" if lang == "english" else optional_q)

        return " ".join(parts)

    def _pick_question(self, slot: str, lang: str) -> str:
        if slot not in SLOT_QUESTIONS:
            return ""
        options = SLOT_QUESTIONS[slot].get(lang) or SLOT_QUESTIONS[slot].get("english", [])
        return random.choice(options) if options else ""

    def _build_acknowledgement(self, extracted: Dict[str, Any], lang: str) -> str:
        """Build a short acknowledgement of what was understood."""
        parts = []
        if "land_size" in extracted and extracted["land_size"]:
            unit = extracted.get("land_unit", "acres")
            if lang == "tamil":
                parts.append(f"{extracted['land_size']} {unit} நிலம் பதிவு செய்யப்பட்டது.")
            else:
                parts.append(f"Got it — {extracted['land_size']} {unit}.")

        if "crop_types" in extracted and extracted["crop_types"]:
            crops = ", ".join(extracted["crop_types"])
            if lang == "tamil":
                parts.append(f"பயிர்: {crops}.")
            else:
                parts.append(f"Crops: {crops}.")

        if "motor_hp" in extracted and extracted["motor_hp"]:
            if lang == "tamil":
                parts.append(f"{extracted['motor_hp']} HP மோட்டார் குறிப்பிட்டீர்கள்.")
            else:
                parts.append(f"Motor HP: {extracted['motor_hp']} HP noted.")

        if "water_source" in extracted and extracted["water_source"]:
            if lang == "tamil":
                parts.append(f"நீர் ஆதாரம்: {extracted['water_source']}.")
            else:
                parts.append(f"Water source: {extracted['water_source']}.")

        return " ".join(parts)


# Singleton
adaptive_questioner = AdaptiveQuestioner()
