# 🌿 AgriMind

**AI-Powered Multilingual Conversational System for Agricultural Requirement Analysis**

> Sri Ramakrishna Engineering College · Department of AI & Data Science · Batch 22AD1010

---

## 🚀 Quick Start

```bash
# 1. Navigate to the project folder
cd final_year_project

# 2. Run the launcher (installs deps + starts server automatically)
python run.py
```

Then open **http://localhost:8000** in your browser.

---

## 🌐 Features

### 👨‍🌾 Farmer Portal
- **Multilingual Chat**: Type or speak in **Tamil**, **English**, or **Tanglish** (Tamil-English mix)
- **Voice Input**: Web Speech API with `ta-IN` (Tamil) and `en-IN` (English) recognition
- **Real-time Slot Tracker**: Live visual tracker showing collected vs missing farm parameters
- **Guided Dialogue**: Adaptive questions to fill missing details
- **Engineering Conflict Warnings**: Instant alerts for motor HP mismatches, power insufficiency, soil-irrigation incompatibilities

### 🏢 Company Dashboard
- **KPI Overview**: Total submissions, pending, under review, feasible, quoted
- **Requirement Queue**: Searchable, filterable table of all submissions
- **Detail Drawer**: Full engineering analysis with feasibility scores and conflict breakdowns
- **Status Workflow**: Update requirement status (Pending → Under Review → Feasible → Quoted)
- **PDF Download**: One-click download of professional requirement reports

### 🤖 LLM Integration
| Provider | Details |
|---|---|
| **Google Gemini** | Primary LLM (`gemini-1.5-flash`) - best for Tamil |
| **OpenAI GPT** | Alternative (`gpt-4o-mini`) - highly accurate |
| **Local Engine** | Built-in rule-based NLP - works offline, no API key needed |

**To use Gemini or OpenAI**: Click the ⚙️ badge in the top-right navbar, select provider, paste your API key.

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│  Farmer Input (Tamil/English/Tanglish Voice or Text)            │
│           ↓                                                     │
│  NLU Extractor (Gemini/OpenAI/Local Rule-based)                 │
│           ↓                                                     │
│  Dialogue State Tracker (session memory, slot completion)       │
│           ↓                                                     │
│  Conflict Detector (engineering validation rules)               │
│           ↓                                                     │
│  Adaptive Questioner (multilingual follow-up generation)        │
│           ↓                                                     │
│  Requirement Repository (SQLite via SQLAlchemy)                 │
│           ↓                                                     │
│  PDF Report Generator (ReportLab)                               │
│           ↓                                                     │
│  Company Dashboard (FastAPI + Vanilla JS)                       │
└─────────────────────────────────────────────────────────────────┘
```

## 📁 Project Structure

```
final_year_project/
├── backend/
│   └── app/
│       ├── main.py               # FastAPI application
│       ├── api/
│       │   └── routes.py         # All API endpoints
│       ├── engine/
│       │   ├── nlu_extractor.py  # Multilingual NLU (Gemini/OpenAI/Local)
│       │   ├── dialogue_tracker.py # Session state management
│       │   ├── conflict_detector.py # Engineering rule validation
│       │   ├── adaptive_questioner.py # Question generation
│       │   └── pdf_generator.py  # PDF report generation
│       └── models/
│           ├── database.py       # SQLAlchemy models + seed data
│           └── schemas.py        # Pydantic request/response schemas
├── frontend/
│   ├── index.html               # Main SPA HTML
│   ├── css/styles.css           # Full design system
│   └── js/app.js                # Frontend logic
├── reports/                     # Generated PDF reports
├── requirements.txt             # Python dependencies
├── run.py                       # Single-command launcher
├── .env.example                 # Environment config template
└── README.md
```

## 🛠️ Manual Setup

```bash
# Install dependencies
pip install -r requirements.txt

# Copy and edit environment file
cp .env.example .env
# Edit .env to add your API keys if needed

# Start the server
uvicorn backend.app.main:app --host 0.0.0.0 --port 8000 --reload
```

## 🧪 Sample Tamil/Tanglish Test Phrases

| Input | Language | Expected Extraction |
|---|---|---|
| `எனக்கு 5 ஏக்கர் கரும்பு நிலம், போர்வெல் 350 அடி, 3 HP மோட்டார்` | Tamil | land=5 acres, crop=Sugarcane, borewell=350ft, motor=3HP |
| `4 acre banana farm, borewell 280 ft, single phase, drip venum` | Tanglish | land=4 acres, crop=Banana, borewell=280ft, irrigation=Drip |
| `12 acres paddy, canal water, three phase, 5 HP, sprinkler` | English | land=12 acres, crop=Paddy, water=Canal, motor=5HP, irrigation=Sprinkler |
| `2.5 acre turmeric ginger, open well 35 ft, 1.5 HP, drip system` | English | land=2.5 acres, crops=[Turmeric, Ginger], well=35ft, motor=1.5HP |

## 📋 API Endpoints

| Method | Endpoint | Description |
|---|---|---|
| `POST` | `/api/chat` | Process farmer conversation turn |
| `POST` | `/api/requirements/submit` | Submit final requirement |
| `GET` | `/api/requirements` | List all requirements (company dashboard) |
| `GET` | `/api/requirements/{id}` | Get requirement details |
| `GET` | `/api/requirements/{id}/pdf` | Download PDF report |
| `POST` | `/api/requirements/{id}/status` | Update workflow status |
| `GET` | `/api/stats` | Dashboard KPI statistics |
| `GET` | `/api/config/llm` | Get current LLM config |
| `POST` | `/api/config/llm` | Switch LLM provider |
| `GET` | `/api/docs` | Swagger API documentation |

---

*Developed for Final Year Project · SREC ADS · 2026*
