// tools/discover_fh5_props_v3.js
// Queries Sketchfab for motorsport stands, festival flags/banners, wood dock piers, harbor cranes, lighthouses.
const https = require('https');
const fs = require('fs');
const path = require('path');

const SF_TOKEN = '4591437114654bf29d34a235f90acf6c';
const OUT_DIR = path.resolve(__dirname, '..', 'build', 'sf_previews_v3');
fs.mkdirSync(OUT_DIR, { recursive: true });

function fetchJson(url) {
    return new Promise((resolve, reject) => {
        https.get(url, { headers: { 'Authorization': `Token ${SF_TOKEN}`, 'User-Agent': 'GRIDLETHAL/1.0' } }, (res) => {
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
            const file = fs.createWriteStream(dest);
            res.pipe(file);
            file.on('finish', () => file.close(resolve));
        }).on('error', reject);
    });
}
async function searchCat(tag, queries, maxFaces = 45000) {
    console.log(`\n=== ${tag} ===`);
    const seen = new Set();
    const list = [];
    for (const q of queries) {
        const url = `https://api.sketchfab.com/v3/search?type=models&downloadable=true&q=${encodeURIComponent(q)}&sort_by=-likeCount&count=12`;
        const data = await fetchJson(url);
        for (const m of (data.results || [])) {
            if (seen.has(m.uid)) continue;
            seen.add(m.uid);
            const fc = m.faceCount || 0;
            if (fc > maxFaces || fc < 40) continue;
            if (/low\s*poly|lowpoly|cartoon|minecraft|voxel/i.test(m.name || '')) continue;
            list.push(m);
        }
    }
    list.sort((a, b) => (b.likeCount || 0) - (a.likeCount || 0));
    const top = list.slice(0, 3);
    for (let i = 0; i < top.length; i++) {
        const m = top[i];
        const thumbs = (m.thumbnails && m.thumbnails.images) || [];
        thumbs.sort((a, b) => b.width - a.width);
        const pick = thumbs.find(t => t.width <= 720) || thumbs[0];
        if (pick && pick.url) await downloadFile(pick.url, path.join(OUT_DIR, `${tag}_${i + 1}_${m.uid}.jpg`));
        console.log(`  [${i + 1}] uid=${m.uid} | faces=${m.faceCount} | likes=${m.likeCount} | "${m.name}"`);
    }
}
async function main() {
    await searchCat('grandstand', ['grandstand', 'bleachers stadium', 'pit stop garage']);
    await searchCat('dock_crane', ['wooden dock', 'gantry crane', 'lighthouse']);
    await searchCat('festival_flag', ['feather flag', 'racing banner', 'canopy tent']);
}
main().catch((e) => { console.error(e); process.exit(1); });
