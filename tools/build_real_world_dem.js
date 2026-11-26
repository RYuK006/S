// tools/build_real_world_dem.js
// Downloads NASA SRTM Terrarium elevation PNG tiles from AWS Open Data for 4 real-world
// topography regions (Alps, Mexican Volcano Caldera, Canyonlands/Monument Valley, Big Sur Coast),
// decodes 16-bit elevation, computes hydrological flow accumulation + strata relief, blends into
// GRIDLETHAL's 7100m x 7100m open world (1024x1024 PNG: R=hi byte, G=lo byte, B=flow/gravel mask, A=strata/ridge).

const https = require('https');
const fs = require('fs');
const path = require('path');
const zlib = require('zlib');

const ROOT = path.resolve(__dirname, '..');
const OUT_PATH = path.join(ROOT, 'assets', 'textures', 'world_dem_height.png');
const OUT_SIZE = 1024;
const HALF_WORLD = 3550.0;
const MIN_H = -20.0;
const MAX_H = 380.0;

function lonLatToTile(lon, lat, z) {
    const n = Math.pow(2, z);
    const x = Math.floor(((lon + 180.0) / 360.0) * n);
    const latRad = (lat * Math.PI) / 180.0;
    const y = Math.floor(((1.0 - Math.log(Math.tan(latRad) + 1.0 / Math.cos(latRad)) / Math.PI) / 2.0) * n);
    return { x, y, z };
}

function fetchBuffer(url) {
    return new Promise((resolve, reject) => {
        https.get(url, (res) => {
            if (res.statusCode !== 200) {
                reject(new Error(`HTTP ${res.statusCode} for ${url}`));
                return;
            }
            const chunks = [];
            res.on('data', (c) => chunks.push(c));
            res.on('end', () => resolve(Buffer.concat(chunks)));
        }).on('error', reject);
    });
}

// Pure-Node minimal PNG decoder supporting RGB/RGBA 8-bit PNGs (like AWS Terrarium tiles)
function decodePng(buf) {
    let offset = 8; // skip PNG signature
    let width = 0, height = 0, colorType = 0;
    const idatChunks = [];
    while (offset < buf.length) {
        const len = buf.readUInt32BE(offset);
        const type = buf.toString('ascii', offset + 4, offset + 8);
        const data = buf.subarray(offset + 8, offset + 8 + len);
        if (type === 'IHDR') {
            width = data.readUInt32BE(0);
            height = data.readUInt32BE(4);
            colorType = data[9];
        } else if (type === 'IDAT') {
            idatChunks.push(data);
        } else if (type === 'IEND') {
            break;
        }
        offset += 12 + len;
    }
    const bpp = colorType === 6 ? 4 : 3;
    const raw = zlib.inflateSync(Buffer.concat(idatChunks));
    const stride = width * bpp;
    const out = Buffer.alloc(width * height * bpp);

    const paeth = (a, b, c) => {
        const p = a + b - c;
        const pa = Math.abs(p - a), pb = Math.abs(p - b), pc = Math.abs(p - c);
        if (pa <= pb && pa <= pc) return a;
        if (pb <= pc) return b;
        return c;
    };

    for (let y = 0; y < height; y++) {
        const filter = raw[y * (stride + 1)];
        const rowStart = y * (stride + 1) + 1;
        const outStart = y * stride;
        for (let i = 0; i < stride; i++) {
            const xVal = raw[rowStart + i];
            const a = i >= bpp ? out[outStart + i - bpp] : 0;
            const b = y > 0 ? out[(y - 1) * stride + i] : 0;
            const c = (y > 0 && i >= bpp) ? out[(y - 1) * stride + i - bpp] : 0;
            let val = xVal;
            if (filter === 1) val = (xVal + a) & 0xff;
            else if (filter === 2) val = (xVal + b) & 0xff;
            else if (filter === 3) val = (xVal + ((a + b) >> 1)) & 0xff;
            else if (filter === 4) val = (xVal + paeth(a, b, c)) & 0xff;
            out[outStart + i] = val;
        }
    }
    return { width, height, bpp, data: out };
}

function encodeRgbaPng(width, height, rgba) {
    const raw = Buffer.alloc(height * (1 + width * 4));
    for (let y = 0; y < height; y++) {
        raw[y * (1 + width * 4)] = 0; // None filter
        rgba.copy(raw, y * (1 + width * 4) + 1, y * width * 4, (y + 1) * width * 4);
    }
    const compressed = zlib.deflateSync(raw, { level: 9 });

    const crcTable = new Uint32Array(256);
    for (let n = 0; n < 256; n++) {
        let c = n;
        for (let k = 0; k < 8; k++) c = (c & 1) ? (0xedb88320 ^ (c >>> 1)) : (c >>> 1);
        crcTable[n] = c >>> 0;
    }
    const crc32 = (b) => {
        let c = 0xffffffff;
        for (let i = 0; i < b.length; i++) c = crcTable[(c ^ b[i]) & 0xff] ^ (c >>> 8);
        return (c ^ 0xffffffff) >>> 0;
    };
    const chunk = (type, data) => {
        const len = Buffer.alloc(4); len.writeUInt32BE(data.length, 0);
        const typeBuf = Buffer.from(type, 'ascii');
        const body = Buffer.concat([typeBuf, data]);
        const crc = Buffer.alloc(4); crc.writeUInt32BE(crc32(body), 0);
        return Buffer.concat([len, body, crc]);
    };
    const ihdr = Buffer.alloc(13);
    ihdr.writeUInt32BE(width, 0);
    ihdr.writeUInt32BE(height, 4);
    ihdr[8] = 8; // bit depth
    ihdr[9] = 6; // RGBA
    const sig = Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]);
    return Buffer.concat([sig, chunk('IHDR', ihdr), chunk('IDAT', compressed), chunk('IEND', Buffer.alloc(0))]);
}

async function fetchDemMosaic(lon, lat, z, gridTiles = 2) {
    const center = lonLatToTile(lon, lat, z);
    const tileSize = 256;
    const total = gridTiles * tileSize;
    const elev = new Float32Array(total * total);
    const startX = center.x - Math.floor(gridTiles / 2);
    const startY = center.y - Math.floor(gridTiles / 2);

    for (let ty = 0; ty < gridTiles; ty++) {
        for (let tx = 0; tx < gridTiles; tx++) {
            const url = `https://s3.amazonaws.com/elevation-tiles-prod/terrarium/${z}/${startX + tx}/${startY + ty}.png`;
            const buf = await fetchBuffer(url);
            const png = decodePng(buf);
            for (let py = 0; py < tileSize; py++) {
                for (let px = 0; px < tileSize; px++) {
                    const si = (py * png.width + px) * png.bpp;
                    const r = png.data[si], g = png.data[si + 1], b = png.data[si + 2];
                    const h = (r * 256.0 + g + b / 256.0) - 32768.0;
                    const ox = tx * tileSize + px;
                    const oy = ty * tileSize + py;
                    elev[oy * total + ox] = h;
                }
            }
        }
    }
    return { size: total, elev };
}

function sampleBilinear(grid, u, v) {
    const s = grid.size;
    const x = Math.max(0, Math.min(s - 1.001, u * (s - 1)));
    const y = Math.max(0, Math.min(s - 1.001, v * (s - 1)));
    const x0 = Math.floor(x), y0 = Math.floor(y);
    const fx = x - x0, fy = y - y0;
    const d = grid.elev;
    const v00 = d[y0 * s + x0], v10 = d[y0 * s + x0 + 1];
    const v01 = d[(y0 + 1) * s + x0], v11 = d[(y0 + 1) * s + x0 + 1];
    return (v00 * (1 - fx) + v10 * fx) * (1 - fy) + (v01 * (1 - fx) + v11 * fx) * fy;
}

function normalizeGridStats(grid) {
    let min = Infinity, max = -Infinity;
    for (let i = 0; i < grid.elev.length; i++) {
        if (grid.elev[i] < min) min = grid.elev[i];
        if (grid.elev[i] > max) max = grid.elev[i];
    }
    return { min, max, span: Math.max(1.0, max - min) };
}

function clamp(v, lo, hi) { return v < lo ? lo : (v > hi ? hi : v); }
function smoothstep(e0, e1, x) {
    const t = clamp((x - e0) / (e1 - e0), 0.0, 1.0);
    return t * t * (3.0 - 2.0 * t);
}
function lerp(a, b, t) { return a + (b - a) * t; }

async function main() {
    console.log('Downloading real NASA SRTM Terrarium tiles from AWS Open Data...');
    // 1. Frozen Pass (NW): Pennine Alps / Matterhorn & Zermatt ridges (Zoom 12, 2x2 tiles -> ~12km)
    const alpine = await fetchDemMosaic(7.658, 45.976, 12, 2);
    const alpineStats = normalizeGridStats(alpine);
    console.log(`  [Alps SRTM] ${alpineStats.min.toFixed(0)}m .. ${alpineStats.max.toFixed(0)}m`);

    // 2. Volcano Ridge (NE): Nevado de Toluca Volcanic Caldera, Mexico (Zoom 12, 2x2 tiles)
    const volcano = await fetchDemMosaic(-99.758, 19.108, 12, 2);
    const volStats = normalizeGridStats(volcano);
    console.log(`  [Nevado de Toluca SRTM] ${volStats.min.toFixed(0)}m .. ${volStats.max.toFixed(0)}m`);

    // 3. Dust Bowl (SW): Monument Valley / Utah-Arizona Red Rock Mesas (Zoom 12, 2x2 tiles)
    const desert = await fetchDemMosaic(-110.10, 36.99, 12, 2);
    const desStats = normalizeGridStats(desert);
    console.log(`  [Monument Valley SRTM] ${desStats.min.toFixed(0)}m .. ${desStats.max.toFixed(0)}m`);

    // 4. Neon Coast (SE): Big Sur Coastal Cliffs & Bluffs (Zoom 12, 2x2 tiles)
    const coast = await fetchDemMosaic(-121.81, 36.27, 12, 2);
    const coastStats = normalizeGridStats(coast);
    console.log(`  [Big Sur Coast SRTM] ${coastStats.min.toFixed(0)}m .. ${coastStats.max.toFixed(0)}m`);

    const heights = new Float32Array(OUT_SIZE * OUT_SIZE);

    for (let py = 0; py < OUT_SIZE; py++) {
        const wz = ((py / (OUT_SIZE - 1)) * 2.0 - 1.0) * HALF_WORLD;
        const wSouth = clamp((wz + 320.0) / 640.0, 0.0, 1.0);
        for (let px = 0; px < OUT_SIZE; px++) {
            const wx = ((px / (OUT_SIZE - 1)) * 2.0 - 1.0) * HALF_WORLD;
            const wEast = clamp((wx + 320.0) / 640.0, 0.0, 1.0);

            // Normalized coordinates within each quadrant for sampling the SRTM mosaics cleanly
            const uNW = clamp((-wx) / HALF_WORLD, 0.05, 0.95);
            const vNW = clamp((-wz) / HALF_WORLD, 0.05, 0.95);
            const rawAlpine = (sampleBilinear(alpine, uNW, vNW) - alpineStats.min) / alpineStats.span;
            const hNW = 42.0 + Math.pow(rawAlpine, 1.15) * 195.0;

            // Volcano mosaic centered around colossal 320m La Gran Caldera cone at (+980, -1140)
            // while Volcano Scenic Highway skirts cleanly along its SE flank!
            const uNE = clamp((wx - 1100.0) / (HALF_WORLD * 1.05) + 0.5, 0.02, 0.98);
            const vNE = clamp((-wz - 1100.0) / (HALF_WORLD * 1.05) + 0.5, 0.02, 0.98);
            const rawVol = (sampleBilinear(volcano, uNE, vNE) - volStats.min) / volStats.span;
            const distVol = Math.hypot(wx - 980.0, wz + 1140.0);
            const coneBoost = clamp(1.0 - distVol / 880.0, 0.0, 1.0);
            const craterDip = Math.pow(clamp(1.0 - distVol / 215.0, 0.0, 1.0), 1.45);
            const calderaFloor = clamp(1.0 - distVol / 110.0, 0.0, 1.0);
            const hNE = 44.0 + Math.pow(rawVol, 1.15) * 120.0 + Math.pow(coneBoost, 1.18) * 185.0 - craterDip * 112.0 + calderaFloor * 14.0;

            // Monument Valley mesa & desert canyon wash silhouette (dramatic terraced cliff mesas + flat drivable basins)
            const uSW = clamp((-wx) / HALF_WORLD, 0.04, 0.96);
            const vSW = clamp((wz) / HALF_WORLD, 0.04, 0.96);
            const rawDes = (sampleBilinear(desert, uSW, vSW) - desStats.min) / desStats.span;
            const terrace = smoothstep(0.32, 0.44, rawDes) * 44.0 + smoothstep(0.62, 0.72, rawDes) * 32.0;
            const hSW = 14.0 + rawDes * 24.0 + terrace;

            // Big Sur coastal foothills sloping down cleanly to curved sandy beach & turquoise sea
            const uSE = clamp((wx) / HALF_WORLD, 0.05, 0.95);
            const vSE = clamp((wz) / HALF_WORLD, 0.05, 0.95);
            const rawCoast = (sampleBilinear(coast, uSE, vSE) - coastStats.min) / coastStats.span;
            const coastCurveX = 2160.0 - 0.00014 * (wz - 200.0) * (wz - 200.0);
            const shoreX = coastCurveX + 48.0 + Math.sin(wz * 0.004) * 18.0;
            const bayDrop = smoothstep(shoreX - 35.0, shoreX + 125.0, wx);
            // Keep inland road corridor safe (4.5m..22m) while ocean seabed drops cleanly to -3.6m
            const inlandCoastH = 5.5 + rawCoast * 16.0;
            const hSE = lerp(inlandCoastH, -3.6, bayDrop);

            const hNorth = lerp(hNW, hNE, wEast);
            const hSouth = lerp(hSW, hSE, wEast);
            let finalH = lerp(hNorth, hSouth, wSouth);

            // Smooth Central Festival Hub Arena at (0, 0) anchored at exactly 22.0m
            const distHub = Math.hypot(wx, wz);
            if (distHub < 460.0) {
                const hubT = smoothstep(145.0, 460.0, distHub);
                finalH = lerp(22.0, finalH, hubT);
            }

            heights[py * OUT_SIZE + px] = clamp(finalH, MIN_H, MAX_H);
        }
    }

    // Simple D8 downhill flow accumulation pass to detect natural gullies, washes, & erosion channels
    const flow = new Float32Array(OUT_SIZE * OUT_SIZE).fill(1.0);
    const order = new Int32Array(OUT_SIZE * OUT_SIZE);
    for (let i = 0; i < order.length; i++) order[i] = i;
    order.sort((a, b) => heights[b] - heights[a]);
    const dirs = [[-1, -1], [0, -1], [1, -1], [-1, 0], [1, 0], [-1, 1], [0, 1], [1, 1]];
    for (let k = 0; k < order.length; k++) {
        const idx = order[k];
        const x = idx % OUT_SIZE, y = (idx / OUT_SIZE) | 0;
        let bestIdx = -1, bestH = heights[idx];
        for (const [dx, dy] of dirs) {
            const nx = x + dx, ny = y + dy;
            if (nx >= 0 && nx < OUT_SIZE && ny >= 0 && ny < OUT_SIZE) {
                const nIdx = ny * OUT_SIZE + nx;
                if (heights[nIdx] < bestH) { bestH = heights[nIdx]; bestIdx = nIdx; }
            }
        }
        if (bestIdx >= 0) flow[bestIdx] += flow[idx];
    }

    // Encode RGBA PNG:
    // R = hi byte (16-bit normalized height), G = lo byte
    // B = hydrological gully/wash mask (0..255), A = ridge/concavity curvature factor (0..255)
    const rgba = Buffer.alloc(OUT_SIZE * OUT_SIZE * 4);
    for (let y = 0; y < OUT_SIZE; y++) {
        for (let x = 0; x < OUT_SIZE; x++) {
            const idx = y * OUT_SIZE + x;
            const norm = clamp((heights[idx] - MIN_H) / (MAX_H - MIN_H), 0.0, 1.0);
            const h16 = Math.round(norm * 65535);
            const fNorm = clamp(Math.log1p(flow[idx]) / 6.5, 0.0, 1.0);

            // Local curvature: positive if ridge/peak, negative if valley
            let avgNbr = heights[idx];
            if (x > 0 && x < OUT_SIZE - 1 && y > 0 && y < OUT_SIZE - 1) {
                avgNbr = 0.25 * (heights[idx - 1] + heights[idx + 1] + heights[idx - OUT_SIZE] + heights[idx + OUT_SIZE]);
            }
            const curv = clamp(0.5 + (heights[idx] - avgNbr) * 0.14, 0.0, 1.0);

            const oi = idx * 4;
            rgba[oi] = (h16 >> 8) & 0xff;
            rgba[oi + 1] = h16 & 0xff;
            rgba[oi + 2] = Math.round(fNorm * 255);
            rgba[oi + 3] = Math.round(curv * 255);
        }
    }

    fs.mkdirSync(path.dirname(OUT_PATH), { recursive: true });
    fs.writeFileSync(OUT_PATH, encodeRgbaPng(OUT_SIZE, OUT_SIZE, rgba));
    console.log(`\n[OK] Saved 1024x1024 real-world NASA SRTM DEM to ${OUT_PATH} (${(fs.statSync(OUT_PATH).size / 1024).toFixed(1)} KB)`);
}

main().catch((e) => { console.error(e); process.exit(1); });
