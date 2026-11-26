# tools/commit_and_push_all.ps1
$ErrorActionPreference = "Stop"

# Get all changed and untracked files individually (-uall ensures directory contents commit one-by-one)
$status = git status --porcelain -uall
if (-not $status) {
    Write-Host "No files to commit."
    exit 0
}

$files = @()
foreach ($line in $status) {
    if ($line.Length -gt 3) {
        $filePath = $line.Substring(3).Trim()
        # Strip quotes if git quoted paths with spaces
        if ($filePath.StartsWith('"') -and $filePath.EndsWith('"')) {
            $filePath = $filePath.Substring(1, $filePath.Length - 2)
        }
        if (Test-Path $filePath) {
            $files += $filePath
        }
    }
}

Write-Host "Found $($files.Count) items to commit one-by-one..."

$count = 0
foreach ($f in $files) {
    $count++
    $msg = "Upgrade Forward+ 6GB VRAM, AgX pipeline, LODs & scenes: $f"
    if ($f.EndsWith(".gdshader")) {
        $msg = "Update PBR highway/terrain shader: $f"
    } elseif ($f.Contains("visual_pipeline")) {
        $msg = "Add shared Forward+ AgX, LightmapGI, occluder & prewarm pipeline: $f"
    } elseif ($f.Contains("optimize_vram_imports")) {
        $msg = "Add BPTC/BC1/LOD asset import optimizer tool: $f"
    } elseif ($f.Contains("prop_mesh_utils") -or $f.Contains("scenery_populator")) {
        $msg = "Add ImporterMesh LOD decimation & spatial HLOD grid culling: $f"
    } elseif ($f.Contains("car_model_loader")) {
        $msg = "Use imported LOD/BPTC cars & one-shot biome reflection probes: $f"
    } elseif ($f.Contains("garage")) {
        $msg = "Upgrade Garage Autoshow studio lighting, orbit camera & GLB models: $f"
    } elseif ($f.Contains("track_test") -or $f.Contains("spline_track") -or $f.Contains("race_")) {
        $msg = "Upgrade Rust Gate Circuit visuals, HUD anchoring & start countdown: $f"
    } elseif ($f.Contains("debug_overlay")) {
        $msg = "Add live F3 VRAM, draw-call, DRS & physics telemetry: $f"
    } elseif ($f.Contains("audit") -or $f.Contains("m1_boot")) {
        $msg = "Update Forward+ Vulkan visual verification screenshot: $f"
    }
    
    git add $f
    git commit --author="RYuK006 <ryuk@gridlethal.com>" -m "$msg"
    Write-Host "[$count/$($files.Count)] Committed: $f"
}

Write-Host "Pushing all commits to origin main..."
git push origin main
Write-Host "Successfully pushed to origin main!"
