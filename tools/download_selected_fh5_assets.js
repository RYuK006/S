// tools/download_selected_fh5_assets.js
const https = require('https');
const fs = require('fs');
const path = require('path');

const SF_TOKEN = '4591437114654bf29d34a235f90acf6c';
const ROOT = path.resolve(__dirname, '..');

function fetchJson(url, headers = {}) {
    return new Promise((resolve, reject) => {
        https.get(url, { headers: { 'User-Agent': 'GRIDLETHAL/1.0', ...headers } }, (res) => {
            if (res.statusCode >= 300 && res.statusCode < 400 && res.headers.location) {
                return fetchJson(res.headers.location, headers).then(resolve, reject);
            }
            let body = '';
            res.on('data', (c) => body += c);
            res.on('end', () => {
                if (res.statusCode !== 200) reject(new Error(`HTTP ${res.statusCode} ${url}: ${body.slice(0, 200)}`));
                else resolve(JSON.parse(body));
            });
        }).on('error', reject);
    });
}

function downloadFile(url, dest, retries = 3) {
    return new Promise((resolve, reject) => {
        fs.mkdirSync(path.dirname(dest), { recursive: true });
        const tmp = dest + '.tmp';
        https.get(url, (res) => {
            if (res.statusCode >= 300 && res.statusCode < 400 && res.headers.location) {
                return downloadFile(res.headers.location, dest, retries).then(resolve, reject);
            }
            if (res.statusCode !== 200) {
                reject(new Error(`HTTP ${res.statusCode} for ${url}`));
                return;
            }
            const file = fs.createWriteStream(tmp);
            res.pipe(file);
            file.on('finish', () => {
                file.close(() => {
                    fs.renameSync(tmp, dest);
                    resolve();
                });
            });
            res.on('error', (err) => {
                file.close();
                if (fs.existsSync(tmp)) fs.unlinkSync(tmp);
                if (retries > 0) resolve(downloadFile(url, dest, retries - 1));
                else reject(err);
            });
        }).on('error', (err) => {
            if (fs.existsSync(tmp)) fs.unlinkSync(tmp);
            if (retries > 0) resolve(downloadFile(url, dest, retries - 1));
            else reject(err);
        });
    });
}

async function downloadSketchfab(uid, relDest) {
    const dest = path.join(ROOT, relDest);
    if (fs.existsSync(dest) && fs.statSync(dest).size > 4096) {
        console.log(`  [SKIP] ${relDest} already present`);
        return;
    }
    console.log(`  [DL] ${relDest} (uid=${uid})...`);
    const info = await fetchJson(`https://api.sketchfab.com/v3/models/${uid}/download`, { 'Authorization': `Token ${SF_TOKEN}` });
    const glbUrl = info.glb && info.glb.url;
    if (!glbUrl) throw new Error(`No GLB URL for ${uid}`);
    await downloadFile(glbUrl, dest);
    console.log(`  [OK] ${relDest} (${(fs.statSync(dest).size / 1048576).toFixed(2)} MB)`);
}

async function downloadPolyHavenGltf(assetId, subFolder) {
    const dir = path.join(ROOT, 'assets', 'models', subFolder, assetId);
    const gltfDest = path.join(dir, `${assetId}.gltf`);
    if (fs.existsSync(gltfDest) && fs.statSync(gltfDest).size > 256) {
        console.log(`  [SKIP] PolyHaven ${assetId}`);
        return;
    }
    console.log(`  [DL PolyHaven] ${assetId}...`);
    const files = await fetchJson(`https://api.polyhaven.com/files/${assetId}`);
    const gltf = files.gltf && (files.gltf['2k'] || files.gltf['1k']);
    if (!gltf || !gltf.gltf) throw new Error(`No gltf for ${assetId}`);
    await downloadFile(gltf.gltf.url, gltfDest);
    const inc = gltf.gltf.include || {};
    for (const [relPath, entry] of Object.entries(inc)) {
        await downloadFile(entry.url, path.join(dir, relPath));
    }
    console.log(`  [OK PolyHaven] ${assetId}`);
}

async function main() {
    // 1. Visually verified realistic foliage & desert plants
    await downloadSketchfab('da0fe1f2d385483d9bf5626834056653', 'assets/models/foliage/fir_winter_summer.glb');
    await downloadSketchfab('26e787f2ff2e4c0fb004c3b0210805a3', 'assets/models/foliage/coconut_palm.glb');
    await downloadSketchfab('1a0da8faf2c54e65a1d8eb39151b914e', 'assets/models/foliage/yucca_beaked.glb');
    await downloadSketchfab('0292f1b735094500a7a376e0d8dba95a', 'assets/models/foliage/yucca_tall.glb');

    // 2. Visually verified rocks, natural sandstone arch, shipping containers, & tire/catch-fence barriers
    await downloadSketchfab('e7778771c06d4705a80cccb23a471d5c', 'assets/models/rocks/sandstone_arch.glb');
    await downloadSketchfab('62ab177739c948d7978c0d03342dcae3', 'assets/models/rocks/cliff_rocks_pack.glb');
    await downloadSketchfab('2b787d1a02174d0bbca9eac34eb3a486', 'assets/models/props/shipping_container_rust.glb');
    await downloadSketchfab('772f4be391a245f699c54e6cf157c58d', 'assets/models/props/shipping_container_blue.glb');
    await downloadSketchfab('32391f2710b846e58f7b998dee618acb', 'assets/models/props/tire_barrier_wall.glb');
    await downloadSketchfab('85c3967de8c24357acc4371339e73c2e', 'assets/models/props/catchfence_barrier.glb');
    await downloadSketchfab('74759f3b36f741ec82803efe4435f31d', 'assets/models/props/concert_truss.glb');
    await downloadSketchfab('6e0e88fa79c84ae082ef06908ca77650', 'assets/models/props/festival_bleacher.glb');
    await downloadSketchfab('256b7c9e92d54a49af295be120b5ec59', 'assets/models/props/festival_canopy_tent.glb');
    await downloadSketchfab('a67849c73da6482697de7f6f10b7ab82', 'assets/models/props/festival_geodome.glb');

    // 3. Poly Haven high-detail photogrammetry coast rocks & desert/alpine shrubs/trees
    await downloadPolyHavenGltf('coast_rocks_01', 'rocks');
    await downloadPolyHavenGltf('shrub_01', 'foliage');

    console.log('=== ALL VERIFIED FH5 MODELS DOWNLOADED CLEANLY! ===');
}

main().catch((e) => { console.error(e); process.exit(1); });
