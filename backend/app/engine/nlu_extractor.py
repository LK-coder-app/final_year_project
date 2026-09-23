"""
AgriMind - Multilingual NLU Extractor
Supports Tamil, English, and Tanglish (Tamil-English code-mix).

Strategy:
1. Rule-based pattern matcher (always available, no API key needed)
2. LLM-enhanced extraction (Google Gemini or OpenAI) when configured

The slot schema covers all agricultural requirement parameters needed for
drip/sprinkler/solar pump infrastructure sizing.
"""
from __future__ import annotations

import os
import re
import json
import asyncio
import logging
from difflib import get_close_matches
from typing import Any, Dict, List, Optional, Tuple

import httpx

logger = logging.getLogger(__name__)

# ─── Tanglish Number Word Dictionary ─────────────────────────────────────────

TANGLISH_NUMBERS = {
    # Tamil romanized digit words
    "onnu": 1, "onnu": 1, "onu": 1,
    "rendu": 2, "rentu": 2, "randu": 2,
    "moonu": 3, "munnu": 3, "moon": 3,
    "naalu": 4, "nalu": 4, "naalu": 4,
    "anju": 5, "aindu": 5,
    "aaru": 6, "aru": 6,
    "ezhu": 7, "elu": 7,
    "ettu": 8, "etdu": 8,
    "ombadhu": 9, "ombodu": 9,
    "padhu": 10, "pathu": 10,
    "pannrendu": 12, "pannirandu": 12,
    "pathaindu": 15, "pathinaindu": 15,
    "irupadu": 20, "iruvadhu": 20,
    "muppadhu": 30, "muppadu": 30,
    "narppadhu": 40, "narpadhu": 40,
    "aimppadhu": 50, "ampadhu": 50,
    "aruvadhu": 60,
    "eluvadhu": 70,
    "enbadhu": 80,
    "thonnooru": 90,
    "nooru": 100, "nuru": 100,
    "aayiram": 1000, "ayiram": 1000,
}

# ─── Tamil Agricultural Dictionary ───────────────────────────────────────────

TAMIL_LAND_UNITS = {
    "ஏக்கர்": "acres", "ஏக்கர்கள்": "acres", "ஏக்": "acres",
    "ஹெக்டேர்": "hectares", "ஹெக்": "hectares",
    "சென்ட்": "cents", "சென்ட்கள்": "cents",
    "குழி": "kuzhi", "வேலி": "veli",
    "acre": "acres", "acres": "acres",
    "hectare": "hectares", "hectares": "hectares",
    "cent": "cents", "cents": "cents",
    # Tanglish phonetic
    "ek": "acres", "ekkar": "acres", "ekkarnm": "acres",
    "hek": "hectares", "hektear": "hectares",
}

TAMIL_CROPS = {
    # Tamil script names → English
    "கரும்பு": "Sugarcane", "வாழை": "Banana", "தென்னை": "Coconut",
    "நெல்": "Paddy", "நெல்லு": "Paddy", "அரிசி": "Paddy",
    "மஞ்சள்": "Turmeric", "இஞ்சி": "Ginger", "தக்காளி": "Tomato",
    "வெங்காயம்": "Onion", "மிளகாய்": "Chilli", "கத்தரிக்காய்": "Brinjal",
    "பருத்தி": "Cotton", "சோளம்": "Maize", "சோளமொ": "Maize",
    "மாம்பழம்": "Mango", "மா": "Mango", "கொய்யா": "Guava",
    "பப்பாயா": "Papaya", "தர்பூசணி": "Watermelon",
    "நிலக்கடலை": "Groundnut", "சூரியகாந்தி": "Sunflower",
    "காய்கறிகள்": "Vegetables", "காய்கறி": "Vegetables",
    "பூக்கள்": "Flowers", "ரோஜா": "Rose",
    # Tanglish / English common names
    "sugarcane": "Sugarcane", "karumbu": "Sugarcane",
    "banana": "Banana", "vazhai": "Banana", "vaazhai": "Banana",
    "coconut": "Coconut", "thennai": "Coconut",
    "paddy": "Paddy", "rice": "Paddy", "nel": "Paddy", "nellu": "Paddy",
    "turmeric": "Turmeric", "manjal": "Turmeric",
    "ginger": "Ginger", "inji": "Ginger",
    "tomato": "Tomato", "thakkali": "Tomato",
    "onion": "Onion", "vengayam": "Onion",
    "chilli": "Chilli", "milagai": "Chilli",
    "brinjal": "Brinjal", "kathirikkai": "Brinjal",
    "cotton": "Cotton", "parutti": "Cotton",
    "maize": "Maize", "corn": "Maize", "cholam": "Maize",
    "mango": "Mango", "maambalam": "Mango",
    "guava": "Guava", "koyyaa": "Guava",
    "papaya": "Papaya",
    "watermelon": "Watermelon", "tharpusani": "Watermelon",
    "groundnut": "Groundnut", "peanut": "Groundnut", "nilakadalai": "Groundnut",
    "sunflower": "Sunflower",
    "vegetables": "Vegetables", "vegetables": "Vegetables", "kaaikari": "Vegetables",
    "flowers": "Flowers",
}

TAMIL_WATER_SOURCES = {
    "போர்வெல்": "Borewell", "போர்வெல்லு": "Borewell", "போர்": "Borewell",
    "கிணறு": "Open Well", "கிணர்": "Open Well", "ஆழ்துளை": "Borewell",
    "ஆறு": "River", "கால்வாய்": "Canal", "குளம்": "Tank/Pond",
    "மழை": "Rainwater", "தொட்டி": "Storage Tank",
    # English
    "borewell": "Borewell", "bore well": "Borewell", "bore": "Borewell",
    "open well": "Open Well", "well": "Open Well", "openwell": "Open Well",
    "river": "River", "canal": "Canal", "tank": "Tank/Pond", "pond": "Tank/Pond",
    "rainwater": "Rainwater", "rain water": "Rainwater",
    # Tanglish phonetic
    "boruvell": "Borewell", "borevell": "Borewell", "borwel": "Borewell",
    "kinaru": "Open Well", "kinnal": "Open Well", "kinaro": "Open Well",
    "kinaru irukku": "Open Well", "kinnu": "Open Well",
    "kanavai": "Canal", "kalvai": "Canal",
    "kulam": "Tank/Pond", "eri": "Tank/Pond",
    "aaru": "River", "ooru water": "River",
}

TAMIL_IRRIGATION_TYPES = {
    "சொட்டு நீர்": "Drip", "சொட்டு": "Drip", "டிரிப்": "Drip",
    "தெளிப்பான்": "Sprinkler", "ஸ்பிரிங்க்லர்": "Sprinkler",
    "வெள்ளம்": "Flood", "வாய்க்கால்": "Furrow",
    "மேல்மட்ட": "Overhead", "மைக்ரோ": "Micro Sprinkler",
    # English
    "drip": "Drip", "drip irrigation": "Drip", "drip system": "Drip",
    "sprinkler": "Sprinkler", "sprinkler system": "Sprinkler",
    "flood": "Flood", "furrow": "Furrow",
    "micro sprinkler": "Micro Sprinkler", "overhead": "Overhead",
    # Tanglish
    "sottu neer": "Drip", "sottu": "Drip", "drip pananum": "Drip",
    "sprinkler system": "Sprinkler", "sprinkler vennum": "Sprinkler",
    "thelipaan": "Sprinkler",
}

TAMIL_SOIL_TYPES = {
    "செம்மண்": "Red Loam", "சிவப்பு மண்": "Red Loam",
    "கருப்பு மண்": "Black Cotton", "கரிசல்": "Black Cotton",
    "வண்டல்": "Alluvial Clay", "வண்டல் மண்": "Alluvial Clay",
    "மணல்": "Sandy", "மணற்பாங்கான": "Sandy Loam",
    "களிமண்": "Clay", "கலவை மண்": "Mixed Loam",
    # English
    "red loam": "Red Loam", "red soil": "Red Loam",
    "black cotton": "Black Cotton", "black soil": "Black Cotton",
    "alluvial": "Alluvial Clay", "alluvial clay": "Alluvial Clay",
    "sandy loam": "Sandy Loam", "sandy": "Sandy", "clay": "Clay", "loam": "Loam",
    # Tanglish
    "semman": "Red Loam", "semmaan": "Red Loam", "sivappu mann": "Red Loam",
    "karuppu mann": "Black Cotton", "karisal": "Black Cotton",
    "vandal mann": "Alluvial Clay", "manal mann": "Sandy",
    "kali mann": "Clay",
}

TAMIL_POWER_PHASE = {
    "ஒற்றை": "Single Phase", "ஒற்றை கட்டம்": "Single Phase",
    "மூன்று கட்டம்": "Three Phase", "மூவட்டம்": "Three Phase",
    # English
    "single phase": "Single Phase", "single": "Single Phase",
    "three phase": "Three Phase", "3 phase": "Three Phase",
    "1 phase": "Single Phase", "threephase": "Three Phase",
    # Tanglish
    "single kattam": "Single Phase", "onnu kattam": "Single Phase",
    "moonu kattam": "Three Phase", "three kattam": "Three Phase",
    "singal": "Single Phase", "thriphase": "Three Phase",
}

TN_DISTRICTS = [
    "Chennai", "Coimbatore", "Madurai", "Salem", "Tiruchirappalli", "Trichy",
    "Erode", "Tirunelveli", "Thanjavur", "Vellore", "Tiruppur", "Dindigul",
    "Krishnagiri", "Namakkal", "Karur", "Pudukkottai", "Sivagangai", "Ramanathapuram",
    "Virudhunagar", "Thoothukudi", "Tuticorin", "Kanchipuram", "Dharmapuri",
    "Cuddalore", "Nagapattinam", "Villupuram", "Ariyalur", "Perambalur",
    "Tiruvarur", "Kallakurichi", "Ranipet", "Chengalpattu", "Tenkasi",
    "Tirupathur", "Mayiladuthurai", "சேலம்", "கோயம்புத்தூர்", "மதுரை",
    "திருச்சி", "ஈரோடு", "தஞ்சாவூர்", "வேலூர்",
    # Tanglish / phonetic
    "koimbatore", "kovai", "coimbator", "madurai", "thiruchirapalli",
    "theni", "dharmapuri", "kancheepuram", "viluppuram", "nagapatnam",
]

# ─── Slot-to-Question Mapping (for context carry-forward) ────────────────────

SLOT_QUESTION_KEYWORDS = {
    "land_size": ["acre", "hectare", "cent", "nilam", "thottam", "land", "farm size", "area", "ek", "adi", "ஏக்கர்"],
    "crop_types": ["payir", "crop", "grow", "cultivate", "podu", "வளர்", "பயிர்"],
    "water_source": ["thanni", "water", "bore", "well", "canal", "kinaru", "source", "நீர்"],
    "borewell_depth": ["bore depth", "borewell depth", "how deep", "depth", "adi", "feet", "ft"],
    "open_well_depth": ["well depth", "kinaru adi", "how deep well", "adi"],
    "motor_hp": ["motor", "pump", "hp", "horse", "etch pee", "எச்பி"],
    "irrigation_type": ["irrigation", "drip", "sprinkler", "system", "neer"],
    "soil_type": ["soil", "mann", "ground type", "மண்"],
    "district": ["area", "district", "place", "location", "where", "எங்க"],
    "budget": ["budget", "cost", "money", "rupees", "lakh", "பட்ஜெட்"],
    "power_phase": ["phase", "kattam", "power", "current", "மின்"],
}


# ─── Core NLU Extractor ───────────────────────────────────────────────────────

class NLUExtractor:
    """
    Multilingual NLU extractor for agricultural requirements.
    Tries LLM extraction first (if configured), falls back to rule-based.
    """

    def __init__(self):
        self.llm_provider = os.getenv("LLM_PROVIDER", "local").lower()
        self.gemini_api_key = os.getenv("GEMINI_API_KEY", "")
        self.gemini_model = os.getenv("GEMINI_MODEL", "gemini-1.5-flash")
        self.openai_api_key = os.getenv("OPENAI_API_KEY", "")
        self.openai_model = os.getenv("OPENAI_MODEL", "gpt-4o-mini")

    def set_provider(self, provider: str, api_key: str = "", model: str = ""):
        """Runtime provider switch from UI."""
        self.llm_provider = provider.lower()
        if provider == "gemini" and api_key:
            self.gemini_api_key = api_key
        if provider == "openai" and api_key:
            self.openai_api_key = api_key
        if model:
            if provider == "gemini":
                self.gemini_model = model
            elif provider == "openai":
                self.openai_model = model

    async def extract(self, text: str, context_history: Optional[List[Dict]] = None) -> Dict[str, Any]:
        """
        Extract agricultural requirement slots from user input.
        Returns a dict with all found slots and confidence scores.
        context_history: list of recent {'role': ..., 'message': ...} dicts
        """
        language = self._detect_language(text)

        # Pre-process: replace Tanglish number words with digits
        text_normalized = self._normalize_tanglish_numbers(text)

        slots: Dict[str, Any] = {}

        # Try LLM extraction first
        if self.llm_provider == "gemini" and self.gemini_api_key and self.gemini_api_key != "your_gemini_api_key_here":
            try:
                slots = await self._extract_gemini(text_normalized, language, context_history)
                slots["_extraction_method"] = "gemini"
                slots["_language"] = language
                return slots
            except Exception as e:
                logger.warning(f"Gemini extraction failed, falling back to rule-based: {e}")

        elif self.llm_provider == "openai" and self.openai_api_key and self.openai_api_key != "your_openai_api_key_here":
            try:
                slots = await self._extract_openai(text_normalized, language, context_history)
                slots["_extraction_method"] = "openai"
                slots["_language"] = language
                return slots
            except Exception as e:
                logger.warning(f"OpenAI extraction failed, falling back to rule-based: {e}")

        # Rule-based fallback
        slots = self._extract_rule_based(text_normalized, language, context_history)
        slots["_extraction_method"] = "rule_based"
        slots["_language"] = language
        return slots

    # ─── Tanglish Number Normalizer ────────────────────────────────────────────

    def _normalize_tanglish_numbers(self, text: str) -> str:
        """Replace Tamil number words (romanized) with digits."""
        result = text
        for word, number in sorted(TANGLISH_NUMBERS.items(), key=lambda x: -len(x[0])):
            pattern = r'\b' + re.escape(word) + r'\b'
            result = re.sub(pattern, str(number), result, flags=re.IGNORECASE)
        return result

    # ─── Language Detection ────────────────────────────────────────────────────

    def _detect_language(self, text: str) -> str:
        """Detect if text is Tamil, English, or Tanglish."""
        tamil_chars = len(re.findall(r'[\u0B80-\u0BFF]', text))
        total_chars = len(text.replace(" ", ""))
        if total_chars == 0:
            return "english"
        ratio = tamil_chars / total_chars
        if ratio > 0.5:
            return "tamil"
        elif ratio > 0.1:
            return "tanglish"
        else:
            return "english"

    # ─── Context Carry-Forward ────────────────────────────────────────────────

    def _infer_slot_from_context(self, text: str, context_history: Optional[List[Dict]]) -> Dict[str, Any]:
        """
        If the current message is a short response (a number or single word),
        check what question was last asked and fill that slot.
        """
        if not context_history or not text.strip():
            return {}
        t = text.strip().lower()
        # Check if response is just a number (possibly with unit)
        num_match = re.match(r'^(\d+(?:\.\d+)?)\s*(ft|feet|அடி|adi|acres?|hp|lph)?$', t)
        if not num_match and len(t.split()) > 4:
            return {}  # Too complex for context carry-forward

        # Find last assistant message
        last_bot_msg = ""
        for turn in reversed(context_history):
            if turn.get("role") == "assistant":
                last_bot_msg = turn.get("message", "").lower()
                break
        if not last_bot_msg:
            return {}

        # Map last question to slot
        for slot, keywords in SLOT_QUESTION_KEYWORDS.items():
            if any(kw in last_bot_msg for kw in keywords):
                if num_match:
                    num = float(num_match.group(1))
                    unit = (num_match.group(2) or "").lower()
                    if slot == "land_size":
                        return {"land_size": num, "land_unit": "acres"}
                    elif slot == "borewell_depth":
                        return {"borewell_depth_ft": num}
                    elif slot == "open_well_depth":
                        return {"open_well_depth_ft": num}
                    elif slot == "motor_hp":
                        return {"motor_hp": num}
                    elif slot == "budget":
                        return {"budget_inr": num}
                    elif slot == "power_phase":
                        # number alone won't help phase
                        pass
        return {}

    # ─── LLM Extraction: Gemini ───────────────────────────────────────────────

    async def _extract_gemini(self, text: str, language: str, context_history: Optional[List[Dict]] = None) -> Dict[str, Any]:
        prompt = self._build_llm_prompt(text, language, context_history)
        url = f"https://generativelanguage.googleapis.com/v1beta/models/{self.gemini_model}:generateContent"
        payload = {
            "contents": [{"parts": [{"text": prompt}]}],
            "generationConfig": {"temperature": 0.05, "maxOutputTokens": 1024},
        }
        async with httpx.AsyncClient(timeout=30) as client:
            resp = await client.post(
                url,
                params={"key": self.gemini_api_key},
                json=payload,
            )
            resp.raise_for_status()
            data = resp.json()
            raw = data["candidates"][0]["content"]["parts"][0]["text"]
            return self._parse_llm_json(raw)

    # ─── LLM Extraction: OpenAI ───────────────────────────────────────────────

    async def _extract_openai(self, text: str, language: str, context_history: Optional[List[Dict]] = None) -> Dict[str, Any]:
        prompt = self._build_llm_prompt(text, language, context_history)
        url = "https://api.openai.com/v1/chat/completions"
        payload = {
            "model": self.openai_model,
            "messages": [
                {"role": "system", "content": "You are an agricultural NLU assistant for Tamil Nadu, India. Extract structured slot data from farmer requirements. Support Tamil, English, and Tanglish."},
                {"role": "user", "content": prompt},
            ],
            "temperature": 0.05,
            "max_tokens": 1024,
        }
        async with httpx.AsyncClient(timeout=30) as client:
            resp = await client.post(
                url,
                headers={"Authorization": f"Bearer {self.openai_api_key}"},
                json=payload,
            )
            resp.raise_for_status()
            data = resp.json()
            raw = data["choices"][0]["message"]["content"]
            return self._parse_llm_json(raw)

    def _build_llm_prompt(self, text: str, language: str, context_history: Optional[List[Dict]] = None) -> str:
        # Build conversation context string
        ctx_str = ""
        if context_history:
            recent = context_history[-6:]  # Last 3 turns
            ctx_lines = []
            for turn in recent:
                role = turn.get("role", "")
                msg = turn.get("message", "")
                if role and msg:
                    ctx_lines.append(f"  {role.upper()}: {msg}")
            if ctx_lines:
                ctx_str = "Recent conversation context:\n" + "\n".join(ctx_lines) + "\n\n"

        return f"""You are an expert agricultural requirements assistant for Tamil Nadu, India.
Extract structured information from the farmer's input below. The input may be in:
- Tamil (native script)
- English
- Tanglish (Tamil written in English letters, e.g. "rendu acre karumbu farm la borewell 280 feet depth iruku, 3 HP motor")

Key Tanglish vocabulary you must understand:
- Land: "nilam"=land, "thottam"=farm, "ek/ekkar"=acres, "adi/adii"=feet depth
- Numbers: "onnu"=1, "rendu"=2, "moonu"=3, "naalu"=4, "anju"=5, "aaru"=6, "ezhu"=7, "ettu"=8, "ombadhu"=9, "padhu"=10
- Water: "bore/boruvell"=Borewell, "kinaru/kinnal"=Open Well, "kalvai/kanavai"=Canal, "eri/kulam"=Tank
- Crops: "karumbu"=Sugarcane, "vazhai/vaazhai"=Banana, "nel/nellu"=Paddy, "thennai"=Coconut, "manjal"=Turmeric, "inji"=Ginger
- Motor: "motor HP", "pump", "etch pee", "horse power"
- Irrigation: "sottu neer/sottu"=Drip, "thelipaan/sprinkler"=Sprinkler
- Soil: "semman/semmaan"=Red Loam, "karisal/karuppu mann"=Black Cotton, "manal"=Sandy
- Phase: "single/singal"=Single Phase, "three kattam/moonu kattam"=Three Phase

{ctx_str}Farmer Input ({language}):
"{text}"

Extract and return ONLY a valid JSON object with these fields (use null for unknown/not mentioned):
{{
  "land_size": <number or null>,
  "land_unit": <"acres"|"hectares"|"cents"|null>,
  "crop_types": <array of English crop names or null>,
  "soil_type": <"Red Loam"|"Black Cotton"|"Alluvial Clay"|"Sandy Loam"|"Sandy"|"Clay"|"Loam"|null>,
  "water_source": <"Borewell"|"Open Well"|"Canal"|"River"|"Tank/Pond"|"Rainwater"|null>,
  "borewell_depth_ft": <number or null>,
  "open_well_depth_ft": <number or null>,
  "water_discharge_lph": <number or null>,
  "motor_hp": <number or null>,
  "power_supply_phase": <"Single Phase"|"Three Phase"|null>,
  "power_hours_per_day": <number or null>,
  "irrigation_type": <"Drip"|"Sprinkler"|"Micro Sprinkler"|"Flood"|"Furrow"|"Overhead"|null>,
  "district": <Tamil Nadu district name or null>,
  "budget_inr": <number in INR (multiply lakhs by 100000) or null>
}}

IMPORTANT: 
- Infer from context if the message is incomplete (e.g., if previous bot asked about depth and user says "280", set borewell_depth_ft=280)
- "lakh" or "lakhs" = 100,000 INR
- Depths are ALWAYS in feet unless stated otherwise
- HP numbers can be decimals (1.5, 2.5, 7.5)
Return ONLY the JSON object. No explanation, no markdown, no extra text."""

    def _parse_llm_json(self, raw: str) -> Dict[str, Any]:
        """Parse JSON from LLM response, handling markdown code fences."""
        text = raw.strip()
        # Strip markdown code fences
        text = re.sub(r'^```(?:json)?\s*', '', text, flags=re.MULTILINE)
        text = re.sub(r'```\s*$', '', text, flags=re.MULTILINE)
        text = text.strip()
        try:
            return json.loads(text)
        except json.JSONDecodeError:
            # Try to extract JSON object from text
            match = re.search(r'\{.*\}', text, re.DOTALL)
            if match:
                try:
                    return json.loads(match.group())
                except Exception:
                    pass
            return {}

    # ─── Rule-Based Extraction ─────────────────────────────────────────────────

    def _extract_rule_based(self, text: str, language: str, context_history: Optional[List[Dict]] = None) -> Dict[str, Any]:
        """Comprehensive rule-based slot extraction for Tamil/English/Tanglish."""
        t = text.lower().strip()
        slots: Dict[str, Any] = {}

        # Context carry-forward (short/single responses)
        if context_history:
            ctx_slots = self._infer_slot_from_context(t, context_history)
            slots.update(ctx_slots)

        slots.update(self._extract_land_size(t, text))
        slots.update(self._extract_crops(t))
        slots.update(self._extract_water_source(t))
        slots.update(self._extract_depths(t))
        slots.update(self._extract_motor(t))
        slots.update(self._extract_power(t))
        slots.update(self._extract_irrigation_type(t))
        slots.update(self._extract_soil_type(t))
        slots.update(self._extract_district(text))
        slots.update(self._extract_budget(t))

        return slots

    def _extract_land_size(self, t: str, original: str) -> Dict:
        """Extract land area and unit with broad phonetic coverage."""
        patterns = [
            # Tamil script
            r'(\d+(?:\.\d+)?)\s*(?:ஏக்கர்(?:கள்)?|ஏக்|ஹெக்டேர்|சென்ட்)',
            # English
            r'(\d+(?:\.\d+)?)\s*(?:acres?|hectares?|cents?)',
            # Tanglish / phonetic
            r'(\d+(?:\.\d+)?)\s*(?:ek(?:kar)?|ekkar)',
            r'(\d+(?:\.\d+)?)\s*(?:acre|ஏக்கர்)',
            r'(\d+(?:\.\d+)?)\s*(?:hek(?:tar)?|hekktar)',
        ]
        unit_map = {
            'ஏக்கர்': 'acres', 'ஏக்கர்கள்': 'acres', 'ஏக்': 'acres',
            'ஹெக்டேர்': 'hectares', 'சென்ட்': 'cents',
            'acre': 'acres', 'acres': 'acres',
            'hectare': 'hectares', 'hectares': 'hectares',
            'cent': 'cents', 'cents': 'cents',
            'ek': 'acres', 'ekkar': 'acres',
            'hek': 'hectares', 'hekktar': 'hectares',
        }

        for pat in patterns:
            m = re.search(pat, t, re.UNICODE)
            if m:
                num = float(m.group(1))
                matched_text = m.group(0)
                unit = 'acres'
                for key, val in unit_map.items():
                    if key in matched_text:
                        unit = val
                        break
                return {'land_size': num, 'land_unit': unit}

        # Generic: number before any land keyword
        m = re.search(r'(\d+(?:\.\d+)?)\s*(?:land|thottam|nilam|நிலம்|தோட்டம்)', t, re.UNICODE)
        if m:
            return {'land_size': float(m.group(1)), 'land_unit': 'acres'}

        return {}

    def _extract_crops(self, t: str) -> Dict:
        """Extract crop types using exact + fuzzy matching."""
        found = []
        for keyword, crop in TAMIL_CROPS.items():
            if keyword.lower() in t:
                if crop not in found:
                    found.append(crop)
        # Fuzzy matching on English words for crop names
        words = t.split()
        all_crop_keys = [k for k in TAMIL_CROPS.keys() if len(k) > 3 and k.isascii()]
        for word in words:
            if len(word) > 3:
                close = get_close_matches(word, all_crop_keys, n=1, cutoff=0.82)
                if close:
                    crop = TAMIL_CROPS[close[0]]
                    if crop not in found:
                        found.append(crop)
        if found:
            return {'crop_types': found}
        return {}

    def _extract_water_source(self, t: str) -> Dict:
        """Extract water source type."""
        for keyword, source in TAMIL_WATER_SOURCES.items():
            if keyword.lower() in t:
                return {'water_source': source}
        return {}

    def _extract_depths(self, t: str) -> Dict:
        """Extract borewell/open well depth in feet."""
        result = {}
        # Determine context
        has_bore = any(w in t for w in ['bore', 'போர்', 'ஆழ்துளை', 'boruvell', 'borevell'])
        has_open_well = any(w in t for w in ['open well', 'kinaru', 'kinnal', 'கிணறு', 'கிணர்', 'kinnu'])

        # Borewell depth patterns
        borewell_patterns = [
            r'bore(?:well)?\s+(?:depth\s+)?(?:is\s+)?(\d+(?:\.\d+)?)\s*(?:feet|ft|அடி|adi)',
            r'(\d+(?:\.\d+)?)\s*(?:feet|ft|அடி|adi)\s+(?:deep\s+)?bore',
            r'(\d+(?:\.\d+)?)\s*(?:அடி|ft|feet)\s+(?:போர்|bore)',
            r'bore[^.]*?(\d+(?:\.\d+)?)\s*(?:அடி|ft|feet)',
        ]
        for pat in borewell_patterns:
            m = re.search(pat, t, re.UNICODE)
            if m:
                depth = float(m.group(1))
                if has_open_well:
                    result['open_well_depth_ft'] = depth
                else:
                    result['borewell_depth_ft'] = depth
                return result

        # Fallback: any depth number with ft/adi
        m = re.search(r'(\d+(?:\.\d+)?)\s*(?:அடி|adi|adii|feet|ft)\b', t, re.UNICODE)
        if m:
            depth = float(m.group(1))
            if has_open_well:
                result['open_well_depth_ft'] = depth
            elif has_bore:
                result['borewell_depth_ft'] = depth

        return result

    def _extract_motor(self, t: str) -> Dict:
        """Extract motor HP with phonetic coverage."""
        patterns = [
            r'(\d+(?:\.\d+)?)\s*(?:hp|h\.p\.|horse\s*power|etch\s*pee|horse|எச்பி|ஏச்பி|மோட்டார்)',
            r'(\d+(?:\.\d+)?)\s*hp',
            r'(\d+(?:\.\d+)?)\s*(?:ஹெச்பி|ஏச்பி)',
        ]
        for pat in patterns:
            m = re.search(pat, t, re.UNICODE)
            if m:
                return {'motor_hp': float(m.group(1))}
        return {}

    def _extract_power(self, t: str) -> Dict:
        """Extract power supply phase and hours."""
        result = {}
        # Phase
        three_phase_kws = ['three phase', '3 phase', '3phase', 'மூன்று கட்டம்', 'three-phase',
                           'moonu kattam', 'three kattam', 'thriphase', 'threephase']
        single_phase_kws = ['single phase', '1 phase', '1phase', 'ஒற்றை', 'single-phase',
                            'singal', 'single kattam', 'onnu kattam']
        if any(w in t for w in three_phase_kws):
            result['power_supply_phase'] = 'Three Phase'
        elif any(w in t for w in single_phase_kws):
            result['power_supply_phase'] = 'Single Phase'

        # Hours per day
        m = re.search(r'(\d+(?:\.\d+)?)\s*(?:hours?|hrs?|மணி\s*நேரம்|mani neram|hr)', t, re.UNICODE)
        if m:
            result['power_hours_per_day'] = float(m.group(1))

        return result

    def _extract_irrigation_type(self, t: str) -> Dict:
        """Extract preferred irrigation system type."""
        for keyword, itype in TAMIL_IRRIGATION_TYPES.items():
            if keyword.lower() in t:
                return {'irrigation_type': itype}
        return {}

    def _extract_soil_type(self, t: str) -> Dict:
        """Extract soil type with phonetic coverage."""
        for keyword, soil in TAMIL_SOIL_TYPES.items():
            if keyword.lower() in t:
                return {'soil_type': soil}
        return {}

    def _extract_district(self, text: str) -> Dict:
        """Extract Tamil Nadu district name with fuzzy matching."""
        t_lower = text.lower()
        # Exact match first
        for district in TN_DISTRICTS:
            if district.lower() in t_lower:
                # Normalize to proper name
                canonical = district.split('/')[0].strip()
                return {'district': canonical}
        # Fuzzy match on single words
        words = re.findall(r'\b[a-zA-Z]{4,}\b', t_lower)
        canonical_districts = [d for d in TN_DISTRICTS if d.isascii()]
        for word in words:
            close = get_close_matches(word, [d.lower() for d in canonical_districts], n=1, cutoff=0.85)
            if close:
                idx = [d.lower() for d in canonical_districts].index(close[0])
                return {'district': canonical_districts[idx]}
        return {}

    def _extract_budget(self, t: str) -> Dict:
        """Extract budget in INR."""
        patterns = [
            r'(?:budget|பட்ஜெட்|₹|rs\.?|rupees?)[^\d]*(\d+(?:\.\d+)?)\s*(?:lakh|lakhs|லட்சம்)',
            r'(\d+(?:\.\d+)?)\s*(?:lakh|lakhs|லட்சம்)\s*(?:budget|பட்ஜெட்)?',
            r'(?:budget|₹|rs\.?)[^\d]*(\d+(?:,\d+)*(?:\.\d+)?)',
            r'(\d+(?:,\d+)*(?:\.\d+)?)\s*(?:rupees?|ரூபாய்)',
        ]
        for i, pat in enumerate(patterns):
            m = re.search(pat, t, re.UNICODE)
            if m:
                num_str = m.group(1).replace(',', '')
                num = float(num_str)
                if i < 2:  # lakh pattern
                    num *= 100000
                return {'budget_inr': num}
        return {}


# Singleton
nlu_extractor = NLUExtractor()
