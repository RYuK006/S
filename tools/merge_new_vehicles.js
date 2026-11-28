// tools/merge_new_vehicles.js
// Merges approved downloaded car GLBs from data/approved_assets_manifest.json into data/vehicles.json
// without breaking existing 32 entries or tests.
const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '..');
const VEH_PATH = path.join(ROOT, 'data', 'vehicles.json');
const MAN_PATH = path.join(ROOT, 'data', 'approved_assets_manifest.json');

const vData = JSON.parse(fs.readFileSync(VEH_PATH, 'utf8'));
const man = JSON.parse(fs.readFileSync(MAN_PATH, 'utf8'));

const existingIds = new Set(vData.vehicles.map(v => v.id));
let added = 0;

for (const c of (man.cars || [])) {
    if (existingIds.has(c.slug)) continue;
    existingIds.add(c.slug);

    const hp = c.hp || 450;
    const mass = c.mass || 1450;
    const isOffroad = c.archetype.includes('Offroad');
    const isHyper = c.archetype.includes('Hypercar');
    const isSuper = c.archetype.includes('Supercar');
    const wb = Number(((c.targetLen || 4.55) * 0.59).toFixed(2));
    const tw = Number((isOffroad ? 1.94 : (isHyper ? 1.88 : 1.78)).toFixed(2));

    vData.vehicles.push({
        id: c.slug,
        name: c.name,
        class_archetype: c.archetype,
        benchmark: c.name,
        mass,
        engine_power_hp: hp,
        max_torque_nm: c.torque || Math.round(hp * 1.15),
        idle_rpm: 900,
        redline_rpm: c.redline || 7500,
        gear_ratios: isHyper ? [3.15, 2.08, 1.52, 1.18, 0.94] : [3.45, 2.15, 1.50, 1.12, 0.88],
        reverse_ratio: 3.15,
        final_drive: isHyper ? 3.55 : (isOffroad ? 4.30 : 3.85),
        wheelbase: wb,
        track_width: tw,
        tire_params: {
            peak_slip: isOffroad ? 0.14 : 0.10,
            slide_slip: isOffroad ? 0.55 : 0.40,
            peak_mu: isOffroad ? 1.52 : (isHyper ? 1.92 : 1.74),
            slide_mu: isOffroad ? 1.12 : 1.24
        },
        drag_coeff: isOffroad ? 0.44 : (isHyper ? 0.29 : 0.32),
        frontal_area: isOffroad ? 2.85 : 2.02,
        health: isOffroad ? 1850 : (isHyper ? 720 : 880),
        combat_rating: Math.round(hp * 0.42 + (isOffroad ? 180 : 90)),
        hp_ton: Number((hp / (mass / 1000.0)).toFixed(1)),
        model_path: c.model_path
    });
    added++;
}

fs.writeFileSync(VEH_PATH, JSON.stringify(vData, null, 2));
console.log(`Updated data/vehicles.json: total vehicles=${vData.vehicles.length} (added ${added} unique new cars)`);
