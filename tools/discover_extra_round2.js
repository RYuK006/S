// tools/discover_extra_round2.js
// Round 2 targeted discovery for 6 backup cars (Supra, Mercedes G63/AMG GT, Camaro ZL1, Focus RS, Lancia Delta, Trophy Truck)
// AND 28+ extra high-quality outdoor/town/highway/festival/biome props via Sketchfab & exact Poly Haven IDs.
const https = require('https');
const fs = require('fs');
const path = require('path');

const SF_TOKEN = '4591437114654bf29d34a235f90acf6c';
const CAR_DIR = path.resolve(__dirname, '..', 'build', 'sf_car_previews');
const PROP_DIR = path.resolve(__dirname, '..', 'build', 'sf_prop_previews');
fs.mkdirSync(CAR_DIR, { recursive: true });
fs.mkdirSync(PROP_DIR, { recursive: true });

function fetchJson(url, useAuth = false) {
    return new Promise((resolve, reject) => {
        const headers = { 'User-Agent': 'GRIDLETHAL/1.0' };
        if (useAuth) headers['Authorization'] = `Token ${SF_TOKEN}`;
        https.get(url, { headers }, (res) => {
            let body = '';
            res.on('data', c => body += c);
            res.on('end', () => {
                if (res.statusCode !== 200) reject(new Error(`HTTP ${res.statusCode}`));
                else resolve(JSON.parse(body));
            });
        }).on('error', reject);
    });
}

function downloadFile(url, dest) {
    return new Promise((resolve, reject) => {
        https.get(url, { headers: { 'User-Agent': 'GRIDLETHAL/1.0' } }, (res) => {
            if (res.statusCode >= 300 && res.statusCode < 400 && res.headers.location) {
                return downloadFile(res.headers.location, dest).then(resolve, reject);
            }
            if (res.statusCode !== 200) return reject(new Error(`HTTP ${res.statusCode}`));
            const file = fs.createWriteStream(dest);
            res.pipe(file);
            file.on('finish', () => file.close(resolve));
        }).on('error', reject);
    });
}

const BAD_RE = /low\s*poly|lowpoly|cartoon|toon|stylized|minecraft|voxel|lego|chibi|toy|anime|diorama|pack\b|collection|chassis\b|wheel\s*only|rim\s*only/i;

const EXTRA_CARS = [
    { slug: 'toyota_supra_a80', q: 'toyota supra a80 1998', archetype: 'JDM Street', targetLen: 4.52 },
    { slug: 'mercedes_amg_gtr', q: 'mercedes-benz amg gt', archetype: 'GT Tourer', targetLen: 4.55 },
    { slug: 'mercedes_g63_amg', q: 'mercedes g-class g63', archetype: 'Offroad & Trucks', targetLen: 4.82 },
    { slug: 'chevy_camaro_ss', q: 'chevrolet camaro ss', archetype: 'Muscle Bruiser', targetLen: 4.78 },
    { slug: 'ford_focus_rs', q: 'ford focus rs', archetype: 'Rally Special', targetLen: 4.39 },
    { slug: 'lancia_delta_hf', q: 'lancia delta integrale', archetype: 'Rally Special', targetLen: 3.90 },
    { slug: 'chevy_corvette_c7', q: 'corvette stingray z06', archetype: 'Supercar Track', targetLen: 4.51 },
    { slug: 'baja_trophy_truck', q: 'ford raptor trophy truck baja', archetype: 'Offroad & Trucks', targetLen: 4.85 }
];

const EXTRA_PROPS = [
    { slug: 'concrete_road_dividers', q: 'concrete jersey barrier', cat: 'HEAVY_SLIDE', biome: 'highway' },
    { slug: 'wooden_barrel_oak', q: 'wooden barrel', cat: 'WOOD_SPLINTER', biome: 'town' },
    { slug: 'metal_dumpster_green', q: 'dumpster garbage container', cat: 'HEAVY_SLIDE', biome: 'town' },
    { slug: 'street_vending_machine', q: 'vending machine', cat: 'HEAVY_SLIDE', biome: 'town' },
    { slug: 'electric_transformer_box', q: 'electrical utility box street', cat: 'SOLID_BUILDING', biome: 'town' },
    { slug: 'road_construction_barrier', q: 'construction barrier sign', cat: 'WOOD_SPLINTER', biome: 'highway' },
    { slug: 'wooden_picnic_table', q: 'wooden picnic table', cat: 'WOOD_SPLINTER', biome: 'hub' },
    { slug: 'park_bench_iron', q: 'park bench cast iron', cat: 'WOOD_SPLINTER', biome: 'town' },
    { slug: 'wooden_warehouse_shed', q: 'wooden barn shed building', cat: 'SOLID_BUILDING', biome: 'desert' },
    { slug: 'town_house_stucco', q: 'residential house building facade', cat: 'SOLID_BUILDING', biome: 'town' },
    { slug: 'modern_shop_building', q: 'commercial shop building', cat: 'SOLID_BUILDING', biome: 'town' },
    { slug: 'radio_tower_lattice', q: 'radio communication tower lattice', cat: 'SOLID_BUILDING', biome: 'volcano' },
    { slug: 'steel_shipping_tank', q: 'industrial water tank steel', cat: 'SOLID_BUILDING', biome: 'port' },
    { slug: 'wooden_utility_pole_sf', q: 'wooden telephone pole', cat: 'POLE_SNAP', biome: 'highway' },
    { slug: 'speed_camera_gantry', q: 'traffic signal gantry', cat: 'SOLID_SIGN_PORTAL', biome: 'highway' },
    { slug: 'podium_race_stage', q: 'music festival stage truss', cat: 'SOLID_BUILDING', biome: 'hub' },
    { slug: 'racing_flag_banner', q: 'racing flag banner', cat: 'LIGHT_PLASTIC_FLICK', biome: 'hub' },
    { slug: 'beach_parasol_umbrella', q: 'beach umbrella chair', cat: 'WOOD_SPLINTER', biome: 'coast' },
    { slug: 'wooden_boat_rowboat', q: 'wooden boat', cat: 'WOOD_SPLINTER', biome: 'coast' },
    { slug: 'joshua_desert_tree', q: 'joshua tree desert', cat: 'TREE_SNAP', biome: 'desert' },
    { slug: 'volcano_lava_rock', q: 'volcanic basalt rock', cat: 'SOLID_ROCK', biome: 'volcano' },
    { slug: 'alpine_snow_rock', q: 'snowy granite boulder', cat: 'SOLID_ROCK', biome: 'snow' },
    { slug: 'metal_generator_yellow', q: 'power generator industrial', cat: 'HEAVY_SLIDE', biome: 'hub' },
    { slug: 'cable_spool_wood', q: 'cable reel wood', cat: 'WOOD_SPLINTER', biome: 'port' },
    { slug: 'stack_tires_racing', q: 'rubber tires stack', cat: 'LIGHT_PLASTIC_FLICK', biome: 'hub' },
    { slug: 'gas_pump_retro', q: 'fuel gas pump', cat: 'EXPLOSIVE_DRUM', biome: 'highway' },
    { slug: 'alpine_wooden_cabin', q: 'log cabin house', cat: 'SOLID_BUILDING', biome: 'snow' },
    { slug: 'corrugated_metal_fence', q: 'corrugated metal fence', cat: 'WOOD_SPLINTER', biome: 'port' }
];

async function searchSf(q, minFaces, maxFaces, maxSizeMb) {
    const url = `https://api.sketchfab.com/v3/search?type=models&downloadable=true&q=${encodeURIComponent(q)}&sort_by=-likeCount&count=16`;
    const data = await fetchJson(url, true);
    const out = [];
    for (const m of (data.results || [])) {
        if (BAD_RE.test(m.name || '')) continue;
        const fc = m.faceCount || 0;
        if (fc < minFaces || fc > maxFaces) continue;
        const sizeMb = m.archives && m.archives.gltf ? (m.archives.gltf.size || 0) / (1024 * 1024) : 999;
        if (sizeMb > maxSizeMb) continue;
        out.push({ m, fc, sizeMb });
    }
    return out;
}

async function main() {
    const extraCarsOut = [];
    for (let i = 0; i < EXTRA_CARS.length; i++) {
        const spec = EXTRA_CARS[i];
        try {
            const cands = await searchSf(spec.q, 14000, 190000, 48);
            if (!cands.length) { console.log(`[CAR SKIP] ${spec.slug}`); continue; }
            const top = cands[0];
            const thumbs = (top.m.thumbnails && top.m.thumbnails.images) || [];
            thumbs.sort((a, b) => b.width - a.width);
            const pickThumb = thumbs.find(t => t.width <= 640 && t.width >= 320) || thumbs[0];
            const fname = `r2_${String(i + 1).padStart(2, '0')}_${spec.slug}_${top.m.uid}.jpg`;
            if (pickThumb && pickThumb.url) await downloadFile(pickThumb.url, path.join(CAR_DIR, fname));
            extraCarsOut.push({ ...spec, uid: top.m.uid, name: top.m.name, faces: top.fc, sizeMb: Number(top.sizeMb.toFixed(1)), thumbFile: fname });
            console.log(`[CAR R2] ${spec.slug} | ${top.fc} faces | ${top.sizeMb.toFixed(1)} MB | "${top.m.name}"`);
        } catch (e) { console.log(`[CAR ERR] ${spec.slug}: ${e.message}`); }
    }

    const extraPropsOut = [];
    for (let i = 0; i < EXTRA_PROPS.length; i++) {
        const spec = EXTRA_PROPS[i];
        try {
            const cands = await searchSf(spec.q, 120, 45000, 24);
            if (!cands.length) { console.log(`[PROP SKIP] ${spec.slug}`); continue; }
            const top = cands[0];
            const thumbs = (top.m.thumbnails && top.m.thumbnails.images) || [];
            thumbs.sort((a, b) => b.width - a.width);
            const pickThumb = thumbs.find(t => t.width <= 640 && t.width >= 300) || thumbs[0];
            const fname = `r2_${String(i + 1).padStart(2, '0')}_${spec.slug}_${top.m.uid}.jpg`;
            if (pickThumb && pickThumb.url) await downloadFile(pickThumb.url, path.join(PROP_DIR, fname));
            extraPropsOut.push({ source: 'sketchfab', ...spec, uid: top.m.uid, name: top.m.name, faces: top.fc, sizeMb: Number(top.sizeMb.toFixed(1)), thumbFile: fname });
            console.log(`[PROP R2] ${spec.slug} | ${top.fc} faces | ${top.sizeMb.toFixed(1)} MB | "${top.m.name}"`);
        } catch (e) { console.log(`[PROP ERR] ${spec.slug}: ${e.message}`); }
    }

    fs.writeFileSync(path.resolve(__dirname, '..', 'build', 'sf_round2_candidates.json'), JSON.stringify({ cars: extraCarsOut, props: extraPropsOut }, null, 2));
    console.log(`Saved R2: ${extraCarsOut.length} cars, ${extraPropsOut.length} props`);
}
main().catch((e) => { console.error(e); process.exit(1); });
