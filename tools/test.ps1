# test.ps1
# Runs headless automated verification suite in Godot 4.

. "$PSScriptRoot\config.ps1"
$godot = Get-GodotExecutable

Write-Host "Running GRIDLETHAL Automated Headless Verification Suite..." -ForegroundColor Cyan
& $godot --headless -s "res://tests/run_all.gd"

if ($LASTEXITCODE -eq 0) {
    Write-Host "`nAll verification tests passed successfully with 0 errors!" -ForegroundColor Green
} else {
    Write-Host "`nTest suite failed with exit code $LASTEXITCODE." -ForegroundColor Red
}
exit $LASTEXITCODE
