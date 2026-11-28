// tools/download_all_approved_assets.js
// Downloads 35 visually-vetted photorealistic cars + 60 visually-vetted high-quality props
// from Sketchfab (GLB) and Poly Haven (1K glTF photogrammetry) with concurrency=4 & retry.
const https = require('https');
const fs = require('fs');
const path = require('path');

const SF_TOKEN = '4591437114654bf29d34a235f90acf6c';
const ROOT = path.resolve(__dirname, '..');

function fetchJson(url, headers = {}, retries = 3) {
    return new Promise((resolve, reject) => {
        https.get(url, { headers: { 'User-Agent': 'GridlethalAssetSync/2.0', ...headers }, timeout: 25000 }, (res) => {
            if (res.statusCode >= 300 && res.statusCode < 400 && res.headers.location) {
                return resolve(fetchJson(res.headers.location, headers, retries));
            }
            if (res.statusCode !== 200) {
                if (retries > 0 && (res.statusCode === 429 || res.statusCode >= 500)) {
                    return setTimeout(() => fetchJson(url, headers, retries - 1).then(resolve, reject), 2500);
                }
                return reject(new Error(`HTTP ${res.statusCode} for ${url}`));
            }
            let d = '';
            res.on('data', c => d += c);
            res.on('end', () => { try { resolve(JSON.parse(d)); } catch (e) { reject(e); } });
        }).on('timeout', function () {
            this.destroy();
            if (retries > 0) setTimeout(() => fetchJson(url, headers, retries - 1).then(resolve, reject), 2000);
            else reject(new Error(`Timeout ${url}`));
        }).on('error', (err) => {
            if (retries > 0) setTimeout(() => fetchJson(url, headers, retries - 1).then(resolve, reject), 2000);
            else reject(err);
        });
    });
}

function downloadFile(url, dest, retries = 3) {
    return new Promise((resolve, reject) => {
        fs.mkdirSync(path.dirname(dest), { recursive: true });
        https.get(url, { headers: { 'User-Agent': 'GridlethalAssetSync/2.0' }, timeout: 60000 }, (res) => {
            if (res.statusCode >= 300 && res.statusCode < 400 && res.headers.location) {
                return resolve(downloadFile(res.headers.location, dest, retries));
            }
            if (res.statusCode !== 200) {
                if (retries > 0 && (res.statusCode === 429 || res.statusCode >= 500)) {
                    return setTimeout(() => downloadFile(url, dest, retries - 1).then(resolve, reject), 2500);
                }
                return reject(new Error(`HTTP ${res.statusCode} downloading ${url}`));
            }
            const tmp = dest + '.part';
            const f = fs.createWriteStream(tmp);
            res.pipe(f);
            f.on('finish', () => f.close(() => { fs.renameSync(tmp, dest); resolve(dest); }));
            f.on('error', (err) => f.close(() => { try { fs.unlinkSync(tmp); } catch (_) {} reject(err); }));
        }).on('timeout', function () {
            this.destroy();
            if (retries > 0) setTimeout(() => downloadFile(url, dest, retries - 1).then(resolve, reject), 2000);
            else reject(new Error(`Timeout ${dest}`));
        }).on('error', (err) => {
            if (retries > 0) setTimeout(() => downloadFile(url, dest, retries - 1).then(resolve, reject), 2000);
            else reject(err);
        });
    });
}

async function downloadSketchfabGlb(uid, destRelPath) {
    const dest = path.join(ROOT, destRelPath);
    if (fs.existsSync(dest) && fs.statSync(dest).size > 20000) {
        return { ok: true, skipped: true, path: destRelPath };
    }
    const info = await fetchJson(`https://api.sketchfab.com/v3/models/${uid}/download`, { 'Authorization': `Token ${SF_TOKEN}` });
    if (!info.glb || !info.glb.url) throw new Error(`No GLB URL for ${uid}`);
    await downloadFile(info.glb.url, dest);
    const sz = fs.statSync(dest).size;
    if (sz < 5000) throw new Error(`Too small (${sz}B) for ${destRelPath}`);
    return { ok: true, skipped: false, path: destRelPath, mb: (sz / 1048576).toFixed(2) };
}

async function downloadPolyHavenModel(id, destSubDir, thumbOut = null) {
    const outDir = path.join(ROOT, 'assets', 'models', destSubDir, id);
    const gltfDest = path.join(outDir, `${id}.gltf`);
    const relPath = `assets/models/${destSubDir}/${id}/${id}.gltf`;
    if (fs.existsSync(gltfDest) && fs.statSync(gltfDest).size > 400) {
        return { ok: true, skipped: true, path: relPath };
    }
    const info = await fetchJson(`https://api.polyhaven.com/files/${id}`);
    const gInfo = info.gltf && (info.gltf['1k'] || info.gltf['2k']);
    if (!gInfo || !gInfo.gltf) throw new Error(`No glTF found for ${id}`);
    const entry = gInfo.gltf;
    await downloadFile(entry.url, gltfDest);
    const includes = entry.include || {};
    for (const [rp, fileObj] of Object.entries(includes)) {
        await downloadFile(fileObj.url, path.join(outDir, rp));
    }
    if (thumbOut) {
        await downloadFile(`https://cdn.polyhaven.com/asset_img/thumbs/${id}.png?width=384`, thumbOut).catch(() => {});
    }
    return { ok: true, skipped: false, path: relPath, files: Object.keys(includes).length + 1 };
}

// 35 Visually Approved Photorealistic New Cars (from visual thumbnail checks)
const APPROVED_CARS = [
    { slug: 'bugatti_centodieci', uid: '7647afdfba6b47a086f9b644442ebeb6', name: 'Bugatti Centodieci', archetype: 'Hypercar Exotics', targetLen: 4.54, mass: 1975, hp: 1577, torque: 1600, topSpeed: 380, redline: 7200 },
    { slug: 'koenigsegg_ccx', uid: '423b64e085974b97b5cfd5a87d9dcce3', name: 'Koenigsegg CCX Roadster', archetype: 'Hypercar Exotics', targetLen: 4.30, mass: 1280, hp: 806, torque: 920, topSpeed: 375, redline: 7600 },
    { slug: 'koenigsegg_one1', uid: 'b4e5a4c5fa5d4d45acd6715d3325254f', name: 'Koenigsegg One:1', archetype: 'Hypercar Exotics', targetLen: 4.50, mass: 1360, hp: 1341, torque: 1371, topSpeed: 400, redline: 8250 },
    { slug: 'porsche_gt2_rs', uid: '97947fc2a58b4e8b8ffa95e827a792e6', name: 'Porsche 911 GT2 RS Clubsport', archetype: 'Supercar Track', targetLen: 4.57, mass: 1390, hp: 700, torque: 750, topSpeed: 340, redline: 7200 },
    { slug: 'audi_r8_lms', uid: '1faf7b2931444fb49e7c28483ac40c0c', name: 'Audi R8 LMS Ultra GT3', archetype: 'Supercar Track', targetLen: 4.46, mass: 1290, hp: 570, torque: 540, topSpeed: 315, redline: 8500 },
    { slug: 'lamborghini_terzo', uid: '7ad3dffa9d344c3c978eafcc220cb709', name: 'Lamborghini Terzo Millennio', archetype: 'Hypercar Exotics', targetLen: 4.68, mass: 1250, hp: 1120, torque: 1080, topSpeed: 370, redline: 9000 },
    { slug: 'ferrari_f40_lm', uid: '8f67f3c0bbcc4e7084ee7f49cab9c7db', name: 'Ferrari F40 LM 1989', archetype: 'Hypercar Exotics', targetLen: 4.36, mass: 1050, hp: 720, torque: 700, topSpeed: 352, redline: 8100 },
    { slug: 'aston_vantage_v600', uid: '4f2d9b51a0d44ea186d8354246379941', name: 'Aston Martin Vantage V600', archetype: 'GT Tourer', targetLen: 4.58, mass: 1970, hp: 600, torque: 813, topSpeed: 320, redline: 6800 },
    { slug: 'ares_s1_project', uid: '4f1bd08fd2914a0e8d3ff44fc7d0b0b9', name: 'Ares S1 Project Spyder', archetype: 'Supercar Track', targetLen: 4.65, mass: 1420, hp: 715, torque: 690, topSpeed: 332, redline: 8600 },
    { slug: 'mazda_rx7_fd', uid: 'd35ff630df614771b82e7b2f59035b1e', name: 'Mazda RX-7 FD3S', archetype: 'JDM Street', targetLen: 4.28, mass: 1260, hp: 315, torque: 330, topSpeed: 265, redline: 8200 },
    { slug: 'skyline_r32_gtr', uid: '8810e677eca543a6b840cf67dd064aa4', name: 'Nissan Skyline R32 GT-R', archetype: 'JDM Street', targetLen: 4.54, mass: 1430, hp: 360, torque: 410, topSpeed: 278, redline: 8200 },
    { slug: 'mitsubishi_evo_ix', uid: 'f0509bed976d453c92dfcd83a5ac14e5', name: 'Mitsubishi Lancer Evo IX MR', archetype: 'Rally Special', targetLen: 4.49, mass: 1410, hp: 345, torque: 455, topSpeed: 262, redline: 7600 },
    { slug: 'honda_nsx_1990', uid: '1cc15628a00a4739a6b6c01128927c8d', name: 'Honda NSX Type-S 1990', archetype: 'JDM Street', targetLen: 4.43, mass: 1320, hp: 310, torque: 320, topSpeed: 274, redline: 8300 },
    { slug: 'nissan_silvia_s13', uid: 'e398ad20e83d42e581ab43438d5b6e49', name: 'Nissan Silvia S13 Spec', archetype: 'JDM Street', targetLen: 4.47, mass: 1180, hp: 270, torque: 310, topSpeed: 252, redline: 7500 },
    { slug: 'dodge_charger_police', uid: 'c6d52512e32d42abb89466ced4d56c1d', name: 'Dodge Charger SRT Interceptor', archetype: 'Muscle Bruiser', targetLen: 5.05, mass: 1980, hp: 485, torque: 644, topSpeed: 290, redline: 6600 },
    { slug: 'dodge_viper_gtsr', uid: 'e984e36cabe943e1b953a276f145ecdf', name: 'Dodge SRT Viper GTS-R', archetype: 'Supercar Track', targetLen: 4.46, mass: 1380, hp: 645, torque: 813, topSpeed: 331, redline: 6500 },
    { slug: 'shelby_gt500', uid: '3c6073393d4f4a3083ec697a389992a7', name: 'Shelby GT500 Cobra 2010', archetype: 'Muscle Bruiser', targetLen: 4.78, mass: 1730, hp: 540, torque: 690, topSpeed: 305, redline: 6500 },
    { slug: 'ford_shelby_gr1', uid: 'bd62972dd652443fa46cbde715e3c7c8', name: 'Ford Shelby GR-1 V10', archetype: 'Hypercar Exotics', targetLen: 4.41, mass: 1760, hp: 605, torque: 679, topSpeed: 322, redline: 7200 },
    { slug: 'bmw_m3_gtr', uid: '7f060f9d44b74c34a5184399a6cfc6d7', name: 'BMW M3 GTR E46', archetype: 'GT Tourer', targetLen: 4.61, mass: 1350, hp: 460, torque: 480, topSpeed: 298, redline: 8200 },
    { slug: 'alfa_giulia_gta', uid: '460d44b163e24836bbefa48be9357ee1', name: 'Alfa Romeo Giulia Sprint GTA', archetype: 'GT Tourer', targetLen: 4.14, mass: 785, hp: 170, torque: 195, topSpeed: 225, redline: 7500 },
    { slug: 'jeep_wrangler_rubicon', uid: 'e3ecbf7d1fda464cb84d4bf41925d383', name: 'Jeep Wrangler Rubicon', archetype: 'Offroad & Trucks', targetLen: 4.75, mass: 2050, hp: 375, torque: 520, topSpeed: 195, redline: 6400 },
    { slug: 'land_rover_defender', uid: '0fbbc07768a5456c9f6f8c9c7e048d28', name: 'Land Rover Defender 110', archetype: 'Offroad & Trucks', targetLen: 4.60, mass: 2150, hp: 340, torque: 550, topSpeed: 185, redline: 5800 },
    { slug: 'audi_sport_quattro', uid: 'a2e98736245448afa807a2b5cabe05c7', name: 'Audi Sport Quattro 1984', archetype: 'Rally Special', targetLen: 4.16, mass: 1290, hp: 390, torque: 450, topSpeed: 258, redline: 7600 },
    { slug: 'porsche_959', uid: '0530aa8fa4b74427a71c961a5bdd7087', name: 'Porsche 959 Twin-Turbo', archetype: 'Rally Special', targetLen: 4.26, mass: 1450, hp: 450, torque: 500, topSpeed: 317, redline: 7600 },
    { slug: 'vw_golf_gti_mk1', uid: '1fc46cb37bd748e3bb9355fcedaf3817', name: 'VW Golf GTI Mk1 1976', archetype: 'Rally Special', targetLen: 3.82, mass: 840, hp: 175, torque: 205, topSpeed: 218, redline: 7200 },
    { slug: 'subaru_brz_varis', uid: 'f0d1a65a4f8e496bbb7f187e57dc90cc', name: 'Subaru BRZ Widebody', archetype: 'JDM Street', targetLen: 4.24, mass: 1250, hp: 330, torque: 365, topSpeed: 268, redline: 7800 },
    { slug: 'dodge_ram_2500', uid: 'b4259af6d85d472b8fde9517bcd38154', name: 'RAM 2500 Heavy Rebel', archetype: 'Offroad & Trucks', targetLen: 5.50, mass: 3100, hp: 650, torque: 1080, topSpeed: 192, redline: 5600 },
    { slug: 'mclaren_720s', uid: '56dff31093154a788f103fa39be90dc2', name: 'McLaren 720S Coupe', archetype: 'Hypercar Exotics', targetLen: 4.54, mass: 1419, hp: 720, torque: 770, topSpeed: 341, redline: 8200 },
    { slug: 'ferrari_laferrari', uid: '8b46fa49718647de846387ef4c1e95b3', name: 'Ferrari LaFerrari', archetype: 'Hypercar Exotics', targetLen: 4.70, mass: 1385, hp: 950, torque: 900, topSpeed: 352, redline: 9250 },
    { slug: 'bmw_m5_cs', uid: '30fa0c4408bc43be8c3a67c51fcc6184', name: 'BMW M5 F90 Competition', archetype: 'GT Tourer', targetLen: 4.96, mass: 1865, hp: 625, torque: 750, topSpeed: 305, redline: 7200 },
    { slug: 'jaguar_etype_1963', uid: '5670ebba9bbb4e42b9ce3ff5f37b743c', name: 'Jaguar E-Type Lightweight', archetype: 'GT Tourer', targetLen: 4.45, mass: 980, hp: 300, torque: 350, topSpeed: 262, redline: 6500 },
    { slug: 'honda_civic_ek9', uid: '4012706636b843d49ad3974af8fba593', name: 'Honda Civic Type R EK9', archetype: 'JDM Street', targetLen: 4.18, mass: 1050, hp: 220, torque: 215, topSpeed: 238, redline: 8600 },
    { slug: 'mercedes_g63_amg', uid: 'f583b5bfc17346c08573dc4f1edebefe', name: 'Mercedes-AMG G63 Biturbo', archetype: 'Offroad & Trucks', targetLen: 4.82, mass: 2560, hp: 585, torque: 850, topSpeed: 240, redline: 6500 },
    { slug: 'chevy_camaro_ss67', uid: '3016d29e5dd54e40b92a9898476c3ccc', name: 'Chevrolet Camaro SS 1967', archetype: 'Muscle Bruiser', targetLen: 4.69, mass: 1520, hp: 425, torque: 580, topSpeed: 265, redline: 6200 },
    { slug: 'ford_gt_2017', uid: '7eb9c5aca1e84d428898bf88fa9ab8b7', name: 'Ford GT EcoBoost 2017', archetype: 'Hypercar Exotics', targetLen: 4.76, mass: 1385, hp: 660, torque: 745, topSpeed: 347, redline: 7000 },
    { slug: 'corvette_c7_z06', uid: '3648a2668d5049d2a15e84facb150562', name: 'Chevrolet Corvette C7 Z06', archetype: 'Supercar Track', targetLen: 4.51, mass: 1598, hp: 650, torque: 881, topSpeed: 315, redline: 6600 }
];

// 60+ Verified High-Quality Environment/Street/Town/Port/Festival/Nature Props
const APPROVED_PROPS_SF = [
    { slug: 'bus_stop_shelter', uid: '8c984e73fa274c49a444f9991444d542', cat: 'SOLID_BUILDING', biome: 'town', scale: 1.0 },
    { slug: 'steel_bollard', uid: '1ccd0c761fc744a3a62e168044a9d2eb', cat: 'POLE_SNAP', biome: 'town', scale: 1.0 },
    { slug: 'mailbox_street', uid: '582c0ce1ffee41179ab981146ae0ff87', cat: 'POLE_SNAP', biome: 'town', scale: 1.0 },
    { slug: 'highway_billboard', uid: '20d1a51fbfa94373900e29de74a0f9ee', cat: 'SOLID_BUILDING', biome: 'highway', scale: 1.0 },
    { slug: 'guard_booth', uid: '422ec83e0bd64687a0026c67abb6bc07', cat: 'SOLID_BUILDING', biome: 'port', scale: 1.0 },
    { slug: 'gas_station_pump', uid: '53abc45c2c7b44078b8f0f03ec7bcf57', cat: 'EXPLOSIVE_DRUM', biome: 'highway', scale: 1.0 },
    { slug: 'solar_street_panel', uid: 'd69ad151457c4aad830b40e8dd92eece', cat: 'POLE_SNAP', biome: 'desert', scale: 1.0 },
    { slug: 'street_trash_can', uid: 'f61aeec14ff441abb0f6add5485a2e90', cat: 'LIGHT_PLASTIC_FLICK', biome: 'town', scale: 1.0 },
    { slug: 'wooden_pallet', uid: '2a4411c6956f4adeb7877f03436bb742', cat: 'WOOD_SPLINTER', biome: 'port', scale: 1.0 },
    { slug: 'hay_bale_round', uid: 'e01a6a0f9ed843279adfac2427c99679', cat: 'WOOD_SPLINTER', biome: 'desert', scale: 1.0 },
    { slug: 'coastal_lighthouse', uid: '464af883421f4ac68ede2605f4f1407b', cat: 'SOLID_BUILDING', biome: 'coast', scale: 1.0 },
    { slug: 'metal_barrier_crowd', uid: '3843be0d065847bc8e0b2b2002e7e46f', cat: 'LIGHT_PLASTIC_FLICK', biome: 'hub', scale: 1.0 },
    { slug: 'desert_water_tower', uid: '500cfe0cf4a74350bb49c5736b692339', cat: 'SOLID_BUILDING', biome: 'desert', scale: 1.0 },
    { slug: 'beach_lifeguard_tower', uid: '69cb65bb670f46d59e48d92c7f08da6b', cat: 'WOOD_SPLINTER', biome: 'coast', scale: 1.0 },
    { slug: 'wind_turbine_tall', uid: 'e0678e6615a74ed29c1376a591262159', cat: 'SOLID_BUILDING', biome: 'highway', scale: 1.0 },
    { slug: 'street_vending_machine', uid: '19d4bd442279453297b26dca4d517501', cat: 'HEAVY_SLIDE', biome: 'town', scale: 1.0 },
    { slug: 'electric_transformer_box', uid: 'e1855872634042abab77dfb7e51a3287', cat: 'SOLID_BUILDING', biome: 'town', scale: 1.0 },
    { slug: 'road_construction_barrier', uid: '2a09091d4e7b4539abe03f6a50762409', cat: 'WOOD_SPLINTER', biome: 'highway', scale: 1.0 },
    { slug: 'park_bench_iron', uid: 'acf643ab6a4a4ef2b894abd59aebdf4d', cat: 'WOOD_SPLINTER', biome: 'town', scale: 1.0 },
    { slug: 'wooden_warehouse_shed', uid: 'e03a76f5f010465ca570c3e3dc2fb1d1', cat: 'SOLID_BUILDING', biome: 'desert', scale: 1.0 },
    { slug: 'modern_shop_building', uid: 'e925b04cdd8e4e51841a20b37bc9c056', cat: 'SOLID_BUILDING', biome: 'town', scale: 1.0 },
    { slug: 'rigging_truss_stage', uid: 'c25451c9c53249b4a040b6b27cec259e', cat: 'SOLID_BUILDING', biome: 'hub', scale: 1.0 },
    { slug: 'beach_parasol_umbrella', uid: 'e559392994e04527b3f5ee35a8c3c418', cat: 'WOOD_SPLINTER', biome: 'coast', scale: 1.0 },
    { slug: 'wooden_rowboat', uid: '3e9093b6f0ce474da4d8cfea7e01f420', cat: 'WOOD_SPLINTER', biome: 'coast', scale: 1.0 },
    { slug: 'joshua_desert_tree', uid: '0da4ba781b37449087dfd34162eb4184', cat: 'TREE_SNAP', biome: 'desert', scale: 1.0 },
    { slug: 'metal_generator_yellow', uid: 'b0de972e500a48d6a26a7d1ef6f5143f', cat: 'HEAVY_SLIDE', biome: 'hub', scale: 1.0 },
    { slug: 'gas_pump_retro', uid: 'add0f902b9164718bd0540e88bf9927e', cat: 'EXPLOSIVE_DRUM', biome: 'highway', scale: 1.0 },
    { slug: 'alpine_wooden_cabin', uid: 'c90674a377864ac1b8fd141ad1917ee3', cat: 'SOLID_BUILDING', biome: 'snow', scale: 1.0 },
    { slug: 'traffic_stop_sign_kit', uid: '27a6775c51e44bfda8e1ac8725eb3e9e', cat: 'POLE_SNAP', biome: 'town', scale: 1.0 }
];

// 31 Exact Photogrammetry Poly Haven CC0 Models (downloaded as 1K glTF + local textures)
const APPROVED_PROPS_PH = [
    { id: 'street_lamp_01', slug: 'ph_street_lamp_01', cat: 'POLE_SNAP', biome: 'town' },
    { id: 'street_lamp_02', slug: 'ph_street_lamp_02', cat: 'POLE_SNAP', biome: 'town' },
    { id: 'fire_hydrant', slug: 'ph_fire_hydrant', cat: 'POLE_SNAP', biome: 'town' },
    { id: 'metal_trash_can', slug: 'ph_metal_trash_can', cat: 'LIGHT_PLASTIC_FLICK', biome: 'town' },
    { id: 'Barrel_01', slug: 'ph_barrel_red', cat: 'EXPLOSIVE_DRUM', biome: 'port' },
    { id: 'Barrel_02', slug: 'ph_barrel_blue', cat: 'HEAVY_SLIDE', biome: 'port' },
    { id: 'barrel_03', slug: 'ph_barrel_rust', cat: 'EXPLOSIVE_DRUM', biome: 'port' },
    { id: 'portable_welding_cart', slug: 'ph_welding_cart', cat: 'EXPLOSIVE_DRUM', biome: 'hub' },
    { id: 'CheeseBox_01', slug: 'ph_wooden_box_flat', cat: 'WOOD_SPLINTER', biome: 'port' },
    { id: 'overhead_crane', slug: 'ph_overhead_crane', cat: 'SOLID_BUILDING', biome: 'port' },
    { id: 'modular_wooden_pier', slug: 'ph_wooden_pier', cat: 'SOLID_BUILDING', biome: 'coast' },
    { id: 'modular_pipes', slug: 'ph_modular_pipes', cat: 'HEAVY_SLIDE', biome: 'port' },
    { id: 'bark_debris_01', slug: 'ph_bark_debris', cat: 'WOOD_SPLINTER', biome: 'snow' },
    { id: 'cheiridopsis_succulent', slug: 'ph_succulent', cat: 'CACTUS_BURST', biome: 'desert' },
    { id: 'pine_sapling_medium', slug: 'ph_pine_sapling', cat: 'TREE_SNAP', biome: 'snow' },
    { id: 'dead_quiver_trunk', slug: 'ph_dead_quiver_trunk', cat: 'TREE_SNAP', biome: 'desert' },
    { id: 'concrete_road_barrier', slug: 'ph_concrete_barrier_01', cat: 'HEAVY_SLIDE', biome: 'highway' },
    { id: 'modular_street_seating', slug: 'ph_street_seating', cat: 'HEAVY_SLIDE', biome: 'town' },
    { id: 'modular_chainlink_fence', slug: 'ph_chainlink_fence', cat: 'WOOD_SPLINTER', biome: 'port' },
    { id: 'portable_generator', slug: 'ph_portable_generator', cat: 'HEAVY_SLIDE', biome: 'hub' },
    { id: 'portable_searchlight', slug: 'ph_portable_searchlight', cat: 'POLE_SNAP', biome: 'hub' },
    { id: 'propane_tank', slug: 'ph_propane_tank', cat: 'EXPLOSIVE_DRUM', biome: 'port' },
    { id: 'small_lpg_tank', slug: 'ph_small_lpg_tank', cat: 'EXPLOSIVE_DRUM', biome: 'town' },
    { id: 'metal_jerrycan', slug: 'ph_metal_jerrycan', cat: 'EXPLOSIVE_DRUM', biome: 'hub' },
    { id: 'wooden_crate_01', slug: 'ph_wooden_crate_01', cat: 'WOOD_SPLINTER', biome: 'port' },
    { id: 'wooden_crate_02', slug: 'ph_wooden_crate_02', cat: 'WOOD_SPLINTER', biome: 'port' },
    { id: 'wooden_military_crate', slug: 'ph_wooden_mil_crate', cat: 'WOOD_SPLINTER', biome: 'hub' },
    { id: 'wooden_barrels_01', slug: 'ph_wooden_barrels', cat: 'WOOD_SPLINTER', biome: 'town' },
    { id: 'wooden_picnic_table', slug: 'ph_picnic_table', cat: 'WOOD_SPLINTER', biome: 'hub' },
    { id: 'old_tyre', slug: 'ph_old_tyre', cat: 'LIGHT_PLASTIC_FLICK', biome: 'hub' },
    { id: 'quiver_tree_01', slug: 'ph_quiver_tree', cat: 'TREE_SNAP', biome: 'desert' },
    { id: 'island_tree_01', slug: 'ph_island_tree', cat: 'TREE_SNAP', biome: 'coast' },
    { id: 'jacaranda_tree', slug: 'ph_jacaranda_tree', cat: 'TREE_SNAP', biome: 'hub' },
    { id: 'fir_tree_01', slug: 'ph_fir_tree', cat: 'TREE_SNAP', biome: 'snow' },
    { id: 'namaqualand_cliff_01', slug: 'ph_sandstone_cliff', cat: 'SOLID_ROCK', biome: 'desert' },
    { id: 'moon_rock_01', slug: 'ph_volcano_boulder', cat: 'SOLID_ROCK', biome: 'volcano' },
    { id: 'coast_land_rocks_02', slug: 'ph_coast_rock_outcrop', cat: 'SOLID_ROCK', biome: 'coast' },
    { id: 'fern_02', slug: 'ph_fern', cat: 'CACTUS_BURST', biome: 'coast' }
];

async function runPool(items, concurrency, workerFn) {
    let idx = 0;
    const results = [];
    async function worker() {
        while (idx < items.length) {
            const myIdx = idx++;
            const item = items[myIdx];
            try {
                const res = await workerFn(item, myIdx);
                results.push(res);
            } catch (err) {
                console.log(`[FAIL] ${item.slug || item.id}: ${err.message}`);
                results.push({ ok: false, item, error: err.message });
            }
        }
    }
    const workers = [];
    for (let w = 0; w < concurrency; w++) workers.push(worker());
    await Promise.all(workers);
    return results;
}

async function main() {
    console.log(`Downloading ${APPROVED_CARS.length} Sketchfab Cars & ${APPROVED_PROPS_SF.length + APPROVED_PROPS_PH.length} Props...`);

    const carResults = await runPool(APPROVED_CARS, 3, async (c, i) => {
        const rel = `assets/models/cars/${c.slug}.glb`;
        const res = await downloadSketchfabGlb(c.uid, rel);
        console.log(`[CAR ${i + 1}/${APPROVED_CARS.length}] ${c.slug} -> ${res.skipped ? 'CACHED' : res.mb + ' MB'}`);
        return { ...res, car: c };
    });

    const sfPropResults = await runPool(APPROVED_PROPS_SF, 3, async (p, i) => {
        const rel = `assets/models/props/${p.slug}.glb`;
        const res = await downloadSketchfabGlb(p.uid, rel);
        console.log(`[PROP-SF ${i + 1}/${APPROVED_PROPS_SF.length}] ${p.slug} -> ${res.skipped ? 'CACHED' : res.mb + ' MB'}`);
        return { ...res, prop: p };
    });

    const phPropResults = await runPool(APPROVED_PROPS_PH, 4, async (p, i) => {
        const thumbDest = path.join(ROOT, 'build', 'sf_prop_previews', `ph_extra_${p.id}.png`);
        const res = await downloadPolyHavenModel(p.id, 'props', thumbDest);
        console.log(`[PROP-PH ${i + 1}/${APPROVED_PROPS_PH.length}] ${p.slug} (${p.id}) -> ${res.skipped ? 'CACHED' : res.files + ' files'}`);
        return { ...res, prop: p };
    });

    const manifest = {
        cars: carResults.filter(r => r.ok).map(r => ({ ...r.car, model_path: 'res://' + r.path })),
        props: [
            ...sfPropResults.filter(r => r.ok).map(r => ({ ...r.prop, model_path: 'res://' + r.path })),
            ...phPropResults.filter(r => r.ok).map(r => ({ ...r.prop, model_path: 'res://' + r.path }))
        ]
    };

    fs.writeFileSync(path.join(ROOT, 'data', 'approved_assets_manifest.json'), JSON.stringify(manifest, null, 2));
    console.log(`\nDONE! Downloaded OK: Cars=${manifest.cars.length}/${APPROVED_CARS.length}, Props=${manifest.props.length}/${APPROVED_PROPS_SF.length + APPROVED_PROPS_PH.length}`);
}

main().catch((e) => { console.error(e); process.exit(1); });
