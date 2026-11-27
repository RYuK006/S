# tools/commit_and_push_all.ps1
$ErrorActionPreference = "Continue"

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
    $msg = "Update GRIDLETHAL project asset/config: $f"
    if ($f.EndsWith(".gdshader")) {
        $msg = "Calibrate unified PBR lighting & terrain/road surface blending shader: $f"
    } elseif ($f.Contains("real_world_roads") -or $f.Contains("build_real_world_map") -or $f.Contains("road_network")) {
        $msg = "Restructure 37-road OSM real-world & town street network: $f"
    } elseif ($f.Contains("destructible_prop_manager") -or $f.Contains("extended_props_populator") -or $f.Contains("biome_props_builder")) {
        $msg = "Add heterogeneous prop collisions, physics destruction & 67-prop placement: $f"
    } elseif ($f.Contains("prop_mesh_utils") -or $f.Contains("scenery_populator") -or $f.Contains("terrain_generator")) {
        $msg = "Enforce zero-props-on-roads spatial checks & clean slope carving: $f"
    } elseif ($f.Contains("car_model_loader") -or $f.Contains("car_material_enhancer") -or $f.Contains("vehicles.json") -or $f.Contains("approved_assets_manifest")) {
        $msg = "Add 36 high-detail cars & split FH5 clearcoat PBR material enhancer: $f"
    } elseif ($f.Contains("garage")) {
        $msg = "Expose full 68-vehicle showroom roster in Garage Autoshow: $f"
    } elseif ($f.Contains("assets/models/cars")) {
        $msg = "Add optimized BPTC/BC1 high-detail 3D vehicle asset: $f"
    } elseif ($f.Contains("assets/models/props")) {
        $msg = "Add optimized photogrammetry/street 3D prop asset: $f"
    } elseif ($f.Contains("test_") -or $f.Contains("audit_") -or $f.Contains("upgrade_v1")) {
        $msg = "Update verification suite & GPU visual audit outputs: $f"
    }
    
    git add -f -- $f
    if ($LASTEXITCODE -ne 0) { throw "git add failed on $f" }
    git commit --author="RYuK006 <ryuk@gridlethal.com>" -m "$msg"
    if ($LASTEXITCODE -ne 0) { throw "git commit failed on $f" }
    if (($count % 100) -eq 0 -or $count -eq $files.Count) {
        Write-Host "[$count/$($files.Count)] Pushing batch to origin main (last: $f)..."
        for ($retry = 1; $retry -le 3; $retry++) {
            git push origin main
            if ($LASTEXITCODE -eq 0) { break }
            Start-Sleep -Seconds 4
        }
        if ($LASTEXITCODE -ne 0) { throw "Failed to push batch at $count ($f)" }
    }
}

Write-Host "Successfully committed one-by-one and pushed all $count files to origin main!"
