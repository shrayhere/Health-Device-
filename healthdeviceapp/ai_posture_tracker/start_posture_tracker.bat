@echo off
title HealthDevice AI Webcam Posture Tracker
echo =========================================================
echo    HealthDevice AI - Real-Time Webcam Posture Tracker
echo =========================================================
echo  [C] Calibrate Neutral Baseline
echo  [B] Toggle Audio Beep Alert
echo  [Q] Exit Tracker
echo.
echo Connecting to webcam and starting telemetry bridge...
cd /d "%~dp0"
python posture_tracker.py
pause
