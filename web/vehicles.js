// web/vehicles.js
// Procedural Vehicle Architecture, 120Hz Dynamics, Damage & Procedural Mesh

class VehicleController {
  constructor(scene, colorHex = 0xee1808, isAI = false, driverName = "Player") {
    this.scene = scene;
    this.isAI = isAI;
    this.driverName = driverName;
    this.colorHex = colorHex;

    this.mass = 1050.0;
    this.position = new THREE.Vector3(0, 1.2, 0);
    this.quaternion = new THREE.Quaternion();
    this.velocity = new THREE.Vector3();
    this.angularVelocity = new THREE.Vector3();
    this.matrixWorld = new THREE.Matrix4();

    this.speedKmh = 0;
    this.engineRPM = 900;
    this.currentGear = 1;
    this.turboBoost = 0;
    this.nitroAmount = 100.0;
    this.nitroActive = false;

    // Combat & Health
    this.maxHealth = 700.0;
    this.health = 700.0;
    this.isWrecked = false;
    this.respawnTimer = 0;
    this.invulnerableTimer = 0;
    this.revengeTarget = null;
    this.slipTimer = 0; // Triggered by oil slicks

    this.throttleInput = 0;
    this.brakeInput = 0;
    this.steerInput = 0;
    this.handbrake = false;

    // AI state
    this.waypointIdx = 0;
    this.targetSpeed = 120.0;

    const wbHalf = 2.45 * 0.5;
    const twHalf = 1.62 * 0.5;
    this.fl = new RaycastWheel(true, true, new THREE.Vector3(-twHalf, -0.2, -wbHalf));
    this.fr = new RaycastWheel(true, false, new THREE.Vector3(twHalf, -0.2, -wbHalf));
    this.rl = new RaycastWheel(false, true, new THREE.Vector3(-twHalf, -0.2, wbHalf));
    this.rr = new RaycastWheel(false, false, new THREE.Vector3(twHalf, -0.2, wbHalf));
    this.fl.oppositeWheel = this.fr; this.fr.oppositeWheel = this.fl;
    this.rl.oppositeWheel = this.rr; this.rr.oppositeWheel = this.rl;
    this.wheels = [this.fl, this.fr, this.rl, this.rr];

    // Procedural Mesh & Materials
    this.paintMat = new THREE.MeshPhysicalMaterial({
      color: colorHex, metalness: 0.82, roughness: 0.14, clearcoat: 1.0, clearcoatRoughness: 0.04
    });
    this.charredMat = new THREE.MeshStandardMaterial({
      color: 0x18181a, roughness: 0.95, metalness: 0.1
    });

    this.meshGroup = buildProceduralSprinterMesh(this);
    this.scene.add(this.meshGroup);

    // Weapon system attached to car
    this.weapons = new WeaponSystem(this);
  }

  applyDamage(amount, attacker = null, hitLocalPos = null) {
    if (this.isWrecked || this.invulnerableTimer > 0) return;

    // Apply passive armour mitigation (25%)
    let effectiveDamage = amount;
    if (this.weapons.passiveWeapon && this.weapons.passiveWeapon.id === 'armour_plating') {
      effectiveDamage *= (1.0 - this.weapons.passiveWeapon.damageResistance);
    }

    this.health = Math.max(0, this.health - effectiveDamage);

    // AI revenge targeting
    if (this.isAI && attacker && attacker !== this) {
      this.revengeTarget = attacker;
    }

    // Dynamic mesh denting
    if (hitLocalPos && this.bodyGeo) {
      this.dentMesh(hitLocalPos, 1.2, 0.22);
    }

    // Fatal Wreck trigger
    if (this.health <= 0 && !this.isWrecked) {
      this.isWrecked = true;
      this.respawnTimer = 3.5;
      this.bodyMesh.material = this.charredMat;
      this.velocity.multiplyScalar(0.4);
      this.angularVelocity.set((Math.random()-0.5)*4, (Math.random()-0.5)*6, (Math.random()-0.5)*4);

      if (window.audio) window.audio.playExplosion();
      if (window.spawnExplosion) window.spawnExplosion(this.position.clone().add(new THREE.Vector3(0, 0.8, 0)));

      // Battle Feed Announcement
      if (window.addBattleFeed) {
        const victimName = this.isAI ? this.driverName : "YOU";
        const killerName = attacker ? (attacker.isAI ? attacker.driverName : "YOU") : "THE TRACK";
        window.addBattleFeed(`${killerName} WRECKED ${victimName}!`);
      }
    }
  }

  dentMesh(localHit, radius, strength) {
    const pos = this.bodyGeo.attributes.position;
    for (let i = 0; i < pos.count; i++) {
      let vx = pos.getX(i), vy = pos.getY(i), vz = pos.getZ(i);
      let dx = vx - localHit.x, dy = vy - localHit.y, dz = vz - localHit.z;
      let d = Math.sqrt(dx*dx + dy*dy + dz*dz);
      if (d < radius) {
        let factor = (1.0 - d / radius) * strength;
        pos.setXYZ(i, vx - dx * factor, vy - Math.abs(dy) * factor * 0.5, vz - dz * factor);
      }
    }
    pos.needsUpdate = true;
    this.bodyGeo.computeVertexNormals();
  }

  respawn(spawnPos, spawnQuat) {
    this.isWrecked = false;
    this.health = this.maxHealth;
    this.position.copy(spawnPos);
    this.quaternion.copy(spawnQuat);
    this.velocity.set(0, 0, 0);
    this.angularVelocity.set(0, 0, 0);
    this.invulnerableTimer = 1.8;
    this.bodyMesh.material = this.paintMat;
  }

  physicsStep(dt) {
    if (this.invulnerableTimer > 0) this.invulnerableTimer -= dt;

    if (this.isWrecked) {
      this.respawnTimer -= dt;
      // Wrecked vehicle continues to skid and settle
      this.velocity.multiplyScalar(0.96);
      this.angularVelocity.multiplyScalar(0.94);
      this.position.add(this.velocity.clone().multiplyScalar(dt));
      const rotDelta = new THREE.Quaternion().setFromEuler(new THREE.Euler(
        this.angularVelocity.x * dt, this.angularVelocity.y * dt, this.angularVelocity.z * dt
      ));
      this.quaternion.multiply(rotDelta).normalize();
      this.meshGroup.position.copy(this.position);
      this.meshGroup.quaternion.copy(this.quaternion);

      // Smoke and fire trail when wrecked
      if (Math.random() < 0.4 && window.spawnSmoke) {
        window.spawnSmoke(this.position.clone().add(new THREE.Vector3((Math.random()-0.5)*0.8, 0.6, (Math.random()-0.5)*0.8)));
      }
      return;
    }

    // Oil slick slip effect
    let surfaceMu = 1.0;
    if (this.slipTimer > 0) {
      this.slipTimer -= dt;
      surfaceMu = 0.22;
    }

    this.matrixWorld.compose(this.position, this.quaternion, new THREE.Vector3(1, 1, 1));
    this.speedKmh = this.velocity.length() * 3.6;

    if (this.throttleInput > 0.3) this.turboBoost = Math.min(1.0, this.turboBoost + dt * 1.5);
    else this.turboBoost = Math.max(0.0, this.turboBoost - dt * 3.0);

    const rpmNorm = Math.max(0, Math.min(1, (this.engineRPM - 900) / (7200 - 900)));
    let engineTorque = 280.0 * (0.6 + 0.4 * Math.sin(rpmNorm * Math.PI)) * this.throttleInput;
    if (this.nitroActive) engineTorque *= 1.8;

    if (this.engineRPM > 6800 && this.currentGear < 5) this.currentGear++;
    else if (this.engineRPM < 2200 && this.currentGear > 1) this.currentGear--;

    const totalRatio = [3.42, 2.14, 1.45, 1.10, 0.86][this.currentGear - 1] * 4.10;
    const axleTorque = engineTorque * totalRatio;
    this.fl.driveTorque = axleTorque * 0.30;
    this.fr.driveTorque = axleTorque * 0.30;
    this.rl.driveTorque = axleTorque * 0.20;
    this.rr.driveTorque = axleTorque * 0.20;

    const maxBrake = 3800.0;
    this.fl.brakeTorque = this.brakeInput * maxBrake * 0.325;
    this.fr.brakeTorque = this.brakeInput * maxBrake * 0.325;
    this.rl.brakeTorque = this.brakeInput * maxBrake * 0.175;
    this.rr.brakeTorque = this.brakeInput * maxBrake * 0.175;

    if (this.handbrake) {
      this.rl.brakeTorque += maxBrake * 1.5;
      this.rr.brakeTorque += maxBrake * 1.5;
      this.rl.handbrakeFactor = 0.35;
      this.rr.handbrakeFactor = 0.35;
    } else {
      this.rl.handbrakeFactor = 1.0;
      this.rr.handbrakeFactor = 1.0;
    }

    const maxSteerRad = (34.0 - Math.min(22.0, this.speedKmh * 0.12)) * (Math.PI / 180.0);
    this.fl.steerAngle = this.steerInput * maxSteerRad;
    this.fr.steerAngle = this.steerInput * maxSteerRad;

    let netForce = new THREE.Vector3(0, -9.81 * this.mass, 0);
    let netTorqueBody = new THREE.Vector3();

    for (let w of this.wheels) {
      w.surfaceMu = surfaceMu;
      const f = w.update(this, dt, 0.0);
      netForce.add(f);
      const rArm = w.relPos.clone().applyQuaternion(this.quaternion);
      netTorqueBody.add(new THREE.Vector3().crossVectors(rArm, f));
    }

    const vSq = this.velocity.lengthSq();
    if (vSq > 0.5) {
      netForce.add(this.velocity.clone().normalize().multiplyScalar(-0.5 * 1.225 * 0.34 * 2.1 * vSq));
    }

    this.velocity.add(netForce.divideScalar(this.mass).multiplyScalar(dt));
    this.position.add(this.velocity.clone().multiplyScalar(dt));

    this.angularVelocity.add(netTorqueBody.divideScalar(this.mass * 1.2).multiplyScalar(dt)).multiplyScalar(0.96);
    const rotDelta = new THREE.Quaternion().setFromEuler(new THREE.Euler(
      this.angularVelocity.x * dt, this.angularVelocity.y * dt, this.angularVelocity.z * dt
    ));
    this.quaternion.multiply(rotDelta).normalize();

    const drivenRPM = Math.abs(((this.rl.wheelAngularVelocity + this.rr.wheelAngularVelocity) * 0.5) * totalRatio * (60.0 / (2.0 * Math.PI)));
    this.engineRPM = Math.max(900, Math.min(7200, drivenRPM + this.throttleInput * 800));

    this.meshGroup.position.copy(this.position);
    this.meshGroup.quaternion.copy(this.quaternion);

    // Update floating health bar visual
    if (this.hpFillMesh) {
      const hpPct = Math.max(0, this.health / this.maxHealth);
      this.hpFillMesh.scale.x = hpPct;
      this.hpFillMesh.position.x = -(1.0 - hpPct) * 0.7;
      if (hpPct < 0.3) this.hpFillMesh.material.color.setHex(0xff2200);
      else if (hpPct < 0.6) this.hpFillMesh.material.color.setHex(0xffaa00);
      else this.hpFillMesh.material.color.setHex(0x00ff66);
    }
  }
}

function buildProceduralSprinterMesh(car) {
  const group = new THREE.Group();
  const bodyGeo = new THREE.BoxGeometry(1.68, 0.72, 3.8, 5, 4, 8);
  const pos = bodyGeo.attributes.position;
  for (let i = 0; i < pos.count; i++) {
    let x = pos.getX(i), y = pos.getY(i), z = pos.getZ(i);
    if (z < -0.8) { y *= (1.0 - (-z - 0.8) * 0.35); x *= (1.0 - (-z - 0.8) * 0.15); }
    if (y > 0.2 && z > -0.6 && z < 1.2) x *= 0.88;
    pos.setXYZ(i, x, y + 0.35, z);
  }
  bodyGeo.computeVertexNormals();
  car.bodyGeo = bodyGeo;

  const bodyMesh = new THREE.Mesh(bodyGeo, car.paintMat);
  bodyMesh.castShadow = true;
  group.add(bodyMesh);
  car.bodyMesh = bodyMesh;

  // Rear Wing
  const wing = new THREE.Mesh(new THREE.BoxGeometry(1.35, 0.06, 0.35), new THREE.MeshStandardMaterial({ color: 0x111113 }));
  wing.position.set(0, 0.95, 1.4);
  group.add(wing);

  // Twin Front Machine Guns
  const mgMat = new THREE.MeshStandardMaterial({ color: 0x222225, metalness: 0.9, roughness: 0.3 });
  for (let s of [-1, 1]) {
    const mgBarrel = new THREE.Mesh(new THREE.CylinderGeometry(0.045, 0.045, 0.7, 8).rotateX(Math.PI / 2), mgMat);
    mgBarrel.position.set(s * 0.52, 0.48, -1.8);
    group.add(mgBarrel);
  }

  // Roof Rocket Launcher Pod
  const podMat = new THREE.MeshStandardMaterial({ color: 0x2e3036, metalness: 0.8, roughness: 0.4 });
  const pod = new THREE.Mesh(new THREE.BoxGeometry(0.38, 0.22, 0.7), podMat);
  pod.position.set(0, 1.05, 0.1);
  group.add(pod);
  for (let rx of [-0.1, 0.1]) {
    const tube = new THREE.Mesh(new THREE.CylinderGeometry(0.05, 0.05, 0.72, 8).rotateX(Math.PI / 2), mgMat);
    tube.position.set(rx, 1.05, 0.1);
    group.add(tube);
  }

  // Headlights
  const hlMat = new THREE.MeshStandardMaterial({ color: 0xffffff, emissive: 0xe6f0ff, emissiveIntensity: 2.5 });
  for (let s of [-1, 1]) {
    const hl = new THREE.Mesh(new THREE.BoxGeometry(0.24, 0.12, 0.04), hlMat);
    hl.position.set(s * 0.58, 0.42, -1.9);
    group.add(hl);
  }

  // Floating 3D Health Bar (for AI and rivals)
  if (car.isAI) {
    const hpBg = new THREE.Mesh(new THREE.PlaneGeometry(1.44, 0.14), new THREE.MeshBasicMaterial({ color: 0x111111, side: THREE.DoubleSide }));
    hpBg.position.set(0, 1.5, 0);
    const hpFill = new THREE.Mesh(new THREE.PlaneGeometry(1.4, 0.11), new THREE.MeshBasicMaterial({ color: 0x00ff66, side: THREE.DoubleSide }));
    hpFill.position.set(0, 1.5, 0.01);
    car.hpFillMesh = hpFill;
    group.add(hpBg);
    group.add(hpFill);
  }

  // Wheels
  const wheelGeo = new THREE.CylinderGeometry(0.32, 0.32, 0.22, 20);
  wheelGeo.rotateZ(Math.PI / 2);
  const tireMat = new THREE.MeshStandardMaterial({ color: 0x141416, roughness: 0.85 });
  const rimMat = new THREE.MeshStandardMaterial({ color: 0xc8cbd0, metalness: 0.95, roughness: 0.15 });

  for (let w of car.wheels) {
    const wGroup = new THREE.Group();
    const tire = new THREE.Mesh(wheelGeo, tireMat);
    wGroup.add(tire);
    const rim = new THREE.Mesh(new THREE.CylinderGeometry(0.20, 0.20, 0.23, 16).rotateZ(Math.PI / 2), rimMat);
    wGroup.add(rim);
    wGroup.position.copy(w.relPos);
    w.visualMesh = wGroup;
    group.add(wGroup);
  }
  return group;
}
