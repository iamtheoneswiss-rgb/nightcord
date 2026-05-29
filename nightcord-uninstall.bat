@echo off
title Nightcord — Uninstallation
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0nightcord-uninstall.ps1"
if %errorlevel% neq 0 pause
