// tools/discover_fh5_props.js
// Searches Sketchfab downloadable PBR models for FH5-grade replacement props and foliage,
// saves small preview thumbnails so visuals can be verified BEFORE downloading any GLB.

const https = require('https');
const fs = require('fs');
const path = require('path');

const SF_TOKEN = '4591437114654bf29d34a235f90acf6c';
const OUT_DIR = path.resolve(__dirname, '..', 'build', 'sf_previews');
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

async function searchCategory(tag, queries) {
    console.log(`\n=== CATEGORY: ${tag} ===`);
    const seen = new Set();
    const candidates = [];
    for (const q of queries) {
        const url = `https://api.sketchfab.com/v3/search?type=models&downloadable=true&q=${encodeURIComponent(q)}&sort_by=-likeCount&count=12`;
        const data = await fetchJson(url);
        for (const m of (data.results || [])) {
            if (seen.has(m.uid)) continue;
            seen.add(m.uid);
            if ((m.faceCount || 0) > 65000 || (m.faceCount || 0) < 20) continue;
            candidates.push(m);
        }
    }
    candidates.sort((a, b) => (b.likeCount || 0) - (a.likeCount || 0));
    const top = candidates.slice(0, 4);
    for (let i = 0; i < top.length; i++) {
        const m = top[i];
        const thumbs = (m.thumbnails && m.thumbnails.images) || [];
        thumbs.sort((a, b) => b.width - a.width);
        const pick = thumbs.find(t => t.width <= 720) || thumbs[0];
        const thumbPath = path.join(OUT_DIR, `${tag}_${i + 1}_${m.uid}.jpg`);
        if (pick && pick.url) {
            await downloadFile(pick.url, thumbPath);
        }
        console.log(`  [${i + 1}] uid=${m.uid} | faces=${m.faceCount} | likes=${m.likeCount} | "${m.name}" -> ${path.basename(thumbPath)}`);
    }
}

async function main() {
    await searchCategory('race_arch', ['racing gantry', 'race start arch', 'pit lane garage', 'grandstand stadium']);
    await searchCategory('container', ['shipping container', 'cargo container rusty', 'harbor crane']);
    await searchCategory('pine', ['pine tree realistic', 'spruce tree', 'fir tree', 'conifer tree']);
    await searchCategory('palm', ['palm tree coconut', 'mexican palm', 'coastal palm tree']);
    await searchCategory('desert_plant', ['agave plant', 'yucca desert', 'joshua tree', 'prickly pear cactus']);
    await searchCategory('volcano_rock', ['volcanic rock', 'basalt cliff', 'obsidian rock', 'canyon rock cliff']);
}

main().catch((e) => { console.error(e); process.exit(1); });
