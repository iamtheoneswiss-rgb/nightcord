# ==============================================================================
#  Nightcord - Installer (PowerShell, fully offline capable)
#
#  Injects Nightcord into Discord with NO external downloads.
#  Uses local dist/ files if available, falls back to GitHub Releases.
#
#  Usage: Right-click - Run with PowerShell
# ==============================================================================

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$LocalDist = Join-Path (Join-Path $ScriptRoot "dist") "desktop"
$InstallDir = Join-Path $env:LOCALAPPDATA "Nightcord"
$DistDir = Join-Path $InstallDir "dist"
$Repo = "iamtheoneswiss-rgb/nightcord"

function Write-Banner {
    Clear-Host
    Write-Host ""
    Write-Host "  NIGHTCORD INSTALLER" -ForegroundColor Cyan
    Write-Host "  Full offline mode`n" -ForegroundColor DarkCyan
}

function Write-OK($m) { Write-Host "  [OK] $m" -ForegroundColor Green }
function Write-Fail($m) { Write-Host "`n  [ERROR] $m`n" -ForegroundColor Red; $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown"); exit 1 }

function Find-Discord {
    $results = @()
    foreach ($ch in @("Discord","DiscordPTB","DiscordCanary","DiscordDevelopment")) {
        $base = Join-Path $env:LOCALAPPDATA $ch
        if (-not (Test-Path $base)) { continue }
        $versions = Get-ChildItem $base -Directory -Filter "app-*" | Sort-Object Name -Descending
        foreach ($ver in $versions) {
            $res = Join-Path $ver.FullName "resources"
            if ((Test-Path (Join-Path $res "app.asar")) -or (Test-Path (Join-Path $res "_app.asar")) -or (Test-Path (Join-Path $res "app"))) {
                $results += @{ Path = $res; Version = $ver.Name -replace "app-", "" }
            }
        }
    }
    return $results
}

function Kill-Discord {
    foreach ($n in @("Discord","DiscordPTB","DiscordCanary","DiscordDevelopment")) {
        $procs = Get-Process -Name $n -ErrorAction SilentlyContinue
        if ($procs) { $procs | Stop-Process -Force }
    }
    Start-Sleep 2
}

function Inject-Nightcord {
    param($ResourcesPath, $PatcherPath)
    $appDir = Join-Path $ResourcesPath "app"
    $appAsar = Join-Path $ResourcesPath "app.asar"
    $backup = Join-Path $ResourcesPath "_app.asar"
    $pkgFile = Join-Path $appDir "package.json"

    if ((Test-Path $appDir) -and (Test-Path $pkgFile)) {
        $pkg = Get-Content $pkgFile -Raw | ConvertFrom-Json
        if ($pkg.name -eq "nightcord") { Write-Host "  Replacing old injection..." }
    }
    if ((Test-Path $appAsar) -and -not (Test-Path $backup)) {
        Move-Item $appAsar $backup -Force; Write-Host "  Backed up app.asar"
    }
    if (Test-Path $appDir) { Remove-Item $appDir -Recurse -Force }
    New-Item -ItemType Directory -Force -Path $appDir | Out-Null
    Set-Content -Path $pkgFile -Value '{"name":"nightcord","main":"index.js"}'

    $p = $PatcherPath.Replace("\", "/")
    $lines = [System.Collections.ArrayList]::new()
    $null = $lines.Add('"use strict";')
    $null = $lines.Add('const path = require("path");')
    $null = $lines.Add('const fs = require("fs");')
    $null = $lines.Add('const main = "' + $p + '";')
    $null = $lines.Add('const alt = path.join(path.dirname(process.execPath), "dist", "patcher.js");')
    $null = $lines.Add('const p = fs.existsSync(main) ? main : (fs.existsSync(alt) ? alt : null);')
    $null = $lines.Add("if (p) { require(p); } else { console.error('[Nightcord] patcher.js not found'); }")
    Set-Content -Path (Join-Path $appDir "index.js") -Value ($lines -join "`r`n")
    Write-OK "Injected into $ResourcesPath"
}

# ── Main ──────────────────────────────────────────────────────────────────
Write-Banner

# Step 1: Get dist files
$patcherPath = $null
if ((Test-Path $LocalDist) -and (Test-Path (Join-Path $LocalDist "patcher.js"))) {
    $patcherPath = Join-Path $LocalDist "patcher.js"
    Write-OK "Using local dist files"
} elseif ((Test-Path (Join-Path (Join-Path $ScriptRoot "dist") "patcher.js"))) {
    $patcherPath = Join-Path (Join-Path $ScriptRoot "dist") "patcher.js"
    Write-OK "Using local dist files"
} else {
    Write-Host "  No local dist found, trying GitHub..." -ForegroundColor DarkGray
    try {
        $api = "https://api.github.com/repos/$Repo/releases/latest"
        $rel = Invoke-RestMethod $api -Headers @{"User-Agent"="Nightcord"; "Accept"="application/vnd.github.v3+json"}
        $asset = $rel.assets | Where-Object { $_.name -eq "nightcord-dist.zip" } | Select-Object -First 1
        if (-not $asset) { throw "nightcord-dist.zip not found in release" }
        $zip = Join-Path $InstallDir "nightcord-dist.zip"
        Invoke-WebRequest $asset.browser_download_url -OutFile $zip
        if (Test-Path $DistDir) { Remove-Item $DistDir -Recurse -Force }
        Expand-Archive $zip $DistDir -Force; Remove-Item $zip -Force
        $patcherPath = Join-Path $DistDir "patcher.js"
    } catch { Write-Fail "No local dist and GitHub failed. Run pnpm build first.`n$_" }
}

# Step 2: Detect Discord
$discords = Find-Discord
if ($discords.Count -eq 0) { Write-Fail "No Discord installations found." }
Write-OK "Found $($discords.Count) Discord installation(s)"

# Step 3: Inject
Kill-Discord
$count = 0
foreach ($d in $discords) {
    Inject-Nightcord -ResourcesPath $d.Path -PatcherPath $patcherPath
    $count++
}
Write-OK "Injected into $count Discord installation(s)"

# Restart Discord
$stable = $discords | Where-Object { $_.Path -like "*\Discord\*" } | Select-Object -First 1
if ($stable) {
    $upd = Join-Path (Split-Path $stable.Path -Parent) "Update.exe"
    if (Test-Path $upd) { Start-Process $upd -ArgumentList "--processStart Discord.exe" -WindowStyle Hidden }
}

Write-Host "`n  Nightcord installed successfully!`n" -ForegroundColor Green
Start-Sleep 3
