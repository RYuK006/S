// tools/discover_extra_props.js
// Queries Poly Haven 3D models (CC0 photogrammetry) + Sketchfab photorealistic models
// for 65+ distinct world/street/city/motorsport/nature props, downloads previews, and writes build/sf_prop_candidates.json.
const https = require('https');
const fs = require('fs');
const path = require('path');

const SF_TOKEN = '4591437114654bf29d34a235f90acf6c';
const OUT_DIR = path.resolve(__dirname, '..', 'build', 'sf_prop_previews');
const JSON_OUT = path.resolve(__dirname, '..', 'build', 'sf_prop_candidates.json');
fs.mkdirSync(OUT_DIR, { recursive: true });

function fetchJson(url, useAuth = false) {
    return new Promise((resolve, reject) => {
        const headers = { 'User-Agent': 'GRIDLETHAL/1.0' };
        if (useAuth) headers['Authorization'] = `Token ${SF_TOKEN}`;
        https.get(url, { headers }, (res) => {
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

// Curated queries grouped by biomechanical/destruction behavior + biome
const PROP_SPECS = [
    // Street / Town / Highway Props
    { slug: 'traffic_light_pole', q: 'traffic light pole', cat: 'POLE_SNAP', biome: 'town', scaleHint: 1.0 },
    { slug: 'highway_overhead_sign', q: 'highway gantry sign road', cat: 'SOLID_SIGN_PORTAL', biome: 'highway', scaleHint: 1.0 },
    { slug: 'street_stop_sign', q: 'stop sign street', cat: 'POLE_SNAP', biome: 'town', scaleHint: 1.0 },
    { slug: 'speed_limit_sign', q: 'road sign speed limit', cat: 'POLE_SNAP', biome: 'highway', scaleHint: 1.0 },
    { slug: 'fire_hydrant', q: 'fire hydrant', cat: 'POLE_SNAP', biome: 'town', scaleHint: 1.0 },
    { slug: 'bus_stop_shelter', q: 'bus stop shelter', cat: 'SOLID_BUILDING', biome: 'town', scaleHint: 1.0 },
    { slug: 'street_bench', q: 'park bench wood metal', cat: 'WOOD_SPLINTER', biome: 'town', scaleHint: 1.0 },
    { slug: 'trash_dumpster', q: 'metal dumpster bin', cat: 'HEAVY_SLIDE', biome: 'town', scaleHint: 1.0 },
    { slug: 'steel_bollard', q: 'street bollard', cat: 'POLE_SNAP', biome: 'town', scaleHint: 1.0 },
    { slug: 'mailbox_street', q: 'street mailbox post', cat: 'POLE_SNAP', biome: 'town', scaleHint: 1.0 },
    { slug: 'highway_billboard', q: 'highway billboard', cat: 'SOLID_BUILDING', biome: 'highway', scaleHint: 1.0 },
    { slug: 'guard_booth', q: 'security guard booth', cat: 'SOLID_BUILDING', biome: 'port', scaleHint: 1.0 },
    { slug: 'cafe_storefront', q: 'mexican building facade shop', cat: 'SOLID_BUILDING', biome: 'town', scaleHint: 1.0 },
    { slug: 'town_apartment_block', q: 'urban residential building', cat: 'SOLID_BUILDING', biome: 'town', scaleHint: 1.0 },
    { slug: 'gas_station_canopy', q: 'gas station canopy', cat: 'SOLID_BUILDING', biome: 'highway', scaleHint: 1.0 },
    { slug: 'telegraph_utility_pole', q: 'wooden utility pole', cat: 'POLE_SNAP', biome: 'desert', scaleHint: 1.0 },
    { slug: 'solar_street_panel', q: 'solar panel pole', cat: 'POLE_SNAP', biome: 'desert', scaleHint: 1.0 },
    { slug: 'street_trash_can', q: 'city trash can bin', cat: 'LIGHT_PLASTIC_FLICK', biome: 'town', scaleHint: 1.0 },
    { slug: 'traffic_cone_orange', q: 'traffic cone', cat: 'LIGHT_PLASTIC_FLICK', biome: 'hub', scaleHint: 1.0 },
    { slug: 'plastic_jersey_barrier', q: 'plastic road barrier water', cat: 'LIGHT_PLASTIC_FLICK', biome: 'hub', scaleHint: 1.0 },

    // Motorsport / Festival / Paddock Props
    { slug: 'fuel_drum_red', q: 'metal fuel oil barrel drum', cat: 'EXPLOSIVE_DRUM', biome: 'port', scaleHint: 1.0 },
    { slug: 'propane_gas_tank', q: 'industrial gas cylinder tank', cat: 'EXPLOSIVE_DRUM', biome: 'port', scaleHint: 1.0 },
    { slug: 'wooden_crate_box', q: 'wooden crate box', cat: 'WOOD_SPLINTER', biome: 'port', scaleHint: 1.0 },
    { slug: 'wooden_pallet', q: 'wooden pallet', cat: 'WOOD_SPLINTER', biome: 'port', scaleHint: 1.0 },
    { slug: 'wooden_ranch_fence', q: 'wooden ranch fence', cat: 'WOOD_SPLINTER', biome: 'desert', scaleHint: 1.0 },
    { slug: 'hay_bale_round', q: 'hay bale straw', cat: 'WOOD_SPLINTER', biome: 'desert', scaleHint: 1.0 },
    { slug: 'portable_generator', q: 'diesel generator trailer', cat: 'HEAVY_SLIDE', biome: 'hub', scaleHint: 1.0 },
    { slug: 'cable_reel_spool', q: 'wooden cable drum reel', cat: 'WOOD_SPLINTER', biome: 'port', scaleHint: 1.0 },
    { slug: 'festival_feather_flag', q: 'racing feather flag banner', cat: 'LIGHT_PLASTIC_FLICK', biome: 'hub', scaleHint: 1.0 },
    { slug: 'podium_winner_stage', q: 'racing podium stage', cat: 'SOLID_BUILDING', biome: 'hub', scaleHint: 1.0 },
    { slug: 'sponsor_inflation_arch', q: 'inflatable race arch', cat: 'LIGHT_PLASTIC_FLICK', biome: 'hub', scaleHint: 1.0 },
    { slug: 'portable_toilet', q: 'porta potty portable toilet', cat: 'LIGHT_PLASTIC_FLICK', biome: 'hub', scaleHint: 1.0 },
    { slug: 'marshall_watch_tower', q: 'watchtower race tower', cat: 'SOLID_BUILDING', biome: 'hub', scaleHint: 1.0 },
    { slug: 'loudspeaker_rig', q: 'concert speaker tower', cat: 'HEAVY_SLIDE', biome: 'hub', scaleHint: 1.0 },
    { slug: 'camera_crane_rig', q: 'broadcast camera tower', cat: 'HEAVY_SLIDE', biome: 'hub', scaleHint: 1.0 },

    // Industrial / Harbor / Port Props
    { slug: 'harbor_gantry_crane', q: 'harbor container crane', cat: 'SOLID_BUILDING', biome: 'port', scaleHint: 1.0 },
    { slug: 'coastal_lighthouse', q: 'coastal lighthouse', cat: 'SOLID_BUILDING', biome: 'coast', scaleHint: 1.0 },
    { slug: 'forklift_industrial', q: 'forklift yellow', cat: 'HEAVY_SLIDE', biome: 'port', scaleHint: 1.0 },
    { slug: 'industrial_silo_tank', q: 'fuel storage tank silo', cat: 'SOLID_BUILDING', biome: 'port', scaleHint: 1.0 },
    { slug: 'harbor_mooring_bollard', q: 'harbor mooring cleat bollard', cat: 'SOLID_ROCK', biome: 'port', scaleHint: 1.0 },
    { slug: 'wooden_dock_pier', q: 'wooden pier dock', cat: 'SOLID_BUILDING', biome: 'coast', scaleHint: 1.0 },
    { slug: 'concrete_pipe_stack', q: 'concrete drainage pipe', cat: 'HEAVY_SLIDE', biome: 'port', scaleHint: 1.0 },
    { slug: 'steel_scaffolding', q: 'metal scaffolding', cat: 'WOOD_SPLINTER', biome: 'hub', scaleHint: 1.0 },
    { slug: 'metal_barrier_crowd', q: 'metal crowd barricade', cat: 'LIGHT_PLASTIC_FLICK', biome: 'hub', scaleHint: 1.0 },

    // Biomes / Rural / Architecture / Nature Props
    { slug: 'alpine_log_cabin', q: 'wooden mountain cabin lodge', cat: 'SOLID_BUILDING', biome: 'snow', scaleHint: 1.0 },
    { slug: 'ski_lift_pylon', q: 'ski lift tower pylon', cat: 'SOLID_BUILDING', biome: 'snow', scaleHint: 1.0 },
    { slug: 'snow_marker_pole', q: 'snow marker pole road', cat: 'POLE_SNAP', biome: 'snow', scaleHint: 1.0 },
    { slug: 'desert_windmill', q: 'desert farm windmill', cat: 'SOLID_BUILDING', biome: 'desert', scaleHint: 1.0 },
    { slug: 'adobe_desert_house', q: 'adobe desert house', cat: 'SOLID_BUILDING', biome: 'desert', scaleHint: 1.0 },
    { slug: 'desert_water_tower', q: 'wooden water tower', cat: 'SOLID_BUILDING', biome: 'desert', scaleHint: 1.0 },
    { slug: 'dead_twisted_tree', q: 'dead twisted dry tree', cat: 'TREE_SNAP', biome: 'desert', scaleHint: 1.0 },
    { slug: 'prickly_pear_cactus', q: 'prickly pear cactus', cat: 'CACTUS_BURST', biome: 'desert', scaleHint: 1.0 },
    { slug: 'agave_desert_plant', q: 'agave aloe desert plant', cat: 'CACTUS_BURST', biome: 'desert', scaleHint: 1.0 },
    { slug: 'volcano_basalt_pillar', q: 'basalt rock column cliff', cat: 'SOLID_ROCK', biome: 'volcano', scaleHint: 1.0 },
    { slug: 'volcano_warning_sign', q: 'danger warning road sign', cat: 'POLE_SNAP', biome: 'volcano', scaleHint: 1.0 },
    { slug: 'radio_radar_dish', q: 'communications radio mast tower', cat: 'SOLID_BUILDING', biome: 'volcano', scaleHint: 1.0 },
    { slug: 'weather_research_pod', q: 'research outpost sci fi cabin', cat: 'SOLID_BUILDING', biome: 'volcano', scaleHint: 1.0 },
    { slug: 'coastal_palm_umbrella', q: 'beach thatch umbrella', cat: 'WOOD_SPLINTER', biome: 'coast', scaleHint: 1.0 },
    { slug: 'beach_lifeguard_tower', q: 'lifeguard tower beach', cat: 'WOOD_SPLINTER', biome: 'coast', scaleHint: 1.0 },
    { slug: 'coastal_sailboat_moored', q: 'yacht sailboat parked', cat: 'SOLID_BUILDING', biome: 'coast', scaleHint: 1.0 },
    { slug: 'surfboard_rack', q: 'surfboard stand beach', cat: 'WOOD_SPLINTER', biome: 'coast', scaleHint: 1.0 },
    { slug: 'alpine_spruce_sapling', q: 'young pine sapling spruce', cat: 'TREE_SNAP', biome: 'snow', scaleHint: 1.0 },
    { slug: 'fallen_log_moss', q: 'fallen tree trunk log', cat: 'WOOD_SPLINTER', biome: 'snow', scaleHint: 1.0 },
    { slug: 'wind_turbine_tall', q: 'wind turbine', cat: 'SOLID_BUILDING', biome: 'highway', scaleHint: 1.0 }
];

const BAD_RE = /low\s*poly|lowpoly|cartoon|toon|stylized|minecraft|voxel|lego|chibi|toy|anime|diorama|pack\s*of\s*100/i;

async function main() {
    const phAssets = await fetchJson('https://api.polyhaven.com/assets?t=models').catch(() => ({}));
    console.log('Poly Haven models indexed:', Object.keys(phAssets).length);

    const picked = [];
    const usedUids = new Set();

    for (const spec of PROP_SPECS) {
        // First check if Poly Haven has a great match for crisp photogrammetry prop
        let phMatch = null;
        const terms = spec.q.toLowerCase().split(/\s+/);
        for (const [id, meta] of Object.entries(phAssets)) {
            const hay = (id + ' ' + (meta.name || '') + ' ' + ((meta.tags || []).join(' '))).toLowerCase();
            if (terms.filter(t => t.length > 3 && hay.includes(t)).length >= 2) {
                phMatch = { id, name: meta.name, thumb: `https://cdn.polyhaven.com/asset_img/thumbs/${id}.png?width=512` };
                break;
            }
        }

        if (phMatch && !usedUids.has('ph_' + phMatch.id)) {
            usedUids.add('ph_' + phMatch.id);
            const fname = `${String(picked.length + 1).padStart(2, '0')}_ph_${spec.slug}_${phMatch.id}.png`;
            try {
                await downloadFile(phMatch.thumb, path.join(OUT_DIR, fname));
                picked.push({
                    idx: picked.length + 1,
                    source: 'polyhaven',
                    phId: phMatch.id,
                    slug: spec.slug,
                    cat: spec.cat,
                    biome: spec.biome,
                    name: phMatch.name,
                    thumbFile: fname
                });
                console.log(`[${picked.length}] PH ${spec.slug} (${phMatch.id}) -> "${phMatch.name}"`);
                continue;
            } catch (_) { /* fall through to Sketchfab */ }
        }

        const url = `https://api.sketchfab.com/v3/search?type=models&downloadable=true&q=${encodeURIComponent(spec.q)}&sort_by=-likeCount&count=14`;
        try {
            const data = await fetchJson(url, true);
            const cands = [];
            for (const m of (data.results || [])) {
                if (usedUids.has(m.uid)) continue;
                const name = m.name || '';
                if (BAD_RE.test(name)) continue;
                const fc = m.faceCount || 0;
                if (fc < 180 || fc > 65000) continue;
                const gltfArch = m.archives && m.archives.gltf;
                const sizeMb = gltfArch ? (gltfArch.size || 0) / (1024 * 1024) : 999;
                if (sizeMb > 28) continue;
                cands.push({ m, fc, sizeMb });
            }
            cands.sort((a, b) => (b.m.likeCount || 0) - (a.m.likeCount || 0));
            if (cands.length === 0) {
                console.log(`[SKIP] ${spec.slug}: no match`);
                continue;
            }
            const top = cands[0];
            usedUids.add(top.m.uid);
            const thumbs = (top.m.thumbnails && top.m.thumbnails.images) || [];
            thumbs.sort((a, b) => b.width - a.width);
            const pickThumb = thumbs.find(t => t.width <= 640 && t.width >= 300) || thumbs[0];
            const fname = `${String(picked.length + 1).padStart(2, '0')}_sf_${spec.slug}_${top.m.uid}.jpg`;
            if (pickThumb && pickThumb.url) {
                await downloadFile(pickThumb.url, path.join(OUT_DIR, fname));
            }
            picked.push({
                idx: picked.length + 1,
                source: 'sketchfab',
                uid: top.m.uid,
                slug: spec.slug,
                cat: spec.cat,
                biome: spec.biome,
                name: top.m.name,
                faces: top.fc,
                likes: top.m.likeCount || 0,
                sizeMb: Number(top.sizeMb.toFixed(1)),
                thumbFile: fname
            });
            console.log(`[${picked.length}] SF ${spec.slug} | ${top.fc} faces | ${top.sizeMb.toFixed(1)} MB | "${top.m.name}"`);
        } catch (err) {
            console.log(`[ERR] ${spec.slug}: ${err.message}`);
        }
    }

    fs.writeFileSync(JSON_OUT, JSON.stringify({ count: picked.length, candidates: picked }, null, 2));
    console.log(`Saved ${picked.length} prop candidates to ${JSON_OUT}`);
}

main().catch((e) => { console.error(e); process.exit(1); });
