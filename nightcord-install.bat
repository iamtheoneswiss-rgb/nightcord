@echo off
title Nightcord — Installation
cd /d "%~dp0"

:: Use local standalone installer (fully offline, no GitHub needed)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0nightcord-install.ps1"
if %errorlevel% neq 0 pause
