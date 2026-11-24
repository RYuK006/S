# config.ps1
# Resolves Godot 4 binary executable path across environment variables and local tool installations.

function Get-GodotExecutable {
    # 1. Check explicit environment variable
    if ($env:GODOT -and (Test-Path $env:GODOT)) {
        return $env:GODOT
    }

    # 2. Check local tools directory wrapper
    $localWrapper = Join-Path $PSScriptRoot "godot.cmd"
    if (Test-Path $localWrapper) {
        return $localWrapper
    }

    # 3. Check system PATH
    $cmd = Get-Command "godot" -ErrorAction SilentlyContinue
    if ($cmd) {
        return $cmd.Source
    }

    $cmd4 = Get-Command "godot4" -ErrorAction SilentlyContinue
    if ($cmd4) {
        return $cmd4.Source
    }

    Write-Error "Godot 4 executable could not be found! Please set the GODOT environment variable or place godot.cmd in tools/."
    Write-Host "Download official Godot 4.x stable: https://godotengine.org/download" -ForegroundColor Yellow
    exit 1
}
