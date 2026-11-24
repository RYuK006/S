// web/weapons.js
// Complete 26-Item Vehicular Combat Arsenal & Multi-Slot Weapon Management

const WEAPONS = {
  // --- FRONT GUNS & CANNONS (1 - 7) ---
  twin_mg: {
    id: "twin_mg", name: "Twin MG", slot: "primary",
    damage: 12.0, fireRate: 14.0, range: 90.0, velocity: 340.0,
    heatPerShot: 0.012, maxAmmo: 999,
    description: "Rapid-fire twin kinetic machine guns mounted on front quarter panels."
  },
  heavy_mg: {
    id: "heavy_mg", name: "Heavy MG", slot: "primary",
    damage: 26.0, fireRate: 8.0, range: 110.0, velocity: 380.0,
    heatPerShot: 0.024, maxAmmo: 300,
    description: "High-calibre armour-piercing rounds with heavy kinetic impact."
  },
  shotgun_cannon: {
    id: "shotgun_cannon", name: "Shotgun Cannon", slot: "primary",
    damage: 9.0, pellets: 12, fireRate: 1.4, range: 35.0, velocity: 280.0,
    spreadAngle: 0.16, heatPerShot: 0.08, maxAmmo: 45,
    description: "12-pellet buckshot blast devastating in close bumper-to-bumper combat."
  },
  flamethrower: {
    id: "flamethrower", name: "Flamethrower", slot: "primary",
    damage: 6.0, fireRate: 20.0, range: 18.0, velocity: 45.0,
    heatPerShot: 0.01, maxAmmo: 200, isFire: true,
    description: "Stream of burning napalm that coats targets in persistent flame and ignites oil."
  },
  plasma_cannon: {
    id: "plasma_cannon", name: "Plasma Cannon", slot: "primary",
    damage: 85.0, fireRate: 1.0, range: 80.0, velocity: 90.0,
    blastRadius: 4.0, heatPerShot: 0.25, maxAmmo: 30,
    description: "High-energy superheated plasma bolt that melts through reinforced armour plating."
  },
  railgun: {
    id: "railgun", name: "Railgun", slot: "primary",
    damage: 420.0, fireRate: 0.25, range: 300.0, velocity: 1200.0,
    isHitscan: true, heatPerShot: 0.65, maxAmmo: 12,
    description: "Hyper-velocity electromagnetic slug capable of piercing multiple vehicles."
  },
  harpoon_launcher: {
    id: "harpoon_launcher", name: "Harpoon Launcher", slot: "primary",
    damage: 40.0, fireRate: 0.2, range: 60.0, velocity: 110.0,
    tetherDuration: 5.0, maxAmmo: 6,
    description: "Pneumatic barbed spear that tethers an enemy car and reels it into melee range."
  },

  // --- ROOF TURRETS (8 - 12) ---
  rocket_pod: {
    id: "rocket_pod", name: "Rocket Pod", slot: "roof",
    damage: 70.0, blastRadius: 5.5, fireRate: 1.25, velocity: 160.0,
    range: 150.0, maxAmmo: 18, isHoming: false,
    description: "High-velocity unguided ballistic rockets with explosive blast radius."
  },
  homing_missile: {
    id: "homing_missile", name: "Homing Missile", slot: "roof",
    damage: 110.0, blastRadius: 6.5, fireRate: 0.75, velocity: 130.0,
    range: 250.0, turnRate: 6.0, lockAngle: 0.61, maxAmmo: 10, isHoming: true,
    description: "Laser-guided tracking missile with terminal seeking and devastating splash."
  },
  minigun_turret: {
    id: "minigun_turret", name: "Minigun Turret", slot: "roof",
    damage: 9.0, fireRate: 40.0, range: 100.0, velocity: 360.0,
    spinUpTime: 0.4, heatPerShot: 0.005, maxAmmo: 600,
    description: "Motorized 6-barrel rotary cannon delivering overwhelming suppressive firepower."
  },
  cluster_rocket: {
    id: "cluster_rocket", name: "Cluster Rocket", slot: "roof",
    damage: 260.0, blastRadius: 8.0, fireRate: 0.3, velocity: 140.0,
    range: 200.0, bomblets: 8, maxAmmo: 8,
    description: "Heavy warhead that splits mid-flight into 8 anti-vehicle bomblets."
  },
  emp_pulse: {
    id: "emp_pulse", name: "EMP Pulse", slot: "roof",
    damage: 0.0, blastRadius: 25.0, fireRate: 0.1, maxAmmo: 6,
    empDuration: 4.0,
    description: "Electromagnetic burst disabling enemy electronics, nitro, and lock-on tracking for 4s."
  },

  // --- REAR WEAPONS (13 - 17) ---
  mine_dropper: {
    id: "mine_dropper", name: "Mine Dropper", slot: "rear",
    damage: 180.0, blastRadius: 6.0, armDelay: 0.8, triggerRadius: 3.5,
    fireRate: 0.65, maxAmmo: 12, impulse: 18000.0,
    description: "Magnetic proximity contact mines that launch tailgating rivals airborne."
  },
  oil_slick: {
    id: "oil_slick", name: "Oil Slick", slot: "rear",
    damage: 0.0, duration: 12.0, triggerRadius: 3.2, slipMu: 0.20,
    fireRate: 0.4, maxAmmo: 10,
    description: "Viscous synthetic lubricant puddle that induces severe loss of control."
  },
  spike_strip: {
    id: "spike_strip", name: "Spike Strip", slot: "rear",
    damage: 50.0, triggerRadius: 2.8, fireRate: 0.5, maxAmmo: 6,
    shredsTyres: true,
    description: "Hollow steel quills that immediately deflate and shred tires on contact."
  },
  smoke_screen: {
    id: "smoke_screen", name: "Smoke Screen", slot: "rear",
    damage: 0.0, duration: 8.0, triggerRadius: 4.0, fireRate: 0.3, maxAmmo: 8,
    blocksLock: true,
    description: "Dense chemical aerosol cloud obscuring vision and breaking incoming missile locks."
  },
  napalm_drop: {
    id: "napalm_drop", name: "Napalm Drop", slot: "rear",
    damage: 112.0, blastRadius: 5.5, duration: 6.0, fireRate: 0.25, maxAmmo: 5,
    description: "Incendiary gel canister creating a persistent wall of fire on the tarmac."
  },

  // --- MELEE & MACHINERY (18 - 21) ---
  ram_plate: {
    id: "ram_plate", name: "Ram Plate", slot: "passive",
    collisionDmgMult: 2.4, selfDamageReduction: 0.60, weight: 45.0,
    description: "Reinforced front-end cow-catcher doubling ramming damage while absorbing impact."
  },
  saw_blades: {
    id: "saw_blades", name: "Saw Blades", slot: "passive",
    contactDmgPerSec: 350.0, weight: 40.0,
    description: "High-speed spinning circular saw discs mounted on wheel hubs grinding armor."
  },
  side_spikes: {
    id: "side_spikes", name: "Side Spikes", slot: "passive",
    contactDmgPerSec: 250.0, weight: 30.0,
    description: "Hardened titanium side skirts that punish aggressive side-swipers."
  },
  wheel_blades: {
    id: "wheel_blades", name: "Wheel Blades", slot: "passive",
    contactDmgPerSec: 150.0, shredsTyres: true, weight: 32.0,
    description: "Concealed scythe blades extending from axle caps to rupture adjacent tires."
  },

  // --- DEFENSIVE (22 - 26) ---
  armour_plating: {
    id: "armour_plating", name: "Armour Plating", slot: "passive",
    bonusHealth: 250.0, damageResistance: 0.25, weight: 80.0,
    description: "Hardened composite panels granting +250 HP and 25% damage mitigation."
  },
  shield_generator: {
    id: "shield_generator", name: "Shield Generator", slot: "passive",
    shieldCapacity: 200.0, rechargeRate: 10.0, weight: 45.0,
    description: "High-voltage kinetic barrier absorbing 200 damage before recharging."
  },
  repair_drone: {
    id: "repair_drone", name: "Repair Drone", slot: "passive",
    healPerSec: 3.0, maxHealRatio: 0.50, weight: 20.0,
    description: "Autonomous micro-drone orbiting the car to patch hull punctures over time."
  },
  countermeasures: {
    id: "countermeasures", name: "Countermeasures", slot: "passive",
    cooldown: 8.0, range: 30.0, maxAmmo: 4, weight: 8.0,
    description: "Automated flare decoys disrupting incoming homing missile guidance."
  },
  nitro_tank: {
    id: "nitro_tank", name: "Nitro Tank", slot: "passive",
    nitroCapacityBonus: 50.0, rechargeRateBonus: 0.30, weight: 25.0,
    description: "Auxiliary nitrous oxide reservoir delivering extended boost duration."
  }
};

class WeaponSystem {
  constructor(vehicle) {
    this.vehicle = vehicle;
    this.primaryWeapon = WEAPONS.twin_mg;
    this.roofWeapon = WEAPONS.rocket_pod;
    this.rearWeapon = WEAPONS.mine_dropper;
    this.passiveWeapon = WEAPONS.armour_plating;

    this.primaryCooldown = 0;
    this.roofCooldown = 0;
    this.rearCooldown = 0;
    this.heat = 0;
    this.isOverheated = false;

    this.primaryAmmo = this.primaryWeapon.maxAmmo;
    this.roofAmmo = 6;
    this.rearAmmo = 3;

    this.currentTarget = null;
    this.targetDist = 0;
  }

  update(dt, enemyCars = []) {
    if (this.primaryCooldown > 0) this.primaryCooldown -= dt;
    if (this.roofCooldown > 0) this.roofCooldown -= dt;
    if (this.rearCooldown > 0) this.rearCooldown -= dt;

    // Heat dissipation
    if (this.heat > 0) {
      this.heat = Math.max(0, this.heat - dt * 0.35);
      if (this.isOverheated && this.heat < 0.25) this.isOverheated = false;
    }

    // Passive repair drone effect
    if (this.passiveWeapon && this.passiveWeapon.id === 'repair_drone' && !this.vehicle.isWrecked) {
      if (this.vehicle.health < this.vehicle.maxHealth * 0.5) {
        this.vehicle.health = Math.min(this.vehicle.maxHealth * 0.5, this.vehicle.health + dt * 3.0);
      }
    }

    // Auto-aim target acquisition in forward cone
    this.currentTarget = null;
    this.targetDist = 999;
    const forward = new THREE.Vector3(0, 0, -1).applyQuaternion(this.vehicle.quaternion);

    for (let enemy of enemyCars) {
      if (enemy === this.vehicle || enemy.isWrecked) continue;
      const toEnemy = enemy.position.clone().sub(this.vehicle.position);
      const dist = toEnemy.length();
      if (dist < 130.0) {
        toEnemy.normalize();
        const angle = forward.angleTo(toEnemy);
        if (angle < (this.roofWeapon.lockAngle || 0.61)) {
          if (dist < this.targetDist) {
            this.targetDist = dist;
            this.currentTarget = enemy;
          }
        }
      }
    }
  }

  canFirePrimary() {
    return this.primaryCooldown <= 0 && !this.isOverheated && this.primaryAmmo > 0 && !this.vehicle.isWrecked;
  }

  canFireRoof() {
    return this.roofCooldown <= 0 && this.roofAmmo > 0 && !this.vehicle.isWrecked;
  }

  canFireRear() {
    return this.rearCooldown <= 0 && this.rearAmmo > 0 && !this.vehicle.isWrecked;
  }
}
