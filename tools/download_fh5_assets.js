// tools/download_fh5_assets.js
const https = require('https');
const fs = require('fs');
const path = require('path');

const SF_TOKEN = '4591437114654bf29d34a235f90acf6c';
const ROOT = path.join(__dirname, '..');

function fetchJson(url, headers = {}) {
    return new Promise((resolve, reject) => {
        https.get(url, { headers: { 'User-Agent': 'GridlethalAssetSync/1.0', ...headers } }, res => {
            if (res.statusCode >= 300 && res.statusCode < 400 && res.headers.location) {
                return resolve(fetchJson(res.headers.location, headers));
            }
            if (res.statusCode !== 200) return reject(new Error(`HTTP ${res.statusCode} for ${url}`));
            let d = '';
            res.on('data', c => d += c);
            res.on('end', () => { try { resolve(JSON.parse(d)); } catch (e) { reject(e); } });
        }).on('error', reject);
    });
}

function downloadFile(url, dest) {
    return new Promise((resolve, reject) => {
        fs.mkdirSync(path.dirname(dest), { recursive: true });
        https.get(url, { headers: { 'User-Agent': 'GridlethalAssetSync/1.0' } }, res => {
            if (res.statusCode >= 300 && res.statusCode < 400 && res.headers.location) {
                return resolve(downloadFile(res.headers.location, dest));
            }
            if (res.statusCode !== 200) return reject(new Error(`HTTP ${res.statusCode} downloading ${url}`));
            const tmp = dest + '.part';
            const f = fs.createWriteStream(tmp);
            res.pipe(f);
            f.on('finish', () => {
                f.close(() => {
                    fs.renameSync(tmp, dest);
                    resolve(dest);
                });
            });
            f.on('error', err => {
                f.close(() => { try { fs.unlinkSync(tmp); } catch(_) {} reject(err); });
            });
        }).on('error', reject);
    });
}

async function downloadPolyHavenModel(id, destSubDir) {
    const outDir = path.join(ROOT, 'assets', 'models', destSubDir, id);
    const gltfDest = path.join(outDir, `${id}.gltf`);
    if (fs.existsSync(gltfDest) && fs.statSync(gltfDest).size > 500) {
        console.log(`[SKIP] PH Model ${id}`);
        return;
    }
    console.log(`[PH MODEL] Downloading ${id} -> assets/models/${destSubDir}/${id}/`);
    const info = await fetchJson(`https://api.polyhaven.com/files/${id}`);
    const gInfo = info.gltf && (info.gltf['1k'] || info.gltf['2k']);
    if (!gInfo || !gInfo.gltf) throw new Error(`No glTF found for ${id}`);
    const entry = gInfo.gltf;
    await downloadFile(entry.url, gltfDest);
    const includes = entry.include || {};
    for (const [relPath, fileObj] of Object.entries(includes)) {
        const target = path.join(outDir, relPath);
        await downloadFile(fileObj.url, target);
    }
    console.log(`  [OK] ${id} (${Object.keys(includes).length + 1} files)`);
}

async function downloadPolyHavenTexture2k(phId, localBaseName) {
    const texDir = path.join(ROOT, 'assets', 'textures');
    console.log(`[PH TEX 2K] Downloading ${phId} -> ${localBaseName}_{diff,nor,rough}.jpg`);
    const info = await fetchJson(`https://api.polyhaven.com/files/${phId}`);
    const diffUrl = info.Diffuse && info.Diffuse['2k'] && info.Diffuse['2k'].jpg && info.Diffuse['2k'].jpg.url;
    const norUrl = info.nor_gl && info.nor_gl['2k'] && info.nor_gl['2k'].jpg && info.nor_gl['2k'].jpg.url;
    const roughUrl = info.Rough && info.Rough['2k'] && info.Rough['2k'].jpg && info.Rough['2k'].jpg.url;
    if (diffUrl) await downloadFile(diffUrl, path.join(texDir, `${localBaseName}_diff.jpg`));
    if (norUrl) await downloadFile(norUrl, path.join(texDir, `${localBaseName}_nor.jpg`));
    if (roughUrl) await downloadFile(roughUrl, path.join(texDir, `${localBaseName}_rough.jpg`));
    console.log(`  [OK] ${localBaseName}`);
}

async function downloadSketchfabGlb(uid, destRelPath) {
    const dest = path.join(ROOT, destRelPath);
    if (fs.existsSync(dest) && fs.statSync(dest).size > 100000) {
        console.log(`[SKIP] SF GLB ${destRelPath}`);
        return;
    }
    console.log(`[SF GLB] Fetching download link for ${uid} -> ${destRelPath}`);
    const info = await fetchJson(`https://api.sketchfab.com/v3/models/${uid}/download`, { 'Authorization': `Token ${SF_TOKEN}` });
    if (!info.glb || !info.glb.url) throw new Error(`No GLB URL for ${uid}`);
    await downloadFile(info.glb.url, dest);
    console.log(`  [OK] ${destRelPath} (${(fs.statSync(dest).size / 1048576).toFixed(2)} MB)`);
}

async function main() {
    // 1. 4K Dramatic Sunny Cloud Sky HDRI
    const hdriDest = path.join(ROOT, 'assets', 'hdri', 'kloofendal_48d_partly_cloudy_puresky_4k.hdr');
    if (!fs.existsSync(hdriDest)) {
        console.log('[HDRI] Fetching kloofendal_48d_partly_cloudy_puresky 4K HDRI...');
        const hInfo = await fetchJson('https://api.polyhaven.com/files/kloofendal_48d_partly_cloudy_puresky');
        await downloadFile(hInfo.hdri['4k'].hdr.url, hdriDest);
        console.log(`  [OK] HDRI ${(fs.statSync(hdriDest).size / 1048576).toFixed(2)} MB`);
    }

    // 2. 2K PBR Terrain & Asphalt Textures (upgrading existing 1K maps + adding gravel shoulder & desert/rock detail)
    await downloadPolyHavenTexture2k('aerial_grass_rock', 'grass');
    await downloadPolyHavenTexture2k('coast_sand_rocks_02', 'sand');
    await downloadPolyHavenTexture2k('snow_02', 'snow');
    await downloadPolyHavenTexture2k('aerial_rocks_02', 'volcano');
    await downloadPolyHavenTexture2k('rock_face_03', 'cliff');
    await downloadPolyHavenTexture2k('asphalt_02', 'asphalt');
    await downloadPolyHavenTexture2k('rocky_trail_02', 'gravel');

    // 3. Poly Haven Closed-Mesh Photogrammetry Rocks, Trees, Grass, & Road Props
    const phRocks = ['boulder_01', 'namaqualand_boulder_02', 'namaqualand_boulder_04', 'coast_rocks_01'];
    for (const r of phRocks) await downloadPolyHavenModel(r, 'rocks');

    const phFoliage = ['pine_tree_01', 'fir_tree_01', 'jacaranda_tree', 'quiver_tree_01', 'grass_medium_01', 'shrub_01'];
    for (const f of phFoliage) await downloadPolyHavenModel(f, 'foliage');

    const phProps = ['concrete_road_barrier_02', 'flood_lights'];
    for (const p of phProps) await downloadPolyHavenModel(p, 'props');

    // 4. Sketchfab Foliage + Hero Vehicles (visually verified from thumbnails)
    await downloadSketchfabGlb('386db8a965c443c390b91e2cc2528c7c', 'assets/models/foliage/saguaro_cactus.glb');
    await downloadSketchfabGlb('00bd2ea54eb1405bb056eac3f1e14673', 'assets/models/foliage/mexican_palm.glb');
    await downloadSketchfabGlb('6952780b80594a31aab2dedf7249a47a', 'assets/models/foliage/dry_grass.glb');

    await downloadSketchfabGlb('98b8590146a8447da52a1fefce064f0b', 'assets/models/cars/ford_bronco.glb');
    await downloadSketchfabGlb('5bde9684bf6d40e0902ee8e482ad1063', 'assets/models/cars/ford_raptor.glb');
    await downloadSketchfabGlb('e1486bac59734e188401721aa3efd59f', 'assets/models/cars/subaru_sti.glb');
    await downloadSketchfabGlb('2c1f18d2f0214cb7a746fc5dd2baeebe', 'assets/models/cars/dodge_challenger.glb');

    console.log('\n=== ALL FH5 PHOTOGRAMMETRY ASSETS & VEHICLES DOWNLOADED SUCCESSFULLY! ===');
}

main().catch(e => { console.error(e); process.exit(1); });
