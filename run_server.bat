@echo off
cd /d "%~dp0"
echo Starting GlycoLens FastAPI backend on http://0.0.0.0:8000 ...
backend\venv\Scripts\python.exe -m uvicorn app.main:app --app-dir backend --reload --host 0.0.0.0 --port 8000

pause
