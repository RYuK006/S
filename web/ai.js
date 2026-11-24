// web/ai.js
// AI Navigation, Curvature Speed Profiling, Tactical Combat & Revenge System

function updateAI(aiObj, dt, allCars = [], combatMgr = null) {
  const car = aiObj.car;
  if (car.isWrecked) return;

  const numPts = splineSamples.length;

  // 1. Spline Navigation: Look ahead for target waypoint
  let bestIdx = car.waypointIdx;
  let bestDistSq = 1e9;
  for (let o = -3; o <= 8; o++) {
    let idx = (car.waypointIdx + o + numPts) % numPts;
    let d = car.position.distanceToSquared(splineSamples[idx]);
    if (d < bestDistSq) { bestDistSq = d; bestIdx = idx; }
  }
  car.waypointIdx = (bestIdx + 10) % numPts;
  const targetPt = splineSamples[car.waypointIdx];

  const forward = new THREE.Vector3(0, 0, -1).applyQuaternion(car.quaternion);
  const toTarget = targetPt.clone().sub(car.position).normalize();
  const right = new THREE.Vector3(1, 0, 0).applyQuaternion(car.quaternion);

  const steerDot = right.dot(toTarget);
  car.steerInput = THREE.MathUtils.lerp(car.steerInput, THREE.MathUtils.clamp(steerDot * 2.2, -1.0, 1.0), dt * 6.0);

  // 2. Curvature speed profiling
  const aheadPt = splineSamples[(car.waypointIdx + 8) % numPts];
  const turnAngle = toTarget.angleTo(aheadPt.clone().sub(targetPt).normalize());
  let safeSpeed = THREE.MathUtils.clamp(175.0 - (turnAngle * 120.0), 60.0, 175.0);

  // Aggressive personality boosts speed
  if (aiObj.cfg.style === "Aggressive" || car.revengeTarget) {
    safeSpeed = Math.min(185.0, safeSpeed * 1.1);
  }

  if (car.speedKmh < safeSpeed) {
    car.throttleInput = 1.0;
    car.brakeInput = 0.0;
  } else {
    car.throttleInput = 0.0;
    car.brakeInput = THREE.MathUtils.clamp((car.speedKmh - safeSpeed) * 0.05, 0.2, 1.0);
  }

  // 3. Combat Evaluation & Weapon Firing
  if (!combatMgr) return;
  car.weapons.update(dt, allCars);

  // Target selection: prefer revenge target if in view
  let target = car.revengeTarget && !car.revengeTarget.isWrecked ? car.revengeTarget : car.weapons.currentTarget;

  if (target && !target.isWrecked) {
    const toEnemy = target.position.clone().sub(car.position);
    const dist = toEnemy.length();
    toEnemy.normalize();
    const angle = forward.angleTo(toEnemy);

    // Front Machine Gun: burst fire when within 55m and aligned
    if (dist < 55.0 && angle < 0.35 && car.weapons.canFirePrimary()) {
      if (Math.random() < 0.6) {
        combatMgr.fireBullets(car, car.weapons.primaryWeapon, target);
        car.weapons.primaryCooldown = 1.0 / car.weapons.primaryWeapon.fireRate;
      }
    }

    // Roof Rocket: launch if target within 45m
    if (dist < 45.0 && angle < 0.40 && car.weapons.canFireRoof()) {
      if (Math.random() < 0.25) {
        combatMgr.launchRocket(car, car.weapons.roofWeapon, target);
        car.weapons.roofAmmo--;
        car.weapons.roofCooldown = 1.0 / car.weapons.roofWeapon.fireRate;
      }
    }
  }

  // Tailgating check: drop mine if someone is riding rear bumper
  for (let other of allCars) {
    if (other === car || other.isWrecked) continue;
    const toOther = other.position.clone().sub(car.position);
    const dist = toOther.length();
    if (dist < 8.0 && forward.dot(toOther.normalize()) < -0.7) {
      if (car.weapons.canFireRear() && Math.random() < 0.3) {
        combatMgr.dropMine(car, car.weapons.rearWeapon);
        car.weapons.rearAmmo--;
        car.weapons.rearCooldown = 2.0;
        break;
      }
    }
  }
}
