# export_android.ps1
# Builds Android package (APK/AAB) for GRIDLETHAL.

param (
    [switch]$AAB
)

$rootDir = Split-Path -Parent $PSScriptRoot
. "$PSScriptRoot\config.ps1"
$godot = Get-GodotExecutable

$buildDir = Join-Path $rootDir "build\android"
if (!(Test-Path $buildDir)) {
    New-Item -ItemType Directory -Force -Path $buildDir | Out-Null
}

$outputFile = if ($AAB) { "GRIDLETHAL.aab" } else { "GRIDLETHAL.apk" }
$outputPath = Join-Path $buildDir $outputFile

# Pre-flight check: Android SDK & Export Templates
$templatesDir = "$env:APPDATA\Godot\export_templates"
$hasTemplates = (Test-Path $templatesDir) -and (Get-ChildItem $templatesDir -Recurse -Filter "android_*.apk").Count -gt 0

if (!$hasTemplates) {
    Write-Warning "Android export templates are not installed!"
    Write-Host "`nTo install official Godot 4 Android export templates:" -ForegroundColor Yellow
    Write-Host "1. In Godot editor, open 'Editor' -> 'Manage Export Templates...'" -ForegroundColor Gray
    Write-Host "2. Click 'Download and Install'" -ForegroundColor Gray
    Write-Host "3. Or download manually from: https://godotengine.org/download`n" -ForegroundColor Gray
}

if (!$env:ANDROID_HOME -and !$env:ANDROID_SDK_ROOT) {
    Write-Warning "ANDROID_HOME or ANDROID_SDK_ROOT environment variable is not configured."
    Write-Host "Ensure Android SDK Command-line Tools and Build-tools (v34.0.0+) are installed.`n" -ForegroundColor Gray
}

Write-Host "Attempting export of Android package: $outputPath..." -ForegroundColor Cyan
& $godot --headless --path "$rootDir" --export-debug "Android" "$outputPath"

if ($LASTEXITCODE -eq 0 -and (Test-Path $outputPath)) {
    Write-Host "Successfully exported Android build: $outputPath" -ForegroundColor Green
} else {
    Write-Host "Android export requires Android SDK and export templates to complete build step." -ForegroundColor Yellow
}
