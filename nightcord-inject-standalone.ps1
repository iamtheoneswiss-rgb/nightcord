param(
    [switch]$Uninstall,
    [switch]$Help,
    [string]$Channel = "All"
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$DistDir = Join-Path (Join-Path $ScriptDir "dist") "desktop"
$PatcherFile = Join-Path $DistDir "patcher.js"
$Channels = @("Discord", "DiscordPTB", "DiscordCanary", "DiscordDevelopment")

if ($Help) {
    Write-Host "Nightcord Standalone Injector`n"
    Write-Host "Usage:"
    Write-Host "  .\nightcord-inject-standalone.ps1              Inject into all Discord installs"
    Write-Host "  .\nightcord-inject-standalone.ps1 -Uninstall   Uninject Nightcord"
    Write-Host "  .\nightcord-inject-standalone.ps1 -Channel DiscordPTB  Inject only into Discord PTB"
    exit 0
}

function Find-DiscordResources {
    $results = @()
    $localAppData = $env:LOCALAPPDATA
    $targets = if ($Channel -eq "All") { $Channels } else { @($Channel) }
    foreach ($ch in $targets) {
        $base = Join-Path $localAppData $ch
        if (-not (Test-Path $base)) { continue }
        try {
            $versions = Get-ChildItem $base -Directory | Where-Object { $_.Name -match "^app-\d+\.\d+\.\d+$" } | Sort-Object Name -Descending
            foreach ($ver in $versions) {
                $res = Join-Path $ver.FullName "resources"
                if ((Test-Path (Join-Path $res "app.asar") -PathType Leaf) -or (Test-Path (Join-Path $res "app")) -or (Test-Path (Join-Path $res "_app.asar"))) {
                    $results += @{ Path = $res; Channel = $ch; Version = $ver.Name -replace "^app-", ""; ExeName = if ($ch -eq "Discord") { "Discord.exe" } else { "$ch.exe" } }
                }
            }
        } catch {}
    }
    return $results
}

function Kill-Discord {
    param($ExeName)
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($ExeName)
    $procs = Get-Process -Name $baseName -ErrorAction SilentlyContinue
    if ($procs) { $procs | Stop-Process -Force; Start-Sleep 2 }
}

function Start-Discord {
    param($resourcesPath, $exeName)
    $appBase = Split-Path $resourcesPath -Parent
    $updateExe = Join-Path $appBase "Update.exe"
    if (Test-Path $updateExe) { Start-Process $updateExe -ArgumentList "--processStart", $exeName -WindowStyle Hidden; return }
    $discordExe = Join-Path $appBase $exeName
    if (Test-Path $discordExe) { Start-Process $discordExe }
}

function Inject {
    param($resourcesPath)
    $appAsar = Join-Path $resourcesPath "app.asar"
    $backup = Join-Path $resourcesPath "_app.asar"
    $appDir = Join-Path $resourcesPath "app"
    $pkgFile = Join-Path $appDir "package.json"

    if ((Test-Path $appDir) -and (Test-Path $pkgFile)) {
        $pkg = Get-Content $pkgFile -Raw | ConvertFrom-Json
        if ($pkg.name -eq "nightcord") { Write-Host "  Already injected. Re-injecting..." }
    }
    if (-not (Test-Path $PatcherFile)) { Write-Host "  [ERROR] patcher.js not found at $PatcherFile" -ForegroundColor Red; return $false }

    Kill-Discord -ExeName $resourcesPath

    if ((Test-Path $appAsar) -and -not (Test-Path $backup)) { Write-Host "  Backing up app.asar..."; Move-Item $appAsar $backup -Force }
    if (Test-Path $appDir) { Remove-Item $appDir -Recurse -Force }
    New-Item -ItemType Directory -Force -Path $appDir | Out-Null

    $p = $PatcherFile.Replace("\", "/")
    $lines = [System.Collections.ArrayList]::new()
    $null = $lines.Add('"use strict";')
    $null = $lines.Add('const path = require("path");')
    $null = $lines.Add('const fs = require("fs");')
    $null = $lines.Add('const patcherPath = "' + $p + '";')
    $null = $lines.Add('if (fs.existsSync(patcherPath)) {')
    $null = $lines.Add('    require(patcherPath);')
    $null = $lines.Add('} else {')
    $null = $lines.Add('    const fallback = path.join(path.dirname(process.execPath), "dist", "patcher.js");')
    $null = $lines.Add('    if (fs.existsSync(fallback)) { require(fallback); }')
    $null = $lines.Add('    else { console.error("[Nightcord] patcher.js not found"); }')
    $null = $lines.Add('}')

    Set-Content -Path $pkgFile -Value '{"name":"nightcord","main":"index.js"}'
    Set-Content -Path (Join-Path $appDir "index.js") -Value ($lines -join "`r`n")
    Write-Host "  [OK] Nightcord injected!" -ForegroundColor Green
    return $true
}

function Uninject {
    param($resourcesPath)
    $appAsar = Join-Path $resourcesPath "app.asar"
    $backup = Join-Path $resourcesPath "_app.asar"
    $appDir = Join-Path $resourcesPath "app"
    $pkgFile = Join-Path $appDir "package.json"

    if ((Test-Path $appDir) -and (Test-Path $pkgFile)) {
        $pkg = Get-Content $pkgFile -Raw | ConvertFrom-Json
        if ($pkg.name -eq "nightcord") { Remove-Item $appDir -Recurse -Force; Write-Host "  Removed injected app/ folder" }
    }
    if ((Test-Path $backup) -and -not (Test-Path $appAsar)) { Move-Item $backup $appAsar -Force; Write-Host "  Restored app.asar" }
    elseif (Test-Path $backup) { Remove-Item $backup -Force }
    Write-Host "  [OK] Nightcord uninjected!" -ForegroundColor Green
}

# -- Main --
Clear-Host
Write-Host "= NIGHTCORD STANDALONE INJECTOR =" -ForegroundColor Cyan
Write-Host ""

$found = Find-DiscordResources
if ($found.Count -eq 0) { Write-Host "No Discord installations found." -ForegroundColor Red; exit 1 }

$counter = 0
foreach ($f in $found) {
    $counter++
    $n = if ($f.Channel -eq "Discord") { "Discord Stable" } else { $f.Channel }
    Write-Host "  [$counter/$($found.Count)] $n v$($f.Version)" -ForegroundColor Yellow
    Write-Host "    Path: $($f.Path)"
    if ($Uninstall) { Uninject -resourcesPath $f.Path } else { Inject -resourcesPath $f.Path }
    Write-Host ""
}

Write-Host "  Restarting Discord..." -ForegroundColor DarkGray
$first = $found[0]
Start-Discord -resourcesPath $first.Path -exeName $first.ExeName
Write-Host "`n  Done!" -ForegroundColor Green
