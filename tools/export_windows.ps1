# export_windows.ps1
# Builds and packages standalone Windows 64-bit distribution of GRIDLETHAL.

param (
    [switch]$Zip
)

$rootDir = Split-Path -Parent $PSScriptRoot
. "$PSScriptRoot\config.ps1"
$godot = Get-GodotExecutable

$buildDir = Join-Path $rootDir "build\windows"
if (!(Test-Path $buildDir)) {
    New-Item -ItemType Directory -Force -Path $buildDir | Out-Null
}

$pckPath = Join-Path $buildDir "GRIDLETHAL.pck"
$exePath = Join-Path $buildDir "GRIDLETHAL.exe"

Write-Host "Exporting GRIDLETHAL Project Pack (.pck)..." -ForegroundColor Cyan
& $godot --headless --path "$rootDir" --export-pack "Windows Desktop" "$pckPath"

if ($LASTEXITCODE -ne 0 -or !(Test-Path $pckPath)) {
    Write-Error "Failed to export GRIDLETHAL.pck! Exit code: $LASTEXITCODE"
    exit 1
}
Write-Host "Successfully generated $pckPath ($([math]::Round((Get-Item $pckPath).Length / 1MB, 2)) MB)" -ForegroundColor Green

# Locate standard Windows 64-bit runner executable
$binDir = "C:\Users\Aaron\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe"
$sourceExe = Join-Path $binDir "godot.exe"
if (!(Test-Path $sourceExe)) {
    $sourceExe = Join-Path $binDir "Godot_v4.7.2-stable_win64.exe"
}

if (Test-Path $sourceExe) {
    Copy-Item -Path $sourceExe -Destination $exePath -Force
    Write-Host "Successfully generated $exePath ($([math]::Round((Get-Item $exePath).Length / 1MB, 2)) MB)" -ForegroundColor Green
} else {
    Write-Warning "Could not find godot.exe template to copy as GRIDLETHAL.exe. Pack is available at $pckPath"
}

# Create installer-free zip package
$zipPath = Join-Path $buildDir "GRIDLETHAL-windows-x64.zip"
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
Compress-Archive -Path $pckPath, $exePath -DestinationPath $zipPath -Force
Write-Host "Successfully created standalone distribution archive: $zipPath" -ForegroundColor Green

Write-Host "`nWindows Desktop Build Complete!" -ForegroundColor Cyan
