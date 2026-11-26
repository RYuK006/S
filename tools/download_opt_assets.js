// tools/download_opt_assets.js
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
            if (res.statusCode !== 200) return reject(new Error(`HTTP ${res.statusCode}`));
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
            const f = fs.createWriteStream(dest);
            res.pipe(f);
            f.on('finish', () => { f.close(() => resolve(dest)); });
        }).on('error', reject);
    });
}

async function dl(uid, destRel) {
    const dest = path.join(ROOT, destRel);
    const info = await fetchJson(`https://api.sketchfab.com/v3/models/${uid}/download`, { 'Authorization': `Token ${SF_TOKEN}` });
    if (!info.glb || !info.glb.url) throw new Error(`No GLB for ${uid}`);
    await downloadFile(info.glb.url, dest);
    console.log(`[OK] ${destRel} (${(fs.statSync(dest).size / 1048576).toFixed(2)} MB)`);
}

async function main() {
    await dl('dc3fbd9205cf4027a4455d1f415e0478', 'assets/models/foliage/pine_tree_opt.glb');
    await dl('26e787f2ff2e4c0fb004c3b0210805a3', 'assets/models/foliage/palm_tree_opt.glb');
    await dl('5a48baa2943b44c3826bcf7ade1074e3', 'assets/models/foliage/desert_bush.glb');
    await dl('bd4ed8d982154f41abb11c5689a7fd83', 'assets/models/rocks/desert_rock_set.glb');
    await dl('ecb35b3e5b424f9dbf54174e6c5907de', 'assets/models/props/starting_line_gantry.glb');
    await dl('c25451c9c53249b4a040b6b27cec259e', 'assets/models/props/festival_truss.glb');
    await dl('16c28f5b3ed24991ac3d1208f4a8bc1f', 'assets/models/cars/ferrari_488_pista.glb');
}
main().catch(e => { console.error(e); process.exit(1); });
