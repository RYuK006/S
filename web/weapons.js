// web/weapons.js
// Stage 3 Vehicular Combat Arsenal: 10 Weapons & Vehicle Weapon System

const WEAPONS = {
  // --- PRIMARY FRONT WEAPONS ---
  twin_mg: {
    id: "twin_mg",
    name: "Twin MG",
    slot: "primary",
    damage: 12.0,
    fireRate: 12.5, // 0.08s cooldown
    range: 120.0,
    velocity: 340.0,
    heatPerShot: 0.012,
    maxAmmo: 999, // Infinite for player in Stage 3
    isBallistic: false,
    description: "Rapid-fire twin kinetic machine guns mounted on front quarter panels."
  },
  heavy_mg: {
    id: "heavy_mg",
    name: "Heavy MG",
    slot: "primary",
    damage: 26.0,
    fireRate: 6.5,
    range: 150.0,
    velocity: 380.0,
    heatPerShot: 0.024,
    maxAmmo: 300,
    isBallistic: false,
    description: "High-calibre armour-piercing rounds with heavy kinetic impact."
  },
  shotgun_cannon: {
    id: "shotgun_cannon",
    name: "Shotgun Cannon",
    slot: "primary",
    damage: 9.0, // per pellet (8 pellets = 72 dmg)
    pellets: 8,
    fireRate: 1.8,
    range: 50.0,
    velocity: 280.0,
    spreadAngle: 0.14,
    heatPerShot: 0.08,
    maxAmmo: 45,
    isBallistic: false,
    description: "8-pellet buckshot blast devastating in close bumper-to-bumper combat."
  },

  // --- ROOF WEAPONS ---
  rocket_pod: {
    id: "rocket_pod",
    name: "Rocket Pod",
    slot: "roof",
    damage: 48.0,
    blastRadius: 5.5,
    fireRate: 1.25, // 0.8s cooldown
    velocity: 160.0,
    range: 160.0,
    salvoCount: 1,
    maxAmmo: 18,
    isHoming: false,
    description: "High-velocity unguided ballistic rockets with explosive blast radius."
  },
  homing_missile: {
    id: "homing_missile",
    name: "Homing Missile",
    slot: "roof",
    damage: 85.0,
    blastRadius: 6.5,
    fireRate: 0.75, // 1.33s cooldown
    velocity: 130.0,
    range: 180.0,
    turnRate: 6.0, // rad/s
    lockAngle: 0.61, // ~35 degrees
    maxAmmo: 6,
    isHoming: true,
    description: "Laser-guided tracking missile with terminal seeking and devastating splash."
  },

  // --- REAR WEAPONS ---
  mine_dropper: {
    id: "mine_dropper",
    name: "Mine Dropper",
    slot: "rear",
    damage: 120.0,
    blastRadius: 6.0,
    armDelay: 0.8,
    triggerRadius: 3.5,
    fireRate: 0.65,
    maxAmmo: 6,
    impulse: 18000.0,
    description: "Magnetic proximity contact mines that launch tailgating rivals airborne."
  },
  oil_slick: {
    id: "oil_slick",
    name: "Oil Slick",
    slot: "rear",
    damage: 0.0,
    duration: 12.0,
    triggerRadius: 3.2,
    slipMu: 0.20,
    slipDuration: 4.0,
    fireRate: 0.5,
    maxAmmo: 4,
    description: "Viscous synthetic lubricant puddle that induces severe loss of control."
  },

  // --- PASSIVE WEAPONS ---
  ram_plate: {
    id: "ram_plate",
    name: "Ram Plate",
    slot: "passive",
    collisionDmgMult: 2.4,
    selfDamageReduction: 0.60,
    description: "Reinforced front-end cow-catcher doubling ramming damage while reducing self damage."
  },
  armour_plating: {
    id: "armour_plating",
    name: "Armour Plating",
    slot: "passive",
    bonusHealth: 250.0,
    damageResistance: 0.25,
    description: "Hardened composite panels granting +250 HP and 25% damage mitigation."
  },
  countermeasures: {
    id: "countermeasures",
    name: "Countermeasures",
    slot: "passive",
    cooldown: 8.0,
    range: 30.0,
    description: "Automated flare decoys disrupting incoming homing missile guidance."
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
