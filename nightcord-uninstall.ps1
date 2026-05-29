# ==============================================================================
#  Nightcord - Uninstaller (PowerShell, fully offline)
#  Removes Nightcord injection from Discord.
# ==============================================================================

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

function Write-Banner {
    Clear-Host
    Write-Host ""
    Write-Host "  NIGHTCORD UNINSTALLER" -ForegroundColor Cyan
    Write-Host ""
}

function Write-OK($m) { Write-Host "  [OK] $m" -ForegroundColor Green }

function Find-Discord {
    $results = @()
    foreach ($ch in @("Discord","DiscordPTB","DiscordCanary","DiscordDevelopment")) {
        $base = Join-Path $env:LOCALAPPDATA $ch
        if (-not (Test-Path $base)) { continue }
        $versions = Get-ChildItem $base -Directory -Filter "app-*" | Sort-Object Name -Descending
        foreach ($ver in $versions) {
            $res = Join-Path $ver.FullName "resources"
            $appDir = Join-Path $res "app"; $backup = Join-Path $res "_app.asar"
            if ((Test-Path $appDir) -or (Test-Path $backup)) {
                $results += @{ Path = $res; Channel = $ch; Version = $ver.Name -replace "app-", "" }
            }
        }
    }
    return $results
}

function Uninject-Nightcord {
    param($ResourcesPath)
    $appDir = Join-Path $ResourcesPath "app"
    $appAsar = Join-Path $ResourcesPath "app.asar"
    $backup = Join-Path $ResourcesPath "_app.asar"
    $pkgFile = Join-Path $appDir "package.json"
    if ((Test-Path $appDir) -and (Test-Path $pkgFile)) {
        $pkg = Get-Content $pkgFile -Raw | ConvertFrom-Json
        if ($pkg.name -eq "nightcord") { Remove-Item $appDir -Recurse -Force; Write-OK "Removed injection" }
    }
    if ((Test-Path $backup) -and -not (Test-Path $appAsar)) { Move-Item $backup $appAsar -Force; Write-OK "Restored app.asar" }
    elseif (Test-Path $backup) { Remove-Item $backup -Force; Write-OK "Removed stale backup" }
}

Write-Banner
$discords = Find-Discord
if ($discords.Count -eq 0) { Write-Host "  No Nightcord injections found."; Start-Sleep 2; exit 0 }
foreach ($d in $discords) {
    $n = if ($d.Channel -eq "Discord") { "Discord Stable" } else { $d.Channel }
    Write-Host "  -> $n v$($d.Version)" -ForegroundColor DarkGray
    Uninject-Nightcord -ResourcesPath $d.Path
}
Write-Host "`n  Nightcord uninstalled successfully! Restart Discord.`n" -ForegroundColor Green
Start-Sleep 3
