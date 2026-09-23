"""
AgriMind - FastAPI Application Entry Point
"""
from __future__ import annotations

import os
from pathlib import Path

from dotenv import load_dotenv
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

# Load .env file
load_dotenv()

from .models.database import init_db
from .api.routes import router

# ─── App Factory ──────────────────────────────────────────────────────────────

app = FastAPI(
    title="AgriMind API",
    description="AI-Powered Multilingual Conversational System for Agricultural Requirement Analysis",
    version="1.0.0",
    docs_url="/api/docs",
    redoc_url="/api/redoc",
)

# CORS - allow all origins for local development
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ─── API Routes ───────────────────────────────────────────────────────────────
app.include_router(router, prefix="/api")

# ─── Static Frontend / Flutter Web ────────────────────────────────────────────
PROJECT_ROOT = Path(__file__).resolve().parent.parent.parent
FARMER_WEB_DIR = PROJECT_ROOT / "agrimind_farmer_flutter" / "build" / "web"
ADMIN_WEB_DIR = PROJECT_ROOT / "agrimind_admin_flutter" / "build" / "web"
LEGACY_FLUTTER_DIR = PROJECT_ROOT / "agrimind_flutter" / "build" / "web"
FRONTEND_DIR = PROJECT_ROOT / "frontend"
REPORTS_DIR = PROJECT_ROOT / "reports"

if REPORTS_DIR.exists():
    app.mount("/reports", StaticFiles(directory=str(REPORTS_DIR)), name="reports_static")

from fastapi.responses import FileResponse, RedirectResponse

# Direct endpoint for Google-styled Missing Data Form
@app.get("/form", include_in_schema=False)
@app.get("/form.html", include_in_schema=False)
def serve_form():
    form_file = FRONTEND_DIR / "form.html"
    if form_file.exists():
        return FileResponse(str(form_file))
    raise HTTPException(status_code=404, detail="Form page not found")

# Mount Admin Flutter web if built
if ADMIN_WEB_DIR.exists():
    print(f"[AgriMind] Mounting Admin Flutter Web from {ADMIN_WEB_DIR}")

    @app.get("/admin", include_in_schema=False)
    def admin_redirect():
        return RedirectResponse(url="/admin/")

    app.mount("/admin", StaticFiles(directory=str(ADMIN_WEB_DIR), html=True), name="admin_flutter")

# Mount Farmer Flutter web at root if built, otherwise fallback to HTML frontend
if FARMER_WEB_DIR.exists():
    print(f"[AgriMind] Mounting Farmer Flutter Web from {FARMER_WEB_DIR}")
    app.mount("/", StaticFiles(directory=str(FARMER_WEB_DIR), html=True), name="farmer_flutter")
elif FRONTEND_DIR.exists():
    print(f"[AgriMind] Mounting HTML frontend from {FRONTEND_DIR}")
    app.mount("/", StaticFiles(directory=str(FRONTEND_DIR), html=True), name="frontend")
elif LEGACY_FLUTTER_DIR.exists():
    print(f"[AgriMind] Mounting Flutter Web from {LEGACY_FLUTTER_DIR}")
    app.mount("/", StaticFiles(directory=str(LEGACY_FLUTTER_DIR), html=True), name="legacy_flutter")

# ─── Startup ──────────────────────────────────────────────────────────────────
@app.on_event("startup")
async def on_startup():
    print("[AgriMind] Starting up...")
    init_db()
    print("[AgriMind] Database initialized and seeded.")
    print(f"[AgriMind] LLM Provider: {os.getenv('LLM_PROVIDER', 'local')}")
    print("[AgriMind] API is ready!")
