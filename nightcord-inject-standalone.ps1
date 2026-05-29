param(
    [switch]$Uninstall,
    [switch]$Help,
    [string]$Channel = "Discord"
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$DistDir = Join-Path $ScriptDir "dist" "desktop"
$PatcherFile = Join-Path $DistDir "patcher.js"
$Channels = @("Discord", "DiscordPTB", "DiscordCanary", "DiscordDevelopment")

if ($Help) {
    Write-Host "Nightcord Injector - Standalone"
    Write-Host ""
    Write-Host "Usage:"
    Write-Host "  .\nightcord-inject-standalone.ps1              Inject into all Discord installations"
    Write-Host "  .\nightcord-inject-standalone.ps1 -Uninstall   Uninject Nightcord"
    Write-Host "  .\nightcord-inject-standalone.ps1 -Channel DiscordPTB  Inject only into Discord PTB"
    exit 0
}

function Find-DiscordResources {
    $results = @()
    $localAppData = $env:LOCALAPPDATA
    $channels = if ($Channel -eq "All") { $Channels } else { @($Channel) }

    foreach ($ch in $channels) {
        $base = Join-Path $localAppData $ch
        if (-not (Test-Path $base)) { continue }
        try {
            $versions = Get-ChildItem $base -Directory | Where-Object { $_.Name -match "^app-\d+\.\d+\.\d+$" } | Sort-Object Name -Descending
            foreach ($ver in $versions) {
                $res = Join-Path $ver.FullName "resources"
                $asar = Join-Path $res "app.asar"
                $appDir = Join-Path $res "app"
                $backup = Join-Path $res "_app.asar"
                if (Test-Path $asar -PathType Leaf -or (Test-Path $appDir) -or (Test-Path $backup)) {
                    $results += @{
                        Path = $res
                        Channel = $ch
                        Version = $ver.Name -replace "^app-", ""
                        ExeName = if ($ch -eq "Discord") { "Discord.exe" } else { "${ch}.exe" }
                    }
                }
            }
        } catch {}
    }
    return $results
}

function Kill-Discord {
    param($ExeName)
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($ExeName)
    try {
        $procs = Get-Process -Name $baseName -ErrorAction SilentlyContinue
        if ($procs) {
            Write-Host "    Closing $baseName..."
            $procs | Stop-Process -Force
            Start-Sleep -Seconds 2
        }
    } catch {}
}

function Start-Discord {
    param($resourcesPath, $exeName)
    try {
        $appBase = Split-Path $resourcesPath -Parent
        $updateExe = Join-Path $appBase "Update.exe"
        if (Test-Path $updateExe) {
            Start-Process -FilePath $updateExe -ArgumentList "--processStart", $exeName -WindowStyle Hidden
        } else {
            $discordExe = Join-Path $appBase $exeName
            if (Test-Path $discordExe) {
                Start-Process -FilePath $discordExe
            }
        }
    } catch {}
}

function Inject {
    param($resourcesPath)

    $appAsar = Join-Path $resourcesPath "app.asar"
    $backup = Join-Path $resourcesPath "_app.asar"
    $appDir = Join-Path $resourcesPath "app"
    $pkgFile = Join-Path $appDir "package.json"

    # Already injected check
    if ((Test-Path $appDir) -and (Test-Path $pkgFile)) {
        try {
            $pkg = Get-Content $pkgFile -Raw | ConvertFrom-Json
            if ($pkg.name -eq "nightcord") {
                Write-Host "  Already injected. Re-injecting..."
            }
        } catch {}
    }

    if (-not (Test-Path $PatcherFile)) {
        Write-Host "  [ERROR] patcher.js not found at: $PatcherFile" -ForegroundColor Red
        Write-Host "  Build the project first: pnpm build" -ForegroundColor Yellow
        return $false
    }

    # Kill Discord
    Kill-Discord -ExeName $resourcesExeName

    # Backup app.asar
    if ((Test-Path $appAsar) -and -not (Test-Path $backup)) {
        Write-Host "    Backing up app.asar -> _app.asar..."
        Move-Item $appAsar $backup -Force
    } elseif (-not (Test-Path $backup)) {
        Write-Host "  [WARN] No app.asar or _app.asar found at $resourcesPath" -ForegroundColor Yellow
    }

    # Remove old app dir
    if (Test-Path $appDir) {
        Remove-Item $appDir -Recurse -Force
    }

    # Create loader
    New-Item -ItemType Directory -Force -Path $appDir | Out-Null
    $patcherPath = $PatcherFile.Replace("\", "/")
    $indexJs = @"
"use strict";
const path = require("path");
const fs = require("fs");
const patcherPath = "${patcherPath}";
if (fs.existsSync(patcherPath)) {
    require(patcherPath);
} else {
    const fallback = path.join(path.dirname(process.execPath), "dist", "patcher.js");
    if (fs.existsSync(fallback)) {
        require(fallback);
    } else {
        console.error("[Nightcord] patcher.js not found at: " + patcherPath);
    }
}
"@
    Set-Content -Path (Join-Path $appDir "package.json") -Value '{"name":"nightcord","main":"index.js"}'
    Set-Content -Path (Join-Path $appDir "index.js") -Value $indexJs

    Write-Host "  [OK] Nightcord injected!" -ForegroundColor Green
    return $true
}

function Uninject {
    param($resourcesPath)

    $appAsar = Join-Path $resourcesPath "app.asar"
    $backup = Join-Path $resourcesPath "_app.asar"
    $appDir = Join-Path $resourcesPath "app"
    $pkgFile = Join-Path $appDir "package.json"

    Kill-Discord -ExeName $resourcesExeName

    # Remove our injection
    if ((Test-Path $appDir) -and (Test-Path $pkgFile)) {
        try {
            $pkg = Get-Content $pkgFile -Raw | ConvertFrom-Json
            if ($pkg.name -eq "nightcord") {
                Write-Host "    Removing injected app/ folder..."
                Remove-Item $appDir -Recurse -Force
            }
        } catch {}
    }

    # Restore backup
    if ((Test-Path $backup) -and -not (Test-Path $appAsar)) {
        Write-Host "    Restoring _app.asar -> app.asar..."
        Move-Item $backup $appAsar -Force
    } elseif (Test-Path $backup) {
        # Both exist - Discord updated itself, remove stale backup
        Remove-Item $backup -Force
    }

    Write-Host "  [OK] Nightcord uninjected!" -ForegroundColor Green
}

# ── Main ──────────────────────────────────────────────────────────────────
Clear-Host
Write-Host "  ╔══════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "  ║       NIGHTCORD  STANDALONE  INJECTOR    ║" -ForegroundColor Cyan
Write-Host "  ╚══════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

$found = Find-DiscordResources

if ($found.Count -eq 0) {
    Write-Host "No Discord installations found in AppData\Local." -ForegroundColor Red
    exit 1
}

$counter = 0
foreach ($f in $found) {
    $counter++
    $channelName = $f.Channel
    if ($channelName -eq "Discord") { $channelName = "Discord Stable" }
    Write-Host "  [$counter/$($found.Count)] $channelName v$($f.Version)" -ForegroundColor Yellow
    Write-Host "    Path: $($f.Path)"

    if ($Uninstall) {
        Uninject -resourcesPath $f.Path
    } else {
        Inject -resourcesPath $f.Path
    }

    Write-Host ""
}

# Restart Discord
Write-Host "  Restarting Discord..." -ForegroundColor DarkGray
$first = $found[0]
Start-Discord -resourcesPath $first.Path -exeName $first.ExeName

Write-Host ""
Write-Host "  Done!" -ForegroundColor Green
