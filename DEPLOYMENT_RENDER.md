# 🚀 AgriMind 24/7 Cloud Backend Deployment Guide (Render)

This guide walks you through deploying the AgriMind backend to **Render** so it runs **24/7 continuously in the cloud** without needing your computer or terminal to be on.

---

## 🌟 Why Render?
- **Free Tier available** (runs 24/7 with zero cost).
- **Automatic HTTPS / SSL** certificate included.
- **Auto-deploys** on every `git push`.
- Native Docker support or Python environment.
- Public URL: `https://your-app-name.onrender.com`.

---

## 📋 Step-by-Step Deployment Instructions

### Step 1: Push Project to GitHub
1. Initialize a git repository if you haven't already:
   ```bash
   git init
   git add .
   git commit -m "AgriMind 24/7 deployment ready"
   ```
2. Create a new repository on [GitHub](https://github.com/new) (public or private).
3. Push your code:
   ```bash
   git remote add origin https://github.com/<your-username>/<your-repo-name>.git
   git branch -M main
   git push -u origin main
   ```

---

### Step 2: Create a Web Service on Render
1. Go to [https://dashboard.render.com](https://dashboard.render.com) and sign in (you can sign in with your GitHub account).
2. Click **New +** in the top right corner and choose **Web Service**.
3. Select **"Build and deploy from a Git repository"** and click **Next**.
4. Connect your GitHub account and select your `agrimind` repository.

---

### Step 3: Configure the Web Service
Fill in the following settings:
- **Name**: `agrimind-backend` (or any name you like)
- **Region**: Select closest to your users (e.g. `Singapore` or `Frankfurt`)
- **Branch**: `main`
- **Runtime**: **Docker** (Render will automatically detect the [Dockerfile](Dockerfile))
- **Instance Type**: **Free**

---

### Step 4: Add Environment Variables
Under the **Environment Variables** section in the Render dashboard, click **Add Environment Variable** for each:

| Key | Recommended Value | Notes |
|---|---|---|
| `LLM_PROVIDER` | `gemini` (or `local`) | AI extraction engine |
| `GEMINI_API_KEY` | `your_actual_gemini_key` | From [Google AI Studio](https://aistudio.google.com/app/apikey) |
| `GEMINI_MODEL` | `gemini-1.5-flash` | Fast & accurate |
| `APP_BASE_URL` | `https://agrimind-backend.onrender.com` | Your Render web service URL |
| `TWILIO_ACCOUNT_SID` | *(Optional)* | For SMS follow-up alerts |
| `TWILIO_AUTH_TOKEN` | *(Optional)* | Twilio auth token |
| `TWILIO_FROM_NUMBER` | *(Optional)* | Twilio phone number |

---

### Step 5: Click "Deploy Web Service"
1. Click **Create Web Service**.
2. Render will build the Docker container and start your FastAPI service.
3. Once the build completes, you will see a green **"Live"** badge!
4. Your API is now live 24/7 at:
   - **Health Check**: `https://<your-app>.onrender.com/api/health`
   - **Swagger Docs**: `https://<your-app>.onrender.com/api/docs`
   - **Farmer Portal**: `https://<your-app>.onrender.com/`
   - **Admin Dashboard**: `https://<your-app>.onrender.com/admin.html` (or your Flutter admin URL)

---

## 🔄 Connecting Your Flutter Apps to Render Backend

In both Flutter web apps:
- Set your `API_BASE` URL in `lib/api_service.dart`:
  ```dart
  static const String baseUrl = 'https://<your-app>.onrender.com/api';
  ```
- Because CORS is configured with `allow_origins=["*"]`, your Flutter apps can connect from localhost, Vercel, Firebase Hosting, or anywhere!
