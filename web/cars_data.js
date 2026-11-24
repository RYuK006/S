// web/cars_data.js
// 12 Vehicle Specifications across 3 Classes, 10 Upgrade Categories & 6 Drivers

const CAR_RECIPES = {
  // --- RALLY CLASS ---
  sprinter_r2: {
    id: "sprinter_r2", name: "Sprinter R2", class: "Rally",
    mass: 1050.0, power_kw: 140.0, top_speed: 175.0, accel_0_100: 6.8,
    health: 700.0, price: 0, level_req: 1,
    drivetrain: "AWD", slots: ["primary", "roof"],
    perk: "Underdog", perk_desc: "+10% weapon damage when below half health.",
    colorHex: 0xee1808
  },
  dust_viper: {
    id: "dust_viper", name: "Dust Viper", class: "Rally",
    mass: 1150.0, power_kw: 210.0, top_speed: 205.0, accel_0_100: 5.0,
    health: 800.0, price: 18000, level_req: 3,
    drivetrain: "AWD", slots: ["primary", "roof", "rear"],
    perk: "Drift King", perk_desc: "Drifting fills nitro bar 30% faster.",
    colorHex: 0xecb414
  },
  gravel_fang: {
    id: "gravel_fang", name: "Gravel Fang", class: "Rally",
    mass: 1200.0, power_kw: 250.0, top_speed: 215.0, accel_0_100: 4.4,
    health: 900.0, price: 42000, level_req: 7,
    drivetrain: "AWD", slots: ["primary", "roof", "rear", "passive"],
    perk: "Gravel Specialist", perk_desc: "No grip loss on dirt and gravel surfaces.",
    colorHex: 0x24d436
  },
  tundra_wolf: {
    id: "tundra_wolf", name: "Tundra Wolf", class: "Rally",
    mass: 1300.0, power_kw: 230.0, top_speed: 200.0, accel_0_100: 5.4,
    health: 1000.0, price: 55000, level_req: 11,
    drivetrain: "AWD", slots: ["primary", "roof", "rear", "passive"],
    perk: "Studded", perk_desc: "Snow and ice grip equals asphalt grip.",
    colorHex: 0xddeeff
  },

  // --- OFFROAD / MONSTER CLASS ---
  bulldog_6x6: {
    id: "bulldog_6x6", name: "Bulldog 6x6", class: "Offroad",
    mass: 3600.0, power_kw: 260.0, top_speed: 150.0, accel_0_100: 9.0,
    health: 2200.0, price: 35000, level_req: 5,
    drivetrain: "6x6", slots: ["primary", "roof", "rear", "passive"],
    perk: "Battering Ram", perk_desc: "Ramming damage x1.5, takes 30% less ram damage.",
    colorHex: 0x4a5440
  },
  rock_crusher: {
    id: "rock_crusher", name: "Rock Crusher", class: "Offroad",
    mass: 2600.0, power_kw: 330.0, top_speed: 170.0, accel_0_100: 6.9,
    health: 1800.0, price: 60000, level_req: 10,
    drivetrain: "4x4", slots: ["primary", "roof", "rear", "passive"],
    perk: "Crawler", perk_desc: "Can climb steep slopes, no penalty in mud.",
    colorHex: 0xc86420
  },
  mud_reaper: {
    id: "mud_reaper", name: "Mud Reaper", class: "Offroad",
    mass: 1500.0, power_kw: 280.0, top_speed: 185.0, accel_0_100: 5.6,
    health: 950.0, price: 48000, level_req: 8,
    drivetrain: "RWD", slots: ["primary", "roof", "rear"],
    perk: "Airtime", perk_desc: "Landing from jumps refills nitro.",
    colorHex: 0x887755
  },
  scrap_titan: {
    id: "scrap_titan", name: "Scrap Titan", class: "Offroad",
    mass: 4800.0, power_kw: 450.0, top_speed: 140.0, accel_0_100: 8.2,
    health: 3500.0, price: 110000, level_req: 18,
    drivetrain: "4x4", slots: ["primary", "roof", "rear", "passive", "side"],
    perk: "Juggernaut", perk_desc: "Small cars knocked aside, immune to spike strips.",
    colorHex: 0x555555
  },

  // --- LUXURY / SUPER CLASS ---
  aurelia_gt: {
    id: "aurelia_gt", name: "Aurelia GT", class: "Super",
    mass: 1600.0, power_kw: 380.0, top_speed: 285.0, accel_0_100: 4.1,
    health: 750.0, price: 140000, level_req: 22,
    drivetrain: "RWD", slots: ["primary", "roof", "passive"],
    perk: "Grand Touring", perk_desc: "Stable at high speed with extra aerodynamic downforce.",
    colorHex: 0x189bee
  },
  noir_phantom: {
    id: "noir_phantom", name: "Noir Phantom", class: "Super",
    mass: 2300.0, power_kw: 450.0, top_speed: 270.0, accel_0_100: 4.4,
    health: 1500.0, price: 220000, level_req: 30,
    drivetrain: "AWD", slots: ["primary", "roof", "rear", "passive"],
    perk: "Prestige", perk_desc: "+15% reputation gain from all events.",
    colorHex: 0x111116
  },
  vandal_hyper: {
    id: "vandal_hyper", name: "Vandal Hyper", class: "Super",
    mass: 1350.0, power_kw: 700.0, top_speed: 345.0, accel_0_100: 2.7,
    health: 600.0, price: 380000, level_req: 42,
    drivetrain: "AWD", slots: ["primary", "roof", "passive"],
    perk: "Hybrid Boost", perk_desc: "Nitro bar recharges rapidly under hard braking.",
    colorHex: 0xff0044
  },
  gilded_sovereign: {
    id: "gilded_sovereign", name: "Gilded Sovereign", class: "Super",
    mass: 3000.0, power_kw: 400.0, top_speed: 240.0, accel_0_100: 5.5,
    health: 2000.0, price: 520000, level_req: 60,
    drivetrain: "RWD", slots: ["primary", "roof", "rear", "passive", "side"],
    perk: "Tax Collector", perk_desc: "+20% cash payout from all races and bounties.",
    colorHex: 0xd4af37
  }
};

const UPGRADE_CATEGORIES = {
  engine: { name: "Engine", base_factor: 0.12, delta_per_tier: 0.06, desc: "Increases horsepower and top speed." },
  turbo: { name: "Turbocharger", base_factor: 0.10, delta_per_tier: 0.04, desc: "Improves boost threshold and mid-range torque." },
  transmission: { name: "Transmission", base_factor: 0.08, delta_per_tier: 0.07, desc: "Reduces shift times from 250ms to 80ms." },
  brakes: { name: "Brakes", base_factor: 0.07, delta_per_tier: 0.08, desc: "Increases stopping power and reduces thermal fade." },
  suspension: { name: "Suspension", base_factor: 0.08, delta_per_tier: 0.06, desc: "Improves body roll damping and cornering composure." },
  tyres: { name: "Tyres", base_factor: 0.09, delta_per_tier: 0.05, desc: "Increases peak friction coefficient and slide grip." },
  armour: { name: "Armour", base_factor: 0.11, delta_per_tier: 0.10, desc: "Reinforces chassis hit points and collision resistance." },
  nitro: { name: "Nitro Tank", base_factor: 0.06, delta_per_tier: 0.20, desc: "Expands nitro capacity and accelerates recharge rate." },
  cooling: { name: "Cooling System", base_factor: 0.05, delta_per_tier: 0.15, desc: "Dissipates weapon heat and prevents jamming." },
  weight_reduction: { name: "Weight Reduction", base_factor: 0.10, delta_per_tier: -0.03, desc: "Saves weight for faster acceleration and agility." }
};

const DRIVERS = {
  hex: { id: "hex", name: "Hex", title: "The Mechanic", perk: "-15% repair & refuel costs." },
  duster: { id: "duster", name: "Duster", title: "The Daredevil", perk: "Jumps instantly replenish 25% nitro." },
  kestrel: { id: "kestrel", name: "Kestrel", title: "The Gunner", perk: "+10% weapon damage across all slots." },
  rook: { id: "rook", name: "Rook", title: "The Tank", perk: "+10% total armour integrity." },
  vee: { id: "vee", name: "Vee", title: "The Ace", perk: "+8% tire grip on all surfaces." },
  maddox: { id: "maddox", name: "Maddox", title: "The Scavenger", perk: "+20% cash and pickup rewards." }
};

function calculateUpgradeCost(basePrice, category, tier) {
  const cat = UPGRADE_CATEGORIES[category] || { base_factor: 0.08 };
  const tierMultipliers = [0.05, 0.09, 0.15, 0.25, 0.40];
  const mult = tierMultipliers[Math.max(0, Math.min(4, tier - 1))];
  const effBase = Math.max(basePrice, 12000);
  return Math.round(effBase * cat.base_factor * mult * 10.0);
}

function computeCarStats(carId, upgrades = {}) {
  const base = CAR_RECIPES[carId] || CAR_RECIPES.sprinter_r2;
  let mass = base.mass;
  let power = base.power_kw;
  let topSpeed = base.top_speed;
  let health = base.health;

  for (let cat of Object.keys(upgrades)) {
    const tier = upgrades[cat] || 0;
    if (tier <= 0) continue;
    const info = UPGRADE_CATEGORIES[cat];
    if (!info) continue;
    const delta = info.delta_per_tier;
    if (cat === 'engine') {
      power *= (1.0 + delta * tier);
      topSpeed *= (1.0 + delta * 0.5 * tier);
    } else if (cat === 'armour') {
      health *= (1.0 + delta * tier);
    } else if (cat === 'weight_reduction') {
      mass *= (1.0 + delta * tier);
    }
  }

  const ratingScore = (power * 0.4) + (health * 0.15) + (topSpeed * 0.35) - (mass * 0.05);
  let classRating = "D";
  if (ratingScore > 320) classRating = "S";
  else if (ratingScore > 240) classRating = "A";
  else if (ratingScore > 180) classRating = "B";
  else if (ratingScore > 130) classRating = "C";

  return {
    mass: Math.round(mass),
    power_kw: Math.round(power),
    top_speed: Math.round(topSpeed),
    health: Math.round(health),
    rating_score: Math.round(ratingScore),
    class_rating: classRating
  };
}
