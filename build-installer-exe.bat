@echo off
title Nightcord — Build Installer
cd /d "%~dp0"

echo.
echo  Building Nightcord C# Installer...
echo  =================================
echo.

:: Restore NuGet packages
echo  [1/2] Restoring packages...
dotnet restore installer-src\NightcordInstaller.csproj
if %errorlevel% neq 0 (
    echo  [ERROR] Package restore failed.
    pause
    exit /b 1
)

:: Publish the installer as a single-file EXE
echo  [2/2] Publishing installer...
dotnet publish installer-src\NightcordInstaller.csproj ^
  -c Release ^
  -r win-x64 ^
  --self-contained false ^
  -p:PublishSingleFile=true ^
  -o installer-src\bin\publish
if %errorlevel% neq 0 (
    echo  [ERROR] Build failed.
    pause
    exit /b 1
)

echo.
echo  [OK] Build successful!
echo  Output: installer-src\bin\publish\Nightcord-Installer.exe
echo.
dir /b installer-src\bin\publish\Nightcord-Installer.exe
echo.
pause
