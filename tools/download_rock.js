// tools/download_rock.js
const https = require('https');
const fs = require('fs');
const path = require('path');
const token = '4591437114654bf29d34a235f90acf6c';
const uid = 'd1f2ce6f71aa4c19adbdc541cc888194'; // Cliff Rock Boulder Field

async function main() {
    console.log(`Getting download link for ${uid}...`);
    const options = {
        hostname: 'api.sketchfab.com',
        path: `/v3/models/${uid}/download`,
        headers: { 'Authorization': `Token ${token}` }
    };
    
    https.get(options, res => {
        let data = '';
        res.on('data', chunk => data += chunk);
        res.on('end', () => {
            if (res.statusCode !== 200) {
                console.error(`Error status ${res.statusCode}: ${data}`);
                return;
            }
            const info = JSON.parse(data);
            console.log('Available formats:', Object.keys(info));
            const gltfInfo = info.gltf;
            if (!gltfInfo) {
                console.error('No gltf found!');
                return;
            }
            console.log(`Downloading from ${gltfInfo.url.substring(0, 60)}... (expires in ${gltfInfo.expires})`);
            downloadZip(gltfInfo.url, path.join(__dirname, '..', 'assets', 'models', 'props', 'cliff_rock_boulder.zip'));
        });
    }).on('error', err => console.error(err.message));
}

function downloadZip(url, dest) {
    const file = fs.createWriteStream(dest);
    https.get(url, res => {
        if (res.statusCode >= 300 && res.statusCode < 400 && res.headers.location) {
            return downloadZip(res.headers.location, dest);
        }
        res.pipe(file);
        file.on('finish', () => {
            file.close();
            console.log(`Downloaded ZIP to ${dest} (${fs.statSync(dest).size} bytes)`);
            extractZip(dest);
        });
    }).on('error', err => {
        fs.unlink(dest, () => {});
        console.error('Download error:', err.message);
    });
}

function extractZip(zipPath) {
    // We can use powershell Expand-Archive
    const { execSync } = require('child_process');
    const outDir = path.join(__dirname, '..', 'assets', 'models', 'props', 'cliff_rock_temp');
    if (!fs.existsSync(outDir)) fs.mkdirSync(outDir, { recursive: true });
    console.log(`Extracting ${zipPath} to ${outDir}...`);
    execSync(`powershell -Command "Expand-Archive -Path '${zipPath}' -DestinationPath '${outDir}' -Force"`);
    
    // Look for .gltf or scene.gltf/glb
    const files = fs.readdirSync(outDir);
    console.log('Extracted files:', files);
    
    // If scene.gltf exists, convert or keep in props
    const destGlb = path.join(__dirname, '..', 'assets', 'models', 'props', 'cliff_rock_boulder.gltf');
    const sceneGltf = path.join(outDir, 'scene.gltf');
    if (fs.existsSync(sceneGltf)) {
        console.log(`Moving scene.gltf and resources to assets/models/props/cliff_rock/`);
        const finalDir = path.join(__dirname, '..', 'assets', 'models', 'props', 'cliff_rock');
        if (!fs.existsSync(finalDir)) fs.mkdirSync(finalDir, { recursive: true });
        execSync(`powershell -Command "Copy-Item -Path '${outDir}/*' -Destination '${finalDir}' -Recurse -Force"`);
        console.log('Cliff rock boulder assets ready in assets/models/props/cliff_rock/scene.gltf');
    }
}

main();
