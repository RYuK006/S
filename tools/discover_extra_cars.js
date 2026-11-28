// tools/discover_extra_cars.js
// Queries Sketchfab API for 45+ distinct photorealistic 3D cars, filters by realistic polycount/size,
// downloads thumbnails for visual inspection, and writes build/sf_car_candidates.json.
const https = require('https');
const fs = require('fs');
const path = require('path');

const SF_TOKEN = '4591437114654bf29d34a235f90acf6c';
const OUT_DIR = path.resolve(__dirname, '..', 'build', 'sf_car_previews');
const JSON_OUT = path.resolve(__dirname, '..', 'build', 'sf_car_candidates.json');
fs.mkdirSync(OUT_DIR, { recursive: true });

function fetchJson(url) {
    return new Promise((resolve, reject) => {
        https.get(url, {
            headers: { 'Authorization': `Token ${SF_TOKEN}`, 'User-Agent': 'GRIDLETHAL/1.0' }
        }, (res) => {
            let body = '';
            res.on('data', (c) => body += c);
            res.on('end', () => {
                if (res.statusCode !== 200) reject(new Error(`HTTP ${res.statusCode}: ${body.slice(0, 200)}`));
                else resolve(JSON.parse(body));
            });
        }).on('error', reject);
    });
}

function downloadFile(url, dest) {
    return new Promise((resolve, reject) => {
        https.get(url, (res) => {
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

const EXISTING_KEYWORDS = [
    'aventador', 'countach', '488 pista', 'mclaren p1', 'nissan gt-r', 'r35', 'mustang gt',
    'challenger', 'bronco', 'raptor', 'bmw m4', 'porsche 911', 'subaru'
];

const CAR_QUERIES = [
    { slug: 'bugatti_chiron', q: 'bugatti chiron', archetype: 'Hypercar Exotics', targetLen: 4.54 },
    { slug: 'koenigsegg_jesko', q: 'koenigsegg', archetype: 'Hypercar Exotics', targetLen: 4.61 },
    { slug: 'pagani_huayra', q: 'pagani huayra', archetype: 'Hypercar Exotics', targetLen: 4.60 },
    { slug: 'porsche_gt3_rs', q: 'porsche 911 gt3 rs', archetype: 'Supercar Track', targetLen: 4.57 },
    { slug: 'audi_r8', q: 'audi r8', archetype: 'Supercar Track', targetLen: 4.43 },
    { slug: 'lamborghini_huracan', q: 'lamborghini huracan', archetype: 'Supercar Track', targetLen: 4.52 },
    { slug: 'ferrari_f40', q: 'ferrari f40', archetype: 'Hypercar Exotics', targetLen: 4.36 },
    { slug: 'aston_vantage', q: 'aston martin vantage', archetype: 'GT Tourer', targetLen: 4.46 },
    { slug: 'corvette_c8', q: 'corvette c8', archetype: 'Supercar Track', targetLen: 4.63 },
    { slug: 'mazda_rx7', q: 'mazda rx7', archetype: 'JDM Street', targetLen: 4.28 },
    { slug: 'toyota_supra_mk4', q: 'toyota supra', archetype: 'JDM Street', targetLen: 4.51 },
    { slug: 'nissan_skyline_r34', q: 'nissan skyline r34', archetype: 'JDM Street', targetLen: 4.60 },
    { slug: 'mitsubishi_evo_x', q: 'mitsubishi lancer evo', archetype: 'Rally Special', targetLen: 4.50 },
    { slug: 'honda_nsx', q: 'honda nsx', archetype: 'JDM Street', targetLen: 4.43 },
    { slug: 'nissan_silvia_s15', q: 'nissan silvia', archetype: 'JDM Street', targetLen: 4.44 },
    { slug: 'camaro_zl1', q: 'chevrolet camaro', archetype: 'Muscle Bruiser', targetLen: 4.78 },
    { slug: 'dodge_charger_rt', q: 'dodge charger', archetype: 'Muscle Bruiser', targetLen: 5.05 },
    { slug: 'dodge_viper', q: 'dodge viper', archetype: 'Muscle Bruiser', targetLen: 4.46 },
    { slug: 'shelby_cobra', q: 'shelby cobra', archetype: 'Muscle Bruiser', targetLen: 4.02 },
    { slug: 'ford_gt', q: 'ford gt 2017', archetype: 'Hypercar Exotics', targetLen: 4.76 },
    { slug: 'mercedes_amg_gt', q: 'mercedes amg gt', archetype: 'GT Tourer', targetLen: 4.54 },
    { slug: 'bmw_m3_e46', q: 'bmw m3', archetype: 'GT Tourer', targetLen: 4.49 },
    { slug: 'alfa_giulia', q: 'alfa romeo giulia', archetype: 'GT Tourer', targetLen: 4.64 },
    { slug: 'jeep_wrangler', q: 'jeep wrangler', archetype: 'Offroad & Trucks', targetLen: 4.34 },
    { slug: 'land_rover_defender', q: 'land rover defender', archetype: 'Offroad & Trucks', targetLen: 4.58 },
    { slug: 'mercedes_g63', q: 'mercedes g63 g wagon', archetype: 'Offroad & Trucks', targetLen: 4.81 },
    { slug: 'hummer_h1', q: 'humvee hummer h1', archetype: 'Offroad & Trucks', targetLen: 4.68 },
    { slug: 'rally_lancia_stratos', q: 'lancia stratos', archetype: 'Rally Special', targetLen: 3.71 },
    { slug: 'audi_quattro_s1', q: 'audi quattro', archetype: 'Rally Special', targetLen: 4.40 },
    { slug: 'porsche_959', q: 'porsche 959', archetype: 'Rally Special', targetLen: 4.26 },
    { slug: 'volkswagen_golf_gti', q: 'volkswagen golf gti', archetype: 'Rally Special', targetLen: 4.28 },
    { slug: 'subaru_brz', q: 'subaru brz gt86', archetype: 'JDM Street', targetLen: 4.24 },
    { slug: 'lotus_evora', q: 'lotus emira evora', archetype: 'Supercar Track', targetLen: 4.39 },
    { slug: 'polaris_rzr_buggy', q: 'baja trophy truck buggy', archetype: 'Offroad & Trucks', targetLen: 4.60 },
    { slug: 'ram_trx_pickup', q: 'dodge ram pickup truck', archetype: 'Offroad & Trucks', targetLen: 5.45 },
    { slug: 'mclaren_720s', q: 'mclaren 720s', archetype: 'Hypercar Exotics', targetLen: 4.54 },
    { slug: 'ferrari_laferrari', q: 'laferrari', archetype: 'Hypercar Exotics', targetLen: 4.70 },
    { slug: 'bmw_m5_cs', q: 'bmw m5', archetype: 'GT Tourer', targetLen: 4.96 },
    { slug: 'jaguar_ftype', q: 'jaguar f-type', archetype: 'GT Tourer', targetLen: 4.47 },
    { slug: 'honda_civic_type_r', q: 'civic type r', archetype: 'JDM Street', targetLen: 4.55 }
];

const BAD_RE = /low\s*poly|lowpoly|cartoon|toon|stylized|minecraft|voxel|lego|chibi|toy|rc\s*car|pack\b|collection|wheel\s*only|rim\s*only|tire\s*only|engine\s*only|interior\s*only|wreck|rusted\s*shell|scrap|burnt|hot\s*wheels|micro\s*machine/i;

async function main() {
    const picked = [];
    const usedUids = new Set();

    for (const item of CAR_QUERIES) {
        const url = `https://api.sketchfab.com/v3/search?type=models&downloadable=true&q=${encodeURIComponent(item.q)}&sort_by=-likeCount&count=16`;
        try {
            const data = await fetchJson(url);
            const candidates = [];
            for (const m of (data.results || [])) {
                if (usedUids.has(m.uid)) continue;
                const name = m.name || '';
                if (BAD_RE.test(name)) continue;
                const fc = m.faceCount || 0;
                if (fc < 14000 || fc > 220000) continue;
                const gltfArch = m.archives && m.archives.gltf;
                const sizeMb = gltfArch ? (gltfArch.size || 0) / (1024 * 1024) : 999;
                if (sizeMb > 55) continue;
                candidates.push({ m, fc, sizeMb });
            }
            // Prefer models between 25k and 120k faces with high likes
            candidates.sort((a, b) => {
                const aScore = (a.m.likeCount || 0) + (a.fc >= 25000 && a.fc <= 125000 ? 150 : 0);
                const bScore = (b.m.likeCount || 0) + (b.fc >= 25000 && b.fc <= 125000 ? 150 : 0);
                return bScore - aScore;
            });
            if (candidates.length === 0) {
                console.log(`[SKIP] ${item.slug}: no valid candidate`);
                continue;
            }
            const top = candidates.slice(0, 2);
            for (let i = 0; i < top.length; i++) {
                const c = top[i];
                if (usedUids.has(c.m.uid)) continue;
                usedUids.add(c.m.uid);
                const thumbs = (c.m.thumbnails && c.m.thumbnails.images) || [];
                thumbs.sort((a, b) => b.width - a.width);
                const pickThumb = thumbs.find(t => t.width <= 640 && t.width >= 320) || thumbs[0];
                const fname = `${String(picked.length + 1).padStart(2, '0')}_${item.slug}_${i}_${c.m.uid}.jpg`;
                const thumbPath = path.join(OUT_DIR, fname);
                if (pickThumb && pickThumb.url) {
                    await downloadFile(pickThumb.url, thumbPath);
                }
                picked.push({
                    idx: picked.length + 1,
                    slug: i === 0 ? item.slug : `${item.slug}_alt`,
                    archetype: item.archetype,
                    targetLen: item.targetLen,
                    uid: c.m.uid,
                    name: c.m.name,
                    faces: c.fc,
                    likes: c.m.likeCount || 0,
                    sizeMb: Number(c.sizeMb.toFixed(1)),
                    thumbFile: fname
                });
                console.log(`[${picked.length}] ${item.slug}${i === 0 ? '' : '_alt'} | ${c.fc} faces | ${c.sizeMb.toFixed(1)} MB | likes=${c.m.likeCount} | "${c.m.name}"`);
                break; // take best 1 per slug first, fallback list separately if needed
            }
        } catch (err) {
            console.log(`[ERR] ${item.slug}: ${err.message}`);
        }
    }

    fs.writeFileSync(JSON_OUT, JSON.stringify({ count: picked.length, candidates: picked }, null, 2));
    console.log(`Saved ${picked.length} car candidates to ${JSON_OUT}`);
}

main().catch((e) => { console.error(e); process.exit(1); });
