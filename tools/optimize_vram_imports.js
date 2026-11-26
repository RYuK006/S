// tools/optimize_vram_imports.js
// Enforces Godot 4 Forward+ 6GB VRAM hygiene across all assets/**/*.import:
//   - Lossless CPU-read data (world_dem_height.png) kept uncompressed & un-mipmapped
//   - HDR skyboxes kept HDR lossless
//   - 3D environment textures capped at 2K (4K allowed for hero cars)
//   - Mipmaps enabled on all 3D textures
//   - Opaque PBR maps -> DXT1/BC1 (compress/mode=2, high_quality=false)
//   - Normal maps, alpha foliage/decals, and PNG car/prop atlases -> BPTC/BC7 (compress/mode=2, high_quality=true)
//   - All .glb/.gltf models -> generate_lods=true, ensure_tangents=true, create_shadow_meshes=true, light_baking=1

const fs = require("fs");
const path = require("path");

function walk(dir) {
  const out = [];
  for (const ent of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, ent.name);
    if (ent.isDirectory()) out.push(...walk(p));
    else if (ent.name.endsWith(".import")) out.push(p);
  }
  return out;
}

function setParam(lines, key, val) {
  const prefix = key + "=";
  for (let i = 0; i < lines.length; i++) {
    if (lines[i].startsWith(prefix)) {
      lines[i] = prefix + val;
      return;
    }
  }
  const paramsIdx = lines.findIndex((l) => l.trim() === "[params]");
  if (paramsIdx >= 0) {
    lines.splice(paramsIdx + 1, 0, prefix + val);
  } else {
    lines.push(prefix + val);
  }
}

const files = walk(path.join(process.cwd(), "assets"));
const counts = { total: 0, updated: 0, bc1: 0, bc7: 0, lossless_data: 0, hdr: 0, scenes: 0 };

for (const file of files) {
  counts.total++;
  const raw = fs.readFileSync(file, "utf8");
  const eol = raw.includes("\r\n") ? "\r\n" : "\n";
  const lines = raw.split(/\r?\n/);
  const norm = file.replace(/\\/g, "/").toLowerCase();

  if (norm.endsWith(".glb.import") || norm.endsWith(".gltf.import")) {
    counts.scenes++;
    setParam(lines, "meshes/ensure_tangents", "true");
    setParam(lines, "meshes/generate_lods", "true");
    setParam(lines, "meshes/create_shadow_meshes", "true");
    setParam(lines, "meshes/light_baking", "1");
    setParam(lines, "meshes/lightmap_texel_size", "0.2");
  } else if (norm.includes("world_dem_height")) {
    counts.lossless_data++;
    setParam(lines, "compress/mode", "0");
    setParam(lines, "compress/high_quality", "false");
    setParam(lines, "mipmaps/generate", "false");
    setParam(lines, "detect_3d/compress_to", "0");
  } else if (norm.endsWith(".hdr.import")) {
    counts.hdr++;
    setParam(lines, "compress/mode", "0");
    setParam(lines, "compress/hdr_compression", "1");
    setParam(lines, "mipmaps/generate", "false");
    setParam(lines, "detect_3d/compress_to", "0");
  } else if (/\.(png|jpg|jpeg)\.import$/i.test(norm)) {
    const isCar = norm.includes("/models/cars/");
    const isNormal = /(_nor|_normal|-normal|_nrm)/.test(norm);
    const isAlphaOrPng = norm.endsWith(".png.import");
    const useBC7 = isNormal || isAlphaOrPng;

    setParam(lines, "compress/mode", "2");
    setParam(lines, "compress/high_quality", useBC7 ? "true" : "false");
    setParam(lines, "compress/normal_map", "0");
    setParam(lines, "mipmaps/generate", "true");
    setParam(lines, "detect_3d/compress_to", "2");
    setParam(lines, "process/size_limit", isCar ? "4096" : "2048");

    if (useBC7) counts.bc7++;
    else counts.bc1++;
  }

  const next = lines.join(eol);
  if (next !== raw) {
    fs.writeFileSync(file, next, "utf8");
    counts.updated++;
  }
}

console.log("VRAM Import Optimization Complete:", counts);
