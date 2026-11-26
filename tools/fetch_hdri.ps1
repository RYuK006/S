# tools/fetch_hdri.ps1
$url = "https://dl.polyhaven.org/file/ph-assets/HDRIs/hdr/2k/syferfontein_0d_clear_2k.hdr"
$dest = "assets/hdri/syferfontein_0d_clear_2k.hdr"
if (-not (Test-Path "assets/hdri")) {
    New-Item -ItemType Directory -Path "assets/hdri" -Force | Out-Null
}
Write-Host "Downloading $url -> $dest"
Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing
Write-Host "Done: $((Get-Item $dest).Length) bytes"
