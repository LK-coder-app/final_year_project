"""
AgriMind - Dialogue State Tracker
Maintains conversational session state with multi-turn memory.
Tracks slots, confidence, and conversation history per session.
"""
from __future__ import annotations

import time
from typing import Any, Dict, List, Optional

# ─── Slot Schema ──────────────────────────────────────────────────────────────

REQUIRED_SLOTS = [
    "land_size",
    "land_unit",
    "crop_types",
    "water_source",
    "motor_hp",
    "irrigation_type",
]

OPTIONAL_SLOTS = [
    "soil_type",
    "borewell_depth_ft",
    "open_well_depth_ft",
    "water_discharge_lph",
    "power_supply_phase",
    "power_hours_per_day",
    "district",
    "budget_inr",
]

ALL_SLOTS = REQUIRED_SLOTS + OPTIONAL_SLOTS


# ─── Session State ─────────────────────────────────────────────────────────────

class SessionState:
    def __init__(self, session_id: str):
        self.session_id = session_id
        self.slots: Dict[str, Any] = {}
        self.slot_confidence: Dict[str, float] = {}
        self.turn_index: int = 0
        self.history: List[Dict[str, str]] = []
        self.language: str = "english"
        self.last_updated: float = time.time()
        self.is_submitted: bool = False
        self.last_question_slot: Optional[str] = None  # Which slot was last asked about

    def update_slots(self, new_slots: Dict[str, Any]):
        """Merge newly extracted slots into current state."""
        for key, value in new_slots.items():
            if key.startswith("_"):
                continue  # Skip metadata keys
            if value is not None:
                self.slots[key] = value
                # Confidence: LLM extractions get higher confidence
                self.slot_confidence[key] = 0.95

        self.last_updated = time.time()

    def add_turn(self, role: str, message: str):
        self.history.append({"role": role, "message": message})
        if role == "user":
            self.turn_index += 1

    def get_last_n_turns(self, n: int = 6) -> List[Dict[str, str]]:
        """Return last n history items for context-aware extraction."""
        return self.history[-n:] if self.history else []

    def get_missing_required_slots(self) -> List[str]:
        return [s for s in REQUIRED_SLOTS if s not in self.slots or self.slots[s] is None]

    def get_missing_optional_slots(self) -> List[str]:
        return [s for s in OPTIONAL_SLOTS if s not in self.slots or self.slots[s] is None]

    def get_completion_pct(self) -> float:
        filled_required = sum(1 for s in REQUIRED_SLOTS if s in self.slots and self.slots[s] is not None)
        filled_optional = sum(1 for s in OPTIONAL_SLOTS if s in self.slots and self.slots[s] is not None)
        # Required slots count for 70%, optional for 30%
        req_score = (filled_required / len(REQUIRED_SLOTS)) * 70
        opt_score = (filled_optional / len(OPTIONAL_SLOTS)) * 30
        return round(req_score + opt_score, 1)

    def is_complete(self) -> bool:
        """Requirements are complete when all required slots are filled."""
        return len(self.get_missing_required_slots()) == 0

    def to_dict(self) -> Dict[str, Any]:
        return {
            "session_id": self.session_id,
            "slots": self.slots,
            "slot_confidence": self.slot_confidence,
            "turn_index": self.turn_index,
            "language": self.language,
            "completion_pct": self.get_completion_pct(),
            "missing_required": self.get_missing_required_slots(),
            "missing_optional": self.get_missing_optional_slots(),
            "is_complete": self.is_complete(),
        }


# ─── Session Manager ──────────────────────────────────────────────────────────

class DialogueTracker:
    """In-memory session manager. For production, swap with Redis."""

    def __init__(self):
        self._sessions: Dict[str, SessionState] = {}
        self._session_timeout_s = 3600  # 1 hour

    def get_or_create(self, session_id: str) -> SessionState:
        if session_id not in self._sessions:
            self._sessions[session_id] = SessionState(session_id)
        return self._sessions[session_id]

    def get(self, session_id: str) -> Optional[SessionState]:
        return self._sessions.get(session_id)

    def delete(self, session_id: str):
        self._sessions.pop(session_id, None)

    def cleanup_expired(self):
        """Remove sessions older than timeout."""
        now = time.time()
        expired = [
            sid for sid, state in self._sessions.items()
            if now - state.last_updated > self._session_timeout_s
        ]
        for sid in expired:
            del self._sessions[sid]

    def get_slots_for_db(self, session_id: str) -> Dict[str, Any]:
        """Return a flat dict of extracted slots suitable for DB insertion."""
        state = self.get(session_id)
        if not state:
            return {}
        s = state.slots
        return {
            "land_size": s.get("land_size"),
            "land_unit": s.get("land_unit"),
            "crop_types": s.get("crop_types"),
            "soil_type": s.get("soil_type"),
            "water_source": s.get("water_source"),
            "borewell_depth_ft": s.get("borewell_depth_ft"),
            "open_well_depth_ft": s.get("open_well_depth_ft"),
            "water_discharge_lph": s.get("water_discharge_lph"),
            "motor_hp": s.get("motor_hp"),
            "power_supply_phase": s.get("power_supply_phase"),
            "power_hours_per_day": s.get("power_hours_per_day"),
            "irrigation_type": s.get("irrigation_type"),
            "district": s.get("district"),
            "budget_inr": s.get("budget_inr"),
        }


# Singleton
dialogue_tracker = DialogueTracker()
