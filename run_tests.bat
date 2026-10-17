@echo off
cd /d "%~dp0"
echo Running GlycoLens test suite...
backend\venv\Scripts\python.exe -m pytest -v
pause
