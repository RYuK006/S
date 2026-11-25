# tools/fetch_all_pbr_assets.ps1
$ErrorActionPreference = "Stop"

# 1. Ensure target directories exist
$dirs = @("assets/hdri", "assets/textures", "assets/models/props", "assets/models/foliage")
foreach ($d in $dirs) {
    if (-not (Test-Path $d)) {
        New-Item -ItemType Directory -Path $d -Force | Out-Null
    }
}

Write-Host "=== 1. DOWNLOADING POLY HAVEN CC0 HDRI SKY ==="
$hdriUrl = "https://dl.polyhaven.org/file/ph-assets/HDRIs/hdr/1k/autumn_field_1k.hdr"
$hdriDest = "assets/hdri/autumn_field_1k.hdr"
if (-not (Test-Path $hdriDest)) {
    Write-Host "Downloading $hdriUrl -> $hdriDest..."
    Invoke-WebRequest -Uri $hdriUrl -OutFile $hdriDest -UseBasicParsing
    Write-Host "HDRI downloaded: $((Get-Item $hdriDest).Length) bytes."
} else {
    Write-Host "HDRI already present."
}

Write-Host "`n=== 2. DOWNLOADING POLY HAVEN CC0 1K PBR TEXTURES ==="
$textures = @(
    @{ Name = "asphalt"; Diff = "https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/asphalt_02/asphalt_02_diff_1k.jpg"; Nor = "https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/asphalt_02/asphalt_02_nor_gl_1k.jpg"; Rough = "https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/asphalt_02/asphalt_02_rough_1k.jpg" },
    @{ Name = "grass"; Diff = "https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/aerial_grass_rock/aerial_grass_rock_diff_1k.jpg"; Nor = "https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/aerial_grass_rock/aerial_grass_rock_nor_gl_1k.jpg"; Rough = "https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/aerial_grass_rock/aerial_grass_rock_rough_1k.jpg" },
    @{ Name = "sand"; Diff = "https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/coast_sand_01/coast_sand_01_diff_1k.jpg"; Nor = "https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/coast_sand_01/coast_sand_01_nor_gl_1k.jpg"; Rough = "https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/coast_sand_01/coast_sand_01_rough_1k.jpg" },
    @{ Name = "snow"; Diff = "https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/snow_02/snow_02_diff_1k.jpg"; Nor = "https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/snow_02/snow_02_nor_gl_1k.jpg"; Rough = "https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/snow_02/snow_02_rough_1k.jpg" },
    @{ Name = "cliff"; Diff = "https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/cliff_side/cliff_side_diff_1k.jpg"; Nor = "https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/cliff_side/cliff_side_nor_gl_1k.jpg"; Rough = "https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/cliff_side/cliff_side_rough_1k.jpg" },
    @{ Name = "volcano"; Diff = "https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/burned_ground_01/burned_ground_01_diff_1k.jpg"; Nor = "https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/burned_ground_01/burned_ground_01_nor_gl_1k.jpg"; Rough = "https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/burned_ground_01/burned_ground_01_rough_1k.jpg" }
)

foreach ($t in $textures) {
    $diffPath = "assets/textures/$($t.Name)_diff.jpg"
    $norPath = "assets/textures/$($t.Name)_nor.jpg"
    $roughPath = "assets/textures/$($t.Name)_rough.jpg"
    
    if (-not (Test-Path $diffPath)) {
        Write-Host "Downloading $($t.Name) Diffuse..."
        Invoke-WebRequest -Uri $t.Diff -OutFile $diffPath -UseBasicParsing
    }
    if (-not (Test-Path $norPath)) {
        Write-Host "Downloading $($t.Name) Normal..."
        Invoke-WebRequest -Uri $t.Nor -OutFile $norPath -UseBasicParsing
    }
    if (-not (Test-Path $roughPath)) {
        Write-Host "Downloading $($t.Name) Roughness..."
        Invoke-WebRequest -Uri $t.Rough -OutFile $roughPath -UseBasicParsing
    }
    Write-Host "  $($t.Name) PBR set ready."
}

Write-Host "`n=== 3. DOWNLOADING CC0 3D GLB MODELS ==="
$models = @(
    @{ Url = "https://github.com/KenneyNL/Starter-Kit-Racing/raw/main/models/track-finish.glb"; Dest = "assets/models/props/track_finish_arch.glb" },
    @{ Url = "https://github.com/KenneyNL/Starter-Kit-Racing/raw/main/models/track-tents.glb"; Dest = "assets/models/props/festival_tents.glb" },
    @{ Url = "https://github.com/KenneyNL/Starter-Kit-Racing/raw/main/models/decoration-forest.glb"; Dest = "assets/models/foliage/pine_cluster.glb" },
    @{ Url = "https://github.com/KenneyNL/Starter-Kit-City-Builder/raw/main/models/building-garage.glb"; Dest = "assets/models/props/pit_garage.glb" },
    @{ Url = "https://github.com/KenneyNL/Starter-Kit-City-Builder/raw/main/models/grass-trees-tall.glb"; Dest = "assets/models/foliage/trees_tall.glb" },
    @{ Url = "https://github.com/KenneyNL/Starter-Kit-City-Builder/raw/main/models/grass-trees.glb"; Dest = "assets/models/foliage/trees_medium.glb" },
    @{ Url = "https://github.com/KenneyNL/Starter-Kit-City-Builder/raw/main/models/building-small-a.glb"; Dest = "assets/models/props/paddock_building_a.glb" },
    @{ Url = "https://github.com/KenneyNL/Starter-Kit-City-Builder/raw/main/models/building-small-b.glb"; Dest = "assets/models/props/paddock_building_b.glb" },
    @{ Url = "https://github.com/KenneyNL/Starter-Kit-City-Builder/raw/main/models/pavement-fountain.glb"; Dest = "assets/models/props/plaza_fountain.glb" },
    @{ Url = "https://github.com/KenneyNL/Starter-Kit-City-Builder/raw/main/models/road-straight-lightposts.glb"; Dest = "assets/models/props/highway_lightpost.glb" }
)

foreach ($m in $models) {
    if (-not (Test-Path $m.Dest)) {
        Write-Host "Downloading 3D model $($m.Dest)..."
        Invoke-WebRequest -Uri $m.Url -OutFile $m.Dest -UseBasicParsing
    } else {
        Write-Host "3D model $($m.Dest) already present."
    }
}

Write-Host "`nAll PBR textures, CC0 HDRI, and 3D models downloaded successfully!"
