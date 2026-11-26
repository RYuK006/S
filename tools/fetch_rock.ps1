# tools/fetch_rock.ps1
$urls = @(
    "https://dl.polyhaven.org/file/ph-assets/Models/gltf/1k/desert_rock_01/desert_rock_01_1k.gltf",
    "https://dl.polyhaven.org/file/ph-assets/Models/gltf/1k/desert_rock_01/desert_rock_01_1k.bin",
    "https://dl.polyhaven.org/file/ph-assets/Models/gltf/1k/desert_rock_01/textures/desert_rock_01_diff_1k.jpg",
    "https://dl.polyhaven.org/file/ph-assets/Models/gltf/1k/desert_rock_01/textures/desert_rock_01_nor_gl_1k.jpg",
    "https://dl.polyhaven.org/file/ph-assets/Models/gltf/1k/desert_rock_01/textures/desert_rock_01_rough_1k.jpg"
)
$destDir = "assets/models/rocks"
New-Item -ItemType Directory -Path "$destDir/textures" -Force | Out-Null

foreach ($u in $urls) {
    $fname = Split-Path $u -Leaf
    if ($u -like "*/textures/*") {
        $out = "$destDir/textures/$fname"
    } else {
        $out = "$destDir/$fname"
    }
    Write-Host "Fetching $fname..."
    Invoke-WebRequest -Uri $u -OutFile $out -UseBasicParsing
}
Write-Host "Rock assets downloaded successfully!"
