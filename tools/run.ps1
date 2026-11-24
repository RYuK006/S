# run.ps1
# Launches GRIDLETHAL in Godot 4 Forward+ Vulkan desktop mode.

. "$PSScriptRoot\config.ps1"
$godot = Get-GodotExecutable

Write-Host "Launching GRIDLETHAL in Godot Forward+ Engine..." -ForegroundColor Cyan
Write-Host "Executable: $godot" -ForegroundColor Gray

& $godot "res://scenes/main.tscn" @args
exit $LASTEXITCODE
