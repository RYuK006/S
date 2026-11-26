# tools/extract_rock.ps1
$zip = "assets/models/props/cliff_rock_boulder.zip"
$dest = "assets/models/props/cliff_rock"
if (-not (Test-Path $dest)) {
    New-Item -ItemType Directory -Path $dest -Force | Out-Null
}
Write-Host "Extracting $zip to $dest..."
Expand-Archive -Path $zip -DestinationPath $dest -Force
Write-Host "Done! Extracted contents:"
Get-ChildItem -Path $dest
