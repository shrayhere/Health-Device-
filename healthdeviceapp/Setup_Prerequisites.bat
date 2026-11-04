@echo off
setlocal enabledelayedexpansion
title HealthDevice AI Posture Tracker - Prerequisites Setup

set "IS_SILENT=0"
if /i "%~1"=="/auto" set "IS_SILENT=1"
if /i "%~1"=="/silent" set "IS_SILENT=1"
if /i "%~1"=="--auto" set "IS_SILENT=1"
if /i "%~1"=="-s" set "IS_SILENT=1"

echo ========================================================================
echo        HealthDevice AI Posture Tracker - Prerequisites Setup
echo ========================================================================
echo.

set "PY_CMD="

:: Check candidates one by one for working Python + pip

:: 1. Try py launcher
py -3 --version >nul 2>&1
if %errorlevel% equ 0 (
    set "CANDIDATE=py -3"
    call :VERIFY_PYTHON "!CANDIDATE!"
    if defined PY_CMD goto :FOUND_WORKING_PYTHON
)

:: 2. Try standard local AppData installations
for /d %%D in ("%LOCALAPPDATA%\Programs\Python\Python3*") do (
    if exist "%%D\python.exe" (
        set "CANDIDATE="%%D\python.exe""
        call :VERIFY_PYTHON "!CANDIDATE!"
        if defined PY_CMD goto :FOUND_WORKING_PYTHON
    )
)

:: 3. Try standard Program Files installations
for /d %%D in ("%ProgramFiles%\Python3*") do (
    if exist "%%D\python.exe" (
        set "CANDIDATE="%%D\python.exe""
        call :VERIFY_PYTHON "!CANDIDATE!"
        if defined PY_CMD goto :FOUND_WORKING_PYTHON
    )
)

:: 4. Try root C:\Python installations
for /d %%D in ("C:\Python3*") do (
    if exist "%%D\python.exe" (
        set "CANDIDATE="%%D\python.exe""
        call :VERIFY_PYTHON "!CANDIDATE!"
        if defined PY_CMD goto :FOUND_WORKING_PYTHON
    )
)

:: 5. Try python in PATH
python --version >nul 2>&1
if %errorlevel% equ 0 (
    set "CANDIDATE=python"
    call :VERIFY_PYTHON "!CANDIDATE!"
    if defined PY_CMD goto :FOUND_WORKING_PYTHON
)

:: If we reached here, no Python with working pip was found!
goto :INSTALL_OFFICIAL_PYTHON

:: Subroutine to test if a candidate has working pip or can bootstrap pip
:VERIFY_PYTHON
set "TEST_EXE=%~1"
%TEST_EXE% -m pip --version >nul 2>&1
if %errorlevel% equ 0 (
    set "PY_CMD=%TEST_EXE%"
    exit /b 0
)
:: Try bootstrapping pip via ensurepip
%TEST_EXE% -m ensurepip --upgrade >nul 2>&1
%TEST_EXE% -m pip --version >nul 2>&1
if %errorlevel% equ 0 (
    set "PY_CMD=%TEST_EXE%"
    exit /b 0
)
exit /b 1

:INSTALL_OFFICIAL_PYTHON
echo [!] A working Python distribution with pip was not found.
echo.

if "%IS_SILENT%"=="1" (
    echo Auto-installing official Python 3.11 in silent mode...
    goto :DO_DOWNLOAD_PYTHON
)

echo Would you like to automatically download and install official Python 3.11 now?
echo Press [Y] for Automatic Install (Recommended), or [M] for Manual Download, or [N] to Cancel.
set /p USER_CHOICE="Your choice (Y/M/N) [Default=Y]: "
if "!USER_CHOICE!"=="" set "USER_CHOICE=Y"
if /i "!USER_CHOICE!"=="M" (
    echo Opening https://www.python.org/downloads/ ...
    start https://www.python.org/downloads/
    echo Please install Python with '[X] Add python.exe to PATH' and run this setup again.
    pause
    exit /b 1
)
if /i "!USER_CHOICE!"=="N" (
    echo Setup cancelled.
    exit /b 1
)

:DO_DOWNLOAD_PYTHON
echo.
echo Downloading official Python 3.11.9 (64-bit) installer...
set "PY_INSTALLER=%TEMP%\python-3.11.9-amd64.exe"
curl.exe -L -sS -o "%PY_INSTALLER%" "https://www.python.org/ftp/python/3.11.9/python-3.11.9-amd64.exe"
if %errorlevel% neq 0 (
    echo [ERROR] Failed to download Python installer. Please check your internet connection.
    if "%IS_SILENT%"=="0" pause
    exit /b 1
)

echo Installing Python 3.11 silently...
start /wait "" "%PY_INSTALLER%" /quiet InstallAllUsers=0 PrependPath=1 Include_test=0 Include_pip=1 SimpleInstall=1
del "%PY_INSTALLER%" >nul 2>&1

:: Refresh PATH search for the newly installed Python
for /d %%D in ("%LOCALAPPDATA%\Programs\Python\Python311*") do (
    if exist "%%D\python.exe" (
        set "PY_CMD="%%D\python.exe""
        goto :FOUND_WORKING_PYTHON
    )
)

:: Re-check PATH
python --version >nul 2>&1
if %errorlevel% equ 0 (
    set "PY_CMD=python"
    goto :FOUND_WORKING_PYTHON
)

echo [ERROR] Python installation completed but could not be located.
if "%IS_SILENT%"=="0" pause
exit /b 1

:FOUND_WORKING_PYTHON
echo [OK] Using Python:
!PY_CMD! --version
echo.

echo Installing required AI computer vision libraries (OpenCV, MediaPipe, Pygame)...
echo This may take 1-2 minutes depending on your internet connection.
echo.

!PY_CMD! -m pip install --upgrade pip >nul 2>&1
!PY_CMD! -m pip install opencv-python mediapipe pygame-ce

if %errorlevel% neq 0 (
    echo.
    echo [!] Retrying package installation with basic options...
    !PY_CMD! -m pip install opencv-python mediapipe pygame-ce
)

echo.
echo ========================================================================
echo  Setup Complete! AI Posture Tracker prerequisites are ready.
echo  You can now launch "Health Device.exe" or use the AI Posture Tracker.
echo ========================================================================
echo.

if "%IS_SILENT%"=="0" (
    pause
)

exit /b 0
