@echo off
cd /d "%~dp0"
set "EXE="

:: 1. Check pythonw in PATH
pythonw --version >nul 2>&1
if %errorlevel% equ 0 set "EXE=pythonw"

:: 2. Check local AppData
if not defined EXE (
    for /d %%D in ("%LOCALAPPDATA%\Programs\Python\Python3*") do (
        if exist "%%D\pythonw.exe" set "EXE="%%D\pythonw.exe""
    )
)

:: 3. Check Program Files
if not defined EXE (
    for /d %%D in ("%ProgramFiles%\Python3*") do (
        if exist "%%D\pythonw.exe" set "EXE="%%D\pythonw.exe""
    )
)

:: 4. Fallback to python
if not defined EXE set "EXE=python"

if exist "ai_posture_tracker\posture_tracker.py" (
    cd ai_posture_tracker
    start "" !EXE! posture_tracker.py --window
) else if exist "posture_tracker.py" (
    start "" !EXE! posture_tracker.py --window
) else (
    echo [ERROR] posture_tracker.py not found.
    pause
)
