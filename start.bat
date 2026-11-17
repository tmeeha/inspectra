@echo off
title Violin Acoustic Spectrum Analyzer - local server
rem Double-click to start the app: serves this folder on localhost (this computer only) and opens the browser.
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0serve.ps1" %*
if errorlevel 1 pause
