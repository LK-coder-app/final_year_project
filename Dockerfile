# AgriMind 24/7 Production Dockerfile for Render / Cloud Deployment
FROM python:3.10-slim

# Set working directory
WORKDIR /app

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PORT=8000 \
    APP_HOST=0.0.0.0

# Install system dependencies (including fonts for ReportLab PDF generation)
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    curl \
    fontconfig \
    libfreetype6 \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements and install python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# Copy backend code, frontend, and config
COPY backend/ ./backend/
COPY frontend/ ./frontend/
COPY agrimind_farmer_flutter/build/web/ ./agrimind_farmer_flutter/build/web/
COPY agrimind_admin_flutter/build/web/ ./agrimind_admin_flutter/build/web/
COPY reports/ ./reports/
COPY .env.example ./.env.example

# Create directory for persistent reports & database
RUN mkdir -p /app/reports

# Expose default port (Render will override via $PORT environment variable)
EXPOSE 8000

# Start Uvicorn production server with dynamic port binding for Render
CMD uvicorn backend.app.main:app --host 0.0.0.0 --port ${PORT:-8000}
