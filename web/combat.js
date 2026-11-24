// web/combat.js
// Sub-stepped Ballistics, Homing Guidance, Explosions, Mines & Combat Manager

class CombatManager {
  constructor(scene) {
    this.scene = scene;
    this.projectiles = [];
    this.mines = [];
    this.oilSlicks = [];
    this.explosions = [];
    this.smokePuffs = [];

    // Shared geometries and materials
    this.bulletGeo = new THREE.CylinderGeometry(0.04, 0.04, 1.2, 6).rotateX(Math.PI / 2);
    this.bulletMat = new THREE.MeshBasicMaterial({ color: 0xffcc33 });

    this.rocketGeo = new THREE.CylinderGeometry(0.08, 0.08, 0.9, 8).rotateX(Math.PI / 2);
    this.rocketMat = new THREE.MeshStandardMaterial({ color: 0x44444a, metalness: 0.8 });

    this.mineGeo = new THREE.CylinderGeometry(0.35, 0.42, 0.16, 12);
    this.mineMat = new THREE.MeshStandardMaterial({ color: 0x222225, metalness: 0.9, roughness: 0.3 });
    this.mineLightMat = new THREE.MeshBasicMaterial({ color: 0xff0000 });

    this.oilGeo = new THREE.CircleGeometry(2.4, 16).rotateX(-Math.PI / 2);
    this.oilMat = new THREE.MeshStandardMaterial({ color: 0x050508, roughness: 0.08, metalness: 0.9 });

    this.expGeo = new THREE.SphereGeometry(1, 12, 8);
    this.expMat = new THREE.MeshBasicMaterial({ color: 0xff6600, transparent: true, opacity: 0.9 });

    this.smokeGeo = new THREE.SphereGeometry(0.5, 8, 6);
  }

  fireBullets(sourceCar, weapon, target = null) {
    if (window.audio) window.audio.playGunfire();

    const forward = new THREE.Vector3(0, 0, -1).applyQuaternion(sourceCar.quaternion);
    const barrelOffsets = [-0.52, 0.52];

    for (let bx of barrelOffsets) {
      const bMesh = new THREE.Mesh(this.bulletGeo, this.bulletMat);
      const startPos = new THREE.Vector3(bx, 0.48, -1.8).applyQuaternion(sourceCar.quaternion).add(sourceCar.position);
      bMesh.position.copy(startPos);
      bMesh.quaternion.copy(sourceCar.quaternion);

      // Auto-aim deflection towards target if within cone
      let dir = forward.clone();
      if (target && !target.isWrecked) {
        const toTarget = target.position.clone().add(new THREE.Vector3(0, 0.5, 0)).sub(startPos).normalize();
        if (forward.angleTo(toTarget) < 0.45) {
          dir = toTarget;
        }
      }

      this.scene.add(bMesh);
      this.projectiles.push({
        mesh: bMesh,
        pos: startPos,
        velocity: dir.multiplyScalar(weapon.velocity),
        damage: weapon.damage,
        sourceCar: sourceCar,
        lifetime: weapon.range / weapon.velocity,
        type: 'bullet'
      });
    }

    // Recoil
    sourceCar.velocity.sub(forward.clone().multiplyScalar(0.4));
  }

  launchRocket(sourceCar, weapon, target = null) {
    if (window.audio) window.audio.playRocketLaunch();

    const forward = new THREE.Vector3(0, 0, -1).applyQuaternion(sourceCar.quaternion);
    const startPos = new THREE.Vector3(0, 1.05, -0.6).applyQuaternion(sourceCar.quaternion).add(sourceCar.position);

    const rMesh = new THREE.Mesh(this.rocketGeo, this.rocketMat);
    rMesh.position.copy(startPos);
    rMesh.quaternion.copy(sourceCar.quaternion);
    this.scene.add(rMesh);

    this.projectiles.push({
      mesh: rMesh,
      pos: startPos,
      forward: forward.clone(),
      velocity: forward.clone().multiplyScalar(weapon.velocity),
      damage: weapon.damage,
      blastRadius: weapon.blastRadius || 5.5,
      sourceCar: sourceCar,
      target: target,
      isHoming: !!weapon.isHoming,
      turnRate: weapon.turnRate || 6.0,
      lifetime: 2.5,
      type: 'rocket'
    });
  }

  dropMine(sourceCar, weapon) {
    const rearPos = new THREE.Vector3(0, 0.1, 2.2).applyQuaternion(sourceCar.quaternion).add(sourceCar.position);
    const group = new THREE.Group();
    group.position.copy(rearPos);

    const mBase = new THREE.Mesh(this.mineGeo, this.mineMat);
    const mLight = new THREE.Mesh(new THREE.SphereGeometry(0.08, 8, 8), this.mineLightMat);
    mLight.position.y = 0.12;
    group.add(mBase);
    group.add(mLight);
    this.scene.add(group);

    this.mines.push({
      group: group,
      pos: rearPos,
      sourceCar: sourceCar,
      armTimer: weapon.armDelay || 0.8,
      damage: weapon.damage || 120.0,
      blastRadius: weapon.blastRadius || 6.0,
      triggerRadius: weapon.triggerRadius || 3.5,
      active: true
    });
  }

  dropOilSlick(sourceCar, weapon) {
    const rearPos = new THREE.Vector3(0, 0.05, 2.2).applyQuaternion(sourceCar.quaternion).add(sourceCar.position);
    const slick = new THREE.Mesh(this.oilGeo, this.oilMat);
    slick.position.copy(rearPos);
    this.scene.add(slick);

    this.oilSlicks.push({
      mesh: slick,
      pos: rearPos,
      lifetime: weapon.duration || 12.0
    });
  }

  spawnExplosion(pos, maxRadius = 4.5) {
    const expMesh = new THREE.Mesh(this.expGeo, this.expMat.clone());
    expMesh.position.copy(pos);
    this.scene.add(expMesh);

    this.explosions.push({
      mesh: expMesh,
      radius: 0.5,
      maxRadius: maxRadius,
      life: 0.45,
      maxLife: 0.45
    });

    // Spawn burst smoke
    for (let i = 0; i < 4; i++) {
      this.spawnSmoke(pos.clone().add(new THREE.Vector3((Math.random()-0.5)*1.5, Math.random()*1.2, (Math.random()-0.5)*1.5)));
    }
  }

  spawnSmoke(pos) {
    const sMat = new THREE.MeshBasicMaterial({ color: 0x333336, transparent: true, opacity: 0.7 });
    const sMesh = new THREE.Mesh(this.smokeGeo, sMat);
    sMesh.position.copy(pos);
    this.scene.add(sMesh);

    this.smokePuffs.push({
      mesh: sMesh,
      pos: pos,
      vel: new THREE.Vector3((Math.random()-0.5)*0.8, 1.2 + Math.random()*1.5, (Math.random()-0.5)*0.8),
      scale: 0.6,
      life: 0.85,
      maxLife: 0.85
    });
  }

  update(dt, allCars = []) {
    // 1. Update Projectiles
    for (let i = this.projectiles.length - 1; i >= 0; i--) {
      const p = this.projectiles[i];
      p.lifetime -= dt;

      if (p.isHoming && p.target && !p.target.isWrecked) {
        const toTarget = p.target.position.clone().add(new THREE.Vector3(0, 0.5, 0)).sub(p.pos).normalize();
        const currentDir = p.velocity.clone().normalize();
        currentDir.lerp(toTarget, dt * p.turnRate).normalize();
        p.velocity.copy(currentDir.multiplyScalar(130.0));
        p.mesh.quaternion.setFromUnitVectors(new THREE.Vector3(0, 0, -1), currentDir);
      }

      p.pos.add(p.velocity.clone().multiplyScalar(dt));
      p.mesh.position.copy(p.pos);

      // Check collision with cars
      let collided = false;
      for (let car of allCars) {
        if (car === p.sourceCar || car.isWrecked) continue;
        if (car.position.distanceTo(p.pos) < 2.2) {
          collided = true;
          const hitLocal = p.pos.clone().sub(car.position);
          car.applyDamage(p.damage, p.sourceCar, hitLocal);

          if (p.type === 'rocket') {
            this.explodeRocket(p, allCars);
          }
          break;
        }
      }

      // Smoke puff behind rockets
      if (p.type === 'rocket' && Math.random() < 0.5) {
        this.spawnSmoke(p.pos.clone());
      }

      if (collided || p.lifetime <= 0) {
        if (p.type === 'rocket' && !collided) {
          this.explodeRocket(p, allCars);
        }
        this.scene.remove(p.mesh);
        this.projectiles.splice(i, 1);
      }
    }

    // 2. Update Mines
    for (let i = this.mines.length - 1; i >= 0; i--) {
      const m = this.mines[i];
      if (m.armTimer > 0) {
        m.armTimer -= dt;
        continue;
      }

      // Blinking red light
      m.group.children[1].visible = (Math.floor(performance.now() * 0.008) % 2 === 0);

      // Trigger detection
      let exploded = false;
      for (let car of allCars) {
        if (car.isWrecked) continue;
        if (car.position.distanceTo(m.pos) < m.triggerRadius) {
          exploded = true;
          this.spawnExplosion(m.pos, m.blastRadius);
          if (window.audio) window.audio.playExplosion();

          // Apply damage and airborne launch impulse
          for (let target of allCars) {
            const dist = target.position.distanceTo(m.pos);
            if (dist < m.blastRadius) {
              const dmg = m.damage * (1.0 - dist / m.blastRadius);
              target.applyDamage(dmg, m.sourceCar);
              // Blast impulse
              const impulseDir = target.position.clone().sub(m.pos).normalize().add(new THREE.Vector3(0, 0.8, 0)).normalize();
              target.velocity.add(impulseDir.multiplyScalar(22.0 * (1.0 - dist / m.blastRadius)));
            }
          }
          break;
        }
      }

      if (exploded) {
        this.scene.remove(m.group);
        this.mines.splice(i, 1);
      }
    }

    // 3. Update Oil Slicks
    for (let i = this.oilSlicks.length - 1; i >= 0; i--) {
      const o = this.oilSlicks[i];
      o.lifetime -= dt;
      for (let car of allCars) {
        if (car.isWrecked) continue;
        if (car.position.distanceTo(o.pos) < 2.5) {
          car.slipTimer = 3.5;
        }
      }
      if (o.lifetime <= 0) {
        this.scene.remove(o.mesh);
        this.oilSlicks.splice(i, 1);
      }
    }

    // 4. Update Explosions
    for (let i = this.explosions.length - 1; i >= 0; i--) {
      const e = this.explosions[i];
      e.life -= dt;
      const progress = 1.0 - (e.life / e.maxLife);
      const s = 0.5 + progress * e.maxRadius;
      e.mesh.scale.set(s, s, s);
      e.mesh.material.opacity = (1.0 - progress) * 0.9;
      if (e.life <= 0) {
        this.scene.remove(e.mesh);
        this.explosions.splice(i, 1);
      }
    }

    // 5. Update Smoke Puffs
    for (let i = this.smokePuffs.length - 1; i >= 0; i--) {
      const sm = this.smokePuffs[i];
      sm.life -= dt;
      sm.pos.add(sm.vel.clone().multiplyScalar(dt));
      sm.scale += dt * 1.5;
      sm.mesh.scale.set(sm.scale, sm.scale, sm.scale);
      sm.mesh.position.copy(sm.pos);
      sm.mesh.material.opacity = (sm.life / sm.maxLife) * 0.7;
      if (sm.life <= 0) {
        this.scene.remove(sm.mesh);
        this.smokePuffs.splice(i, 1);
      }
    }
  }

  explodeRocket(rocket, allCars) {
    this.spawnExplosion(rocket.pos, rocket.blastRadius);
    if (window.audio) window.audio.playExplosion();

    // Splash damage and impulse
    for (let car of allCars) {
      if (car.isWrecked) continue;
      const dist = car.position.distanceTo(rocket.pos);
      if (dist < rocket.blastRadius) {
        const falloff = 1.0 - (dist / rocket.blastRadius);
        car.applyDamage(rocket.damage * falloff, rocket.sourceCar);
        const impulse = car.position.clone().sub(rocket.pos).normalize().add(new THREE.Vector3(0, 0.4, 0)).normalize();
        car.velocity.add(impulse.multiplyScalar(14.0 * falloff));
      }
    }
  }
}
