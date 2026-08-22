@echo off
setlocal EnableDelayedExpansion

cd /d "%~dp0"

echo ==========================================
echo  AI Resume Analyzer - Gemini Ready Runner
echo ==========================================
echo.

set APP_PORT=5000
set APP_URL=http://127.0.0.1:%APP_PORT%
set HEALTH_URL=http://127.0.0.1:%APP_PORT%/health

if not exist ".venv\Scripts\python.exe" (
    echo Creating virtual environment...
    python -m venv .venv
    if errorlevel 1 (
        echo Failed to create virtual environment. Make sure Python is installed and added to PATH.
        pause
        exit /b 1
    )
)

if not exist ".env" (
    echo Creating .env from .env.example...
    copy ".env.example" ".env" > nul
)

echo Preparing Gemini-only configuration...
".venv\Scripts\python.exe" -c "from pathlib import Path; p=Path('.env'); lines=p.read_text(encoding='utf-8').splitlines() if p.exists() else []; data={}; order=[]; [order.append(x.split('=',1)[0]) or data.__setitem__(x.split('=',1)[0], x.split('=',1)[1]) for x in lines if '=' in x and not x.lstrip().startswith('#')]; data['AI_PROVIDER']='gemini'; data['REQUIRE_AI_ANALYSIS']='1'; data['OPENAI_API_KEY']=''; data.setdefault('GEMINI_MODEL','gemini-3.6-flash'); data.setdefault('GEMINI_OCR_MODEL', data.get('GEMINI_MODEL','gemini-3.6-flash')); data.setdefault('GEMINI_API_KEY',''); keys=[]; [keys.append(k) for k in order if k in data and k not in keys]; [keys.append(k) for k in ['AI_PROVIDER','REQUIRE_AI_ANALYSIS','GEMINI_API_KEY','GEMINI_MODEL','GEMINI_OCR_MODEL','OPENAI_API_KEY'] if k not in keys]; p.write_text('\n'.join(f'{k}={data[k]}' for k in keys) + '\n', encoding='utf-8')"
if errorlevel 1 (
    echo Failed to prepare .env.
    pause
    exit /b 1
)

set AI_PROVIDER=gemini
set REQUIRE_AI_ANALYSIS=1
set OPENAI_API_KEY=

echo Checking Python packages...
".venv\Scripts\python.exe" -c "import flask, flask_sqlalchemy, dotenv, pymysql; from google import genai" > nul 2> nul
if errorlevel 1 (
    echo Installing required packages. This may take a few minutes on first run...
    ".venv\Scripts\python.exe" -m pip install --upgrade pip
    ".venv\Scripts\python.exe" -m pip install -r requirements.txt
    if errorlevel 1 (
        echo.
        echo Dependency installation failed.
        echo Try installing Python 3.12 or 3.13 if Python package wheels fail on your PC.
        pause
        exit /b 1
    )
)

echo Checking Gemini API key and model access...
".venv\Scripts\python.exe" -c "import os; from dotenv import load_dotenv; load_dotenv('.env'); assert os.getenv('AI_PROVIDER') == 'gemini', 'AI_PROVIDER must be gemini'; key=os.getenv('GEMINI_API_KEY','').strip(); assert key, 'GEMINI_API_KEY is missing in .env'; from google import genai; client=genai.Client(api_key=key); first=next(iter(client.models.list()), None); assert first, 'Gemini API did not return models'; print('Gemini preflight passed')"
if errorlevel 1 (
    echo.
    echo Gemini setup failed. Add a valid GEMINI_API_KEY in .env, then run this file again.
    echo Scores, ATS estimate, job match, and report are configured to require Gemini AI.
    pause
    exit /b 1
)

for /f "tokens=5" %%p in ('netstat -ano ^| findstr /R /C:":5000 .*LISTENING"') do set APP_PID=%%p
if defined APP_PID (
    echo Port 5000 is already in use by process ID %APP_PID%.
    echo Checking whether the resume analyzer is already running...
    ".venv\Scripts\python.exe" -c "import urllib.request; urllib.request.urlopen('%HEALTH_URL%', timeout=3).read()" > nul 2> nul
    if errorlevel 1 (
        echo.
        echo Port 5000 is busy. Trying port 5001 instead...
        set APP_PORT=5001
        set APP_URL=http://127.0.0.1:!APP_PORT!
        set HEALTH_URL=http://127.0.0.1:!APP_PORT!/health
        netstat -ano | findstr /R /C:":5001 .*LISTENING" > nul
        if not errorlevel 1 (
            echo Port 5001 is also busy. Close the old process from Task Manager, then run again.
            pause
            exit /b 1
        )
    ) else (
        echo App is already running. Opening browser...
        start "" "!APP_URL!"
        ping -n 3 127.0.0.1 > nul
        exit /b 0
    )
)

".venv\Scripts\python.exe" -c "from app import create_app; create_app(); print('App check passed')" > nul 2> nul
if errorlevel 1 (
    echo.
    echo App startup check failed. Running once to show the real error:
    ".venv\Scripts\python.exe" app.py
    pause
    exit /b 1
)

set FLASK_DEBUG=0
set FLASK_RUN_HOST=127.0.0.1
set FLASK_RUN_PORT=%APP_PORT%

echo.
echo Starting Flask app in Gemini-only AI mode...
echo Scores, ATS estimate, job match, and report require Gemini AI.
echo Open this URL in your browser:
echo %APP_URL%
echo.
echo Admin login:
echo Email: admin@example.com
echo Password: admin123
echo.

start "" "%APP_URL%"
".venv\Scripts\python.exe" app.py

pause
