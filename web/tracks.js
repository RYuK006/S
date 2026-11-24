// web/tracks.js
// Spline Track Construction, Checkpoint Gates and Dynamic Circuit Pickups

const circuitPoints = [
  new THREE.Vector3(0, 0, 0),
  new THREE.Vector3(0, 0, -140),
  new THREE.Vector3(40, 2.5, -240),
  new THREE.Vector3(120, 4.0, -280),
  new THREE.Vector3(220, 2.0, -240),
  new THREE.Vector3(260, 0, -140),
  new THREE.Vector3(250, 0, 40),
  new THREE.Vector3(210, 1.5, 140),
  new THREE.Vector3(160, 1.0, 180),
  new THREE.Vector3(90, 0, 160),
  new THREE.Vector3(30, 0, 100),
  new THREE.Vector3(0, 0, 30)
];

const splineCurve = new THREE.CatmullRomCurve3(circuitPoints, true, 'catmullrom', 0.5);
const splineSamples = splineCurve.getSpacedPoints(180);

// Generate Checkpoint Gates
const numCheckpoints = 18;
const checkpointGates = [];
for (let i = 0; i < numCheckpoints; i++) {
  let idx = Math.floor((i / numCheckpoints) * splineSamples.length);
  checkpointGates.push(splineSamples[idx]);
}

function buildTrackRoad(scene) {
  const roadWidth = 14.0;
  const geom = new THREE.BufferGeometry();
  const verts = [], uvs = [], indices = [];

  for (let i = 0; i < splineSamples.length; i++) {
    const pt = splineSamples[i];
    const nextPt = splineSamples[(i + 1) % splineSamples.length];
    const forward = new THREE.Vector3().subVectors(nextPt, pt).normalize();
    const right = new THREE.Vector3().crossVectors(forward, new THREE.Vector3(0, 1, 0)).normalize();

    const pL = pt.clone().sub(right.clone().multiplyScalar(roadWidth * 0.5));
    const pR = pt.clone().add(right.clone().multiplyScalar(roadWidth * 0.5));
    verts.push(pL.x, pL.y + 0.04, pL.z);
    verts.push(pR.x, pR.y + 0.04, pR.z);
    uvs.push(0, i * 0.2, 1, i * 0.2);

    if (i < splineSamples.length - 1) {
      let b = i * 2;
      indices.push(b, b + 1, b + 3, b, b + 3, b + 2);
    }
  }
  // Connect loop
  let lastB = (splineSamples.length - 1) * 2;
  indices.push(lastB, lastB + 1, 1, lastB, 1, 0);

  geom.setAttribute('position', new THREE.Float32BufferAttribute(verts, 3));
  geom.setAttribute('uv', new THREE.Float32BufferAttribute(uvs, 2));
  geom.setIndex(indices);
  geom.computeVertexNormals();

  const roadMat = new THREE.MeshStandardMaterial({ color: 0x222226, roughness: 0.65 });
  const roadMesh = new THREE.Mesh(geom, roadMat);
  roadMesh.receiveShadow = true;
  scene.add(roadMesh);
}

// Dynamic Track Pickups Manager
class TrackPickupManager {
  constructor(scene) {
    this.scene = scene;
    this.pickups = [];

    // Place pickups at interesting track locations
    const spawnGateIndices = [2, 5, 8, 11, 14, 17];
    const types = ['repair', 'ammo', 'nitro', 'repair', 'ammo', 'nitro'];

    for (let i = 0; i < spawnGateIndices.length; i++) {
      const gateIdx = spawnGateIndices[i];
      const pt = checkpointGates[gateIdx];
      const type = types[i];
      this.createPickup(pt.clone().add(new THREE.Vector3(0, 1.2, 0)), type);
    }
  }

  createPickup(pos, type) {
    const group = new THREE.Group();
    group.position.copy(pos);

    let mat, geom;
    if (type === 'repair') {
      mat = new THREE.MeshStandardMaterial({ color: 0x00ff66, emissive: 0x00cc44, emissiveIntensity: 1.2, roughness: 0.2 });
      // Cross shape
      const c1 = new THREE.Mesh(new THREE.BoxGeometry(0.8, 0.25, 0.25), mat);
      const c2 = new THREE.Mesh(new THREE.BoxGeometry(0.25, 0.8, 0.25), mat);
      group.add(c1); group.add(c2);
    } else if (type === 'ammo') {
      mat = new THREE.MeshStandardMaterial({ color: 0xffaa00, emissive: 0xff6600, emissiveIntensity: 1.0, roughness: 0.3 });
      const box = new THREE.Mesh(new THREE.BoxGeometry(0.65, 0.45, 0.45), mat);
      group.add(box);
    } else { // nitro
      mat = new THREE.MeshStandardMaterial({ color: 0x00d4ff, emissive: 0x0088ff, emissiveIntensity: 1.5, roughness: 0.2 });
      const cyl = new THREE.Mesh(new THREE.CylinderGeometry(0.22, 0.22, 0.75, 12), mat);
      group.add(cyl);
    }

    this.scene.add(group);
    this.pickups.push({
      group,
      baseY: pos.y,
      type,
      respawnTimer: 0,
      active: true
    });
  }

  update(dt, vehicles = []) {
    const time = performance.now() * 0.003;
    for (let p of this.pickups) {
      if (!p.active) {
        p.respawnTimer -= dt;
        if (p.respawnTimer <= 0) {
          p.active = true;
          p.group.visible = true;
        }
        continue;
      }

      // Hover and rotate
      p.group.rotation.y += dt * 2.2;
      p.group.position.y = p.baseY + Math.sin(time + p.baseY) * 0.25;

      // Contact detection with vehicles
      for (let v of vehicles) {
        if (v.isWrecked) continue;
        if (v.position.distanceTo(p.group.position) < 3.2) {
          this.collect(p, v);
          break;
        }
      }
    }
  }

  collect(p, vehicle) {
    p.active = false;
    p.group.visible = false;
    p.respawnTimer = 15.0; // 15s respawn

    if (window.audio) window.audio.playPickupChime();

    if (p.type === 'repair') {
      vehicle.health = Math.min(vehicle.maxHealth, vehicle.health + 250.0);
      if (!vehicle.isAI && window.addBattleFeed) window.addBattleFeed("+250 ARMOUR RESTORED");
    } else if (p.type === 'ammo') {
      vehicle.weapons.roofAmmo = Math.min(vehicle.weapons.roofWeapon.maxAmmo, vehicle.weapons.roofAmmo + 3);
      vehicle.weapons.rearAmmo = Math.min(vehicle.weapons.rearWeapon.maxAmmo, vehicle.weapons.rearAmmo + 2);
      if (!vehicle.isAI && window.addBattleFeed) window.addBattleFeed("+AMMO & ROCKETS REFILLED");
    } else if (p.type === 'nitro') {
      vehicle.nitroAmount = Math.min(100.0, vehicle.nitroAmount + 50.0);
      if (!vehicle.isAI && window.addBattleFeed) window.addBattleFeed("+50% NITRO BOOST");
    }
  }
}
