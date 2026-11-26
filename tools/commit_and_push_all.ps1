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
    $msg = "Update $f to Forza Horizon 5 visual fidelity"
    if ($f.EndsWith(".gdshader")) {
        $msg = "Add PBR highway asphalt shader: $f"
    } elseif ($f.Contains("car_model_loader")) {
        $msg = "Calibrate true 1:1 scale and PBR materials for car models: $f"
    } elseif ($f.Contains("scenery_populator")) {
        $msg = "Integrate 3D scanned photogrammetry rocks and props: $f"
    } elseif ($f.Contains("road_network")) {
        $msg = "Generate PBR highway road geometry with worn tire tracks: $f"
    } elseif ($f.Contains("open_world")) {
        $msg = "Upgrade open world environment with AgX tonemapper and 2K sunny sky: $f"
    } elseif ($f.Contains("syferfontein")) {
        $msg = "Add Poly Haven 2K clear sunny sky HDRI: $f"
    } elseif ($f.Contains("cliff_rock")) {
        $msg = "Add 3D photogrammetric scanned boulder rock field: $f"
    } elseif ($f.Contains("audit")) {
        $msg = "Add high-resolution Forward+ Vulkan GPU audit screenshot: $f"
    } elseif ($f.Contains("tools")) {
        $msg = "Add visual fidelity inspection and audit script: $f"
    }
    
    git add $f
    git commit --author="RYuK006 <ryuk@gridlethal.com>" -m "$msg"
    Write-Host "[$count/$($files.Count)] Committed: $f"
}

Write-Host "Pushing all commits to origin main..."
git push origin main
Write-Host "Successfully pushed to origin main!"
