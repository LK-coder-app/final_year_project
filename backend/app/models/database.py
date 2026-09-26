"""
AgriMind - SQLAlchemy Database Models + Seed Data
"""
import hashlib
import hmac
import json
import os
import secrets
from datetime import datetime, timezone

from sqlalchemy import (
    Boolean, Column, DateTime, Float, Integer, JSON, String, Text, create_engine
)
from sqlalchemy.orm import declarative_base, sessionmaker

DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./agrimind.db")

engine = create_engine(
    DATABASE_URL,
    connect_args={"check_same_thread": False} if "sqlite" in DATABASE_URL else {},
)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()


def utcnow():
    return datetime.now(timezone.utc)


# ─── ORM Models ──────────────────────────────────────────────────────────────

class FarmerRequirement(Base):
    __tablename__ = "farmer_requirements"

    id = Column(Integer, primary_key=True, index=True)
    session_id = Column(String(64), unique=True, index=True)
    farmer_name = Column(String(255), nullable=True)
    farmer_phone = Column(String(20), nullable=True)
    farmer_email = Column(String(255), nullable=True, index=True)
    district = Column(String(100), nullable=True)
    language = Column(String(20), default="english")

    # Farm & Crop
    land_size = Column(Float, nullable=True)
    land_unit = Column(String(20), nullable=True)
    crop_types = Column(JSON, nullable=True)
    soil_type = Column(String(100), nullable=True)

    # Water
    water_source = Column(String(100), nullable=True)
    borewell_depth_ft = Column(Float, nullable=True)
    open_well_depth_ft = Column(Float, nullable=True)
    water_discharge_lph = Column(Float, nullable=True)

    # Power
    motor_hp = Column(Float, nullable=True)
    power_supply_phase = Column(String(20), nullable=True)
    power_hours_per_day = Column(Float, nullable=True)

    # Irrigation
    irrigation_type = Column(String(100), nullable=True)
    budget_inr = Column(Float, nullable=True)

    # Extracted slots JSON (raw NLU output)
    extracted_slots = Column(JSON, nullable=True)

    # Engineering analysis
    conflicts = Column(JSON, nullable=True)
    feasibility_score = Column(Float, nullable=True)
    feasibility_details = Column(JSON, nullable=True)

    # Workflow
    status = Column(String(50), default="pending")  # pending, under_review, feasible, quoted, rejected
    pdf_path = Column(String(512), nullable=True)
    pdf_version = Column(Integer, default=1)
    company_notes = Column(Text, nullable=True)

    # Admin LLM Analysis
    missing_fields = Column(JSON, nullable=True)       # List of missing field keys from LLM analysis
    llm_analysis_text = Column(Text, nullable=True)    # Full LLM narrative analysis

    # Farmer Follow-up Form
    follow_up_token = Column(String(64), unique=True, nullable=True, index=True)
    follow_up_sent_at = Column(DateTime, nullable=True)
    follow_up_filled_at = Column(DateTime, nullable=True)
    last_submitted_form_data = Column(JSON, nullable=True)
    form_sent_to_account = Column(Boolean, default=False)
    pdf_delivered_to_farmer = Column(Boolean, default=False)
    pdf_delivered_at = Column(DateTime, nullable=True)

    # Metadata
    created_at = Column(DateTime, default=utcnow)
    updated_at = Column(DateTime, default=utcnow, onupdate=utcnow)
    submitted_at = Column(DateTime, nullable=True)


class ConversationLog(Base):
    __tablename__ = "conversation_logs"

    id = Column(Integer, primary_key=True, index=True)
    session_id = Column(String(64), index=True)
    turn_index = Column(Integer, default=0)
    role = Column(String(20))        # "user" or "assistant"
    message = Column(Text)
    language_detected = Column(String(20), nullable=True)
    slots_extracted = Column(JSON, nullable=True)
    created_at = Column(DateTime, default=utcnow)


class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    email = Column(String(255), unique=True, index=True, nullable=False)
    phone = Column(String(30), unique=True, index=True, nullable=True)
    full_name = Column(String(255), nullable=False)
    password_hash = Column(String(255), nullable=False)
    role = Column(String(20), default="farmer", index=True)  # "farmer" or "admin"
    firebase_uid = Column(String(128), unique=True, nullable=True, index=True)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=utcnow)
    last_login = Column(DateTime, nullable=True)


# ─── Password Security Helpers ───────────────────────────────────────────────

AUTH_SALT = "agrimind_security_salt_2026"

def hash_password(password: str) -> str:
    return hashlib.sha256(f"{AUTH_SALT}:{password}".encode("utf-8")).hexdigest()

def verify_password(password: str, hashed: str) -> bool:
    return hmac.compare_digest(hash_password(password), hashed)


# ─── DB Helpers ──────────────────────────────────────────────────────────────

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def init_db():
    Base.metadata.create_all(bind=engine)
    _migrate_add_columns()
    _seed_auth_users()
    _seed_demo_data()


def _seed_auth_users():
    """Seed initial default Administrator and sample Farmer accounts."""
    db = SessionLocal()
    try:
        # 1. Admin account
        admin = db.query(User).filter(User.email == "admin@agrimind.ai").first()
        if not admin:
            admin = User(
                email="admin@agrimind.ai",
                phone="+919000000001",
                full_name="AgriMind Administrator",
                password_hash=hash_password("admin123"),
                role="admin",
                is_active=True,
            )
            db.add(admin)
            print("[AgriMind] Seeded Admin account: admin@agrimind.ai / admin123")

        # 2. Farmer account
        farmer = db.query(User).filter(User.email == "murugesan@agrimind.ai").first()
        if not farmer:
            farmer = User(
                email="murugesan@agrimind.ai",
                phone="+919876543210",
                full_name="Murugesan K.",
                password_hash=hash_password("farmer123"),
                role="farmer",
                is_active=True,
            )
            db.add(farmer)
            print("[AgriMind] Seeded Farmer account: murugesan@agrimind.ai / farmer123")

        db.commit()
    except Exception as e:
        db.rollback()
        print(f"[AgriMind] Seed auth users error (non-fatal): {e}")
    finally:
        db.close()


def _migrate_add_columns():
    """Safe migration: add new columns if they don't exist (SQLite compatible)."""
    from sqlalchemy import inspect, text
    try:
        inspector = inspect(engine)
        columns = {c["name"] for c in inspector.get_columns("farmer_requirements")}
        new_cols = {
            "farmer_email": "VARCHAR(255)",
            "missing_fields": "TEXT",
            "llm_analysis_text": "TEXT",
            "follow_up_token": "VARCHAR(64)",
            "follow_up_sent_at": "DATETIME",
            "follow_up_filled_at": "DATETIME",
            "last_submitted_form_data": "TEXT",
            "pdf_version": "INTEGER DEFAULT 1",
            "form_sent_to_account": "BOOLEAN DEFAULT 0",
            "pdf_delivered_to_farmer": "BOOLEAN DEFAULT 0",
            "pdf_delivered_at": "DATETIME",
        }
        with engine.connect() as conn:
            for col, dtype in new_cols.items():
                if col not in columns:
                    try:
                        conn.execute(text(f"ALTER TABLE farmer_requirements ADD COLUMN {col} {dtype}"))
                        conn.commit()
                        print(f"[AgriMind] Migrated: added column '{col}'")
                    except Exception as e:
                        print(f"[AgriMind] Migration skip '{col}': {e}")
    except Exception as e:
        print(f"[AgriMind] Migration check failed (non-fatal): {e}")


def _seed_demo_data():
    """Seed realistic Tamil Nadu agricultural demo requirements."""
    db = SessionLocal()
    try:
        count = db.query(FarmerRequirement).count()
        if count > 0:
            return  # Already seeded

        demo_records = [
            FarmerRequirement(
                session_id="demo-001",
                farmer_name="Murugesan K.",
                farmer_phone="+91-9876543210",
                district="Coimbatore",
                language="tanglish",
                land_size=4.0,
                land_unit="acres",
                crop_types=["Banana"],
                soil_type="Red Loam",
                water_source="Borewell",
                borewell_depth_ft=280.0,
                motor_hp=3.0,
                power_supply_phase="Single Phase",
                power_hours_per_day=6.0,
                irrigation_type="Drip",
                budget_inr=180000.0,
                extracted_slots={
                    "land_size": 4.0, "land_unit": "acres",
                    "crop_types": ["Banana"], "soil_type": "Red Loam",
                    "water_source": "Borewell", "borewell_depth_ft": 280.0,
                    "motor_hp": 3.0, "power_supply_phase": "Single Phase",
                    "power_hours_per_day": 6.0, "irrigation_type": "Drip",
                    "budget_inr": 180000.0
                },
                conflicts=[],
                feasibility_score=88.5,
                feasibility_details={
                    "motor_adequacy": "Adequate",
                    "water_sufficiency": "Sufficient",
                    "power_coverage": "Full cycle coverage",
                    "recommended_system": "Drip Irrigation with 2 LPH drippers @ 1.5m spacing"
                },
                status="feasible",
                submitted_at=datetime(2026, 9, 18, 10, 30, tzinfo=timezone.utc),
                created_at=datetime(2026, 9, 18, 10, 0, tzinfo=timezone.utc),
                updated_at=datetime(2026, 9, 18, 10, 30, tzinfo=timezone.utc),
            ),
            FarmerRequirement(
                session_id="demo-002",
                farmer_name="Selvaraj P.",
                farmer_phone="+91-9654321098",
                district="Salem",
                language="tamil",
                land_size=8.0,
                land_unit="acres",
                crop_types=["Sugarcane"],
                soil_type="Black Cotton",
                water_source="Borewell",
                borewell_depth_ft=420.0,
                motor_hp=3.0,
                power_supply_phase="Single Phase",
                power_hours_per_day=5.0,
                irrigation_type="Drip",
                budget_inr=350000.0,
                extracted_slots={
                    "land_size": 8.0, "land_unit": "acres",
                    "crop_types": ["Sugarcane"], "soil_type": "Black Cotton",
                    "water_source": "Borewell", "borewell_depth_ft": 420.0,
                    "motor_hp": 3.0, "power_supply_phase": "Single Phase",
                    "power_hours_per_day": 5.0, "irrigation_type": "Drip",
                    "budget_inr": 350000.0
                },
                conflicts=[
                    {
                        "type": "motor_undersized",
                        "severity": "high",
                        "message": "3 HP motor is insufficient for 8 acres sugarcane with 420 ft borewell head. Recommended: 7.5 HP.",
                        "recommendation": "Upgrade to 7.5 HP submersible pump or divide farm into 2 zones with separate pumps."
                    },
                    {
                        "type": "power_hours_insufficient",
                        "severity": "medium",
                        "message": "5 hours/day is insufficient to complete full irrigation cycle for sugarcane. Minimum 8 hours required.",
                        "recommendation": "Apply for additional power supply or plan night irrigation schedule."
                    }
                ],
                feasibility_score=42.0,
                feasibility_details={
                    "motor_adequacy": "Undersized - Upgrade Required",
                    "water_sufficiency": "Marginal",
                    "power_coverage": "Insufficient for full cycle",
                    "recommended_system": "7.5 HP pump with zonal drip, 4 zones of 2 acres each"
                },
                status="under_review",
                submitted_at=datetime(2026, 9, 19, 14, 15, tzinfo=timezone.utc),
                created_at=datetime(2026, 9, 19, 13, 45, tzinfo=timezone.utc),
                updated_at=datetime(2026, 9, 19, 14, 15, tzinfo=timezone.utc),
            ),
            FarmerRequirement(
                session_id="demo-003",
                farmer_name="Kavitha S.",
                farmer_phone="+91-9543210987",
                district="Thanjavur",
                language="english",
                land_size=12.0,
                land_unit="acres",
                crop_types=["Paddy", "Vegetables"],
                soil_type="Alluvial Clay",
                water_source="Canal",
                motor_hp=5.0,
                power_supply_phase="Three Phase",
                power_hours_per_day=10.0,
                irrigation_type="Sprinkler",
                budget_inr=520000.0,
                extracted_slots={
                    "land_size": 12.0, "land_unit": "acres",
                    "crop_types": ["Paddy", "Vegetables"], "soil_type": "Alluvial Clay",
                    "water_source": "Canal", "motor_hp": 5.0,
                    "power_supply_phase": "Three Phase", "power_hours_per_day": 10.0,
                    "irrigation_type": "Sprinkler", "budget_inr": 520000.0
                },
                conflicts=[],
                feasibility_score=91.0,
                feasibility_details={
                    "motor_adequacy": "Well-sized",
                    "water_sufficiency": "Canal - Abundant",
                    "power_coverage": "Excellent coverage",
                    "recommended_system": "Mini sprinkler @ 12m x 12m grid, 5 HP centrifugal pump"
                },
                status="quoted",
                submitted_at=datetime(2026, 9, 17, 9, 0, tzinfo=timezone.utc),
                created_at=datetime(2026, 9, 17, 8, 30, tzinfo=timezone.utc),
                updated_at=datetime(2026, 9, 20, 11, 0, tzinfo=timezone.utc),
            ),
            FarmerRequirement(
                session_id="demo-004",
                farmer_name="Rajan M.",
                farmer_phone="+91-9432109876",
                district="Erode",
                language="tanglish",
                land_size=2.5,
                land_unit="acres",
                crop_types=["Turmeric", "Ginger"],
                soil_type="Sandy Loam",
                water_source="Open Well",
                open_well_depth_ft=35.0,
                motor_hp=1.5,
                power_supply_phase="Single Phase",
                power_hours_per_day=4.0,
                irrigation_type="Drip",
                budget_inr=75000.0,
                extracted_slots={
                    "land_size": 2.5, "land_unit": "acres",
                    "crop_types": ["Turmeric", "Ginger"], "soil_type": "Sandy Loam",
                    "water_source": "Open Well", "open_well_depth_ft": 35.0,
                    "motor_hp": 1.5, "power_supply_phase": "Single Phase",
                    "power_hours_per_day": 4.0, "irrigation_type": "Drip",
                    "budget_inr": 75000.0
                },
                conflicts=[],
                feasibility_score=79.0,
                feasibility_details={
                    "motor_adequacy": "Adequate for open well",
                    "water_sufficiency": "Adequate",
                    "power_coverage": "Sufficient",
                    "recommended_system": "Inline drip with 1.6 LPH drippers, 1.2m spacing for spice crops"
                },
                status="pending",
                submitted_at=datetime(2026, 9, 20, 8, 45, tzinfo=timezone.utc),
                created_at=datetime(2026, 9, 20, 8, 30, tzinfo=timezone.utc),
                updated_at=datetime(2026, 9, 20, 8, 45, tzinfo=timezone.utc),
            ),
        ]

        db.add_all(demo_records)
        db.commit()
        print("[AgriMind] DB seeded with 4 demo requirements.")
    except Exception as e:
        db.rollback()
        print(f"[AgriMind] Seed error (non-fatal): {e}")
    finally:
        db.close()
