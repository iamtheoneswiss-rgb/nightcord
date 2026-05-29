@echo off
title Nightcord — One-Click Installer
cd /d "%~dp0"

echo.
echo  ╔══════════════════════════════════════════╗
echo  ║       NIGHTCORD  ONE-CLICK  INSTALLER    ║
echo  ╚══════════════════════════════════════════╝
echo.

:: Step 1: Build if needed
if not exist "dist\desktop\patcher.js" (
    echo  [STEP 1/3] Building Nightcord...
    call pnpm build
    if %errorlevel% neq 0 (
        echo  [ERROR] Build failed. Need Node.js + pnpm.
        pause
        exit /b 1
    )
) else (
    echo  [STEP 1/3] Build found, skipping.
)

echo.
echo  [STEP 2/3] Injecting into Discord...

:: Run the standalone installer (fully offline, no GitHub calls)
powershell -NoProfile -ExecutionPolicy Bypass -File "nightcord-install.ps1"
if %errorlevel% neq 0 (
    echo  [ERROR] Injection failed.
    pause
    exit /b 1
)

echo.
echo  [STEP 3/3] Starting Discord...
set "DISCORD_PATH=%LOCALAPPDATA%\Discord"
if exist "%DISCORD_PATH%\Update.exe" (
    start "" "%DISCORD_PATH%\Update.exe" --processStart Discord.exe
) else (
    for /f "delims=" %%i in ('dir /b /ad /o-n "%DISCORD_PATH%\app-*" 2^>nul') do (
        start "" "%DISCORD_PATH%\%%i\Discord.exe"
        goto :done
    )
)
:done

echo.
echo  ╔══════════════════════════════════════════════════════╗
echo  ║  Nightcord installed successfully!                   ║
echo  ║  Restart Discord if it didn't open automatically.    ║
echo  ╚══════════════════════════════════════════════════════╝
echo.
timeout /t 5 /nobreak >nul
