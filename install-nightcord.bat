@echo off
title Nightcord — One-Click Installer
cd /d "%~dp0"

echo.
echo  ╔══════════════════════════════════════════╗
echo  ║       NIGHTCORD  ONE-CLICK  INSTALLER    ║
echo  ╚══════════════════════════════════════════╝
echo.

:: Check for dist files
if not exist "dist\desktop\patcher.js" (
    echo  [STEP 1/3] Building Nightcord...
    call pnpm build
    if %errorlevel% neq 0 (
        echo  [ERROR] Build failed. Make sure Node.js and pnpm are installed.
        pause
        exit /b 1
    )
) else (
    echo  [STEP 1/3] Build already exists, skipping.
)

echo.
echo  [STEP 2/3] Injecting into Discord...

:: Kill Discord first
echo     Closing Discord...
taskkill /F /IM Discord.exe /T >nul 2>&1
taskkill /F /IM DiscordPTB.exe /T >nul 2>&1
taskkill /F /IM DiscordCanary.exe /T >nul 2>&1
timeout /t 3 /nobreak >nul

:: Try C# installer first if it exists
if exist "installer-src\bin\publish\Nightcord-Installer.exe" (
    echo     Running Nightcord Installer...
    start "" "installer-src\bin\publish\Nightcord-Installer.exe"
    echo.
    echo  The installer window should open.
    echo  Select your Discord installation and click Inject.
    echo.
    pause
    exit /b 0
)

:: Fallback to standalone injector
powershell -NoProfile -ExecutionPolicy Bypass -File "nightcord-inject-standalone.ps1"
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
echo  ║  Restart Discord if it didn't open automatically.     ║
echo  ╚══════════════════════════════════════════════════════╝
echo.
timeout /t 5 /nobreak >nul
