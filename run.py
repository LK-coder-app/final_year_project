#!/usr/bin/env python3
"""
AgriMind - Single-Command Launcher
Usage: python run.py

Installs dependencies, initializes DB, and starts the server.
"""
import os
import sys
import subprocess

BANNER = """
╔══════════════════════════════════════════════════════════════╗
║   🌿  AgriMind  ·  AI Agricultural Requirement System        ║
║   Sri Ramakrishna Engineering College · Dept. of AI & DS     ║
╚══════════════════════════════════════════════════════════════╝
"""

def run(cmd, **kwargs):
    return subprocess.run(cmd, shell=True, check=True, **kwargs)


def main():
    print(BANNER)

    # ── 1. Install dependencies ───────────────────────────────────────────────
    print("📦 Installing dependencies...")
    try:
        run(f'"{sys.executable}" -m pip install -r requirements.txt -q')
        print("✅ Dependencies installed.\n")
    except subprocess.CalledProcessError as e:
        print(f"⚠️  pip install failed: {e}")
        print("   Try running: pip install -r requirements.txt manually.\n")

    # ── 2. Create .env if missing ──────────────────────────────────────────────
    if not os.path.exists(".env") and os.path.exists(".env.example"):
        import shutil
        shutil.copy(".env.example", ".env")
        print("📝 Created .env from .env.example (default: Local Engine mode).\n")

    # ── 3. Create reports dir ─────────────────────────────────────────────────
    os.makedirs("reports", exist_ok=True)

    # ── 4. Start server ───────────────────────────────────────────────────────
    host = os.getenv("APP_HOST", "0.0.0.0")
    port = int(os.getenv("APP_PORT", "8000"))

    print(f"🚀 AgriMind Unified Server running at http://localhost:{port}")
    print(f"   🌾 Farmer Portal (Flutter):   http://localhost:{port}/")
    print(f"   🛡️  Admin Dashboard (Flutter): http://localhost:{port}/admin")
    print(f"   📖 REST API Docs:             http://localhost:{port}/api/docs")
    print(f"\n   ☁️  For 24/7 Cloud Hosting without terminal: see DEPLOYMENT_RENDER.md")
    print(f"   Press Ctrl+C to stop.\n")
    print("─" * 64)

    try:
        run(
            f'"{sys.executable}" -m uvicorn backend.app.main:app '
            f'--host {host} --port {port} --reload',
        )
    except KeyboardInterrupt:
        print("\n\n👋 AgriMind server stopped. Goodbye!")
    except subprocess.CalledProcessError as e:
        print(f"\n❌ Server failed to start: {e}")
        print("   Make sure you are running this from the project root directory.")
        sys.exit(1)


if __name__ == "__main__":
    main()
