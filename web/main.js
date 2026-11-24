// web/main.js
// Main Game Engine, 120Hz Loop, Scene Initialization, Controls & Game States

// Mobile Detection
const isMobile = /Android|iPhone|iPad|iPod|Windows Phone/i.test(navigator.userAgent);
if (isMobile) {
  document.getElementById('touch-controls').style.display = 'block';
  document.getElementById('controls-hint').style.display = 'none';
}

// Global Audio Instance
const audio = new ProceduralAudioEngine();
window.audio = audio;

// Three.js Scene, Camera, Renderer
const container = document.getElementById('canvas-container');
const scene = new THREE.Scene();
scene.background = new THREE.Color(0x7599c2);
scene.fog = new THREE.FogExp2(0x8fa8c6, 0.0035);

const renderer = new THREE.WebGLRenderer({ antialias: true, powerPreference: 'high-performance' });
renderer.setSize(window.innerWidth, window.innerHeight);
renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
renderer.toneMapping = THREE.ACESFilmicToneMapping;
renderer.toneMappingExposure = 1.05;
renderer.shadowMap.enabled = true;
renderer.shadowMap.type = THREE.PCFSoftShadowMap;
container.appendChild(renderer.domElement);

const camera = new THREE.PerspectiveCamera(68, window.innerWidth / window.innerHeight, 0.1, 1000);

const hemiLight = new THREE.HemisphereLight(0xddeeff, 0x3f352b, 0.8);
scene.add(hemiLight);

const sunLight = new THREE.DirectionalLight(0xffedd2, 3.2);
sunLight.position.set(-60, 80, -60);
sunLight.castShadow = true;
sunLight.shadow.mapSize.width = 2048;
sunLight.shadow.mapSize.height = 2048;
scene.add(sunLight);

// Ground & Road
const ground = new THREE.Mesh(new THREE.PlaneGeometry(1200, 1200).rotateX(-Math.PI / 2), new THREE.MeshStandardMaterial({ color: 0x5a4d3e, roughness: 0.95 }));
ground.receiveShadow = true;
scene.add(ground);
buildTrackRoad(scene);

// Subsystems
const saveManager = new SaveManager();
window.saveManager = saveManager;

const progression = new ProgressionManager(saveManager);
window.progression = progression;

const cheatMenu = new CheatMenuController(saveManager);
window.cheatMenu = cheatMenu;

const garage = new GarageController(scene, saveManager);
window.garage = garage;

const combatManager = new CombatManager(scene);
window.spawnExplosion = (pos) => combatManager.spawnExplosion(pos);
window.spawnSmoke = (pos) => combatManager.spawnSmoke(pos);

const pickupManager = new TrackPickupManager(scene);

const bossController = new BossController(scene);
window.bossController = bossController;

let currentBiomeGrip = 1.0;

function startCampaignRace(raceConfig) {
  const bio = BIOMES[raceConfig.region] || BIOMES.dust_bowl;
  scene.background = new THREE.Color(bio.skyColor);
  scene.fog.color = new THREE.Color(bio.fogColor);
  ground.material.color = new THREE.Color(bio.groundColor);
  hemiLight.color = new THREE.Color(bio.ambientLight);
  sunLight.color = new THREE.Color(bio.sunColor);

  currentBiomeGrip = bio.surfaceGrip;
  totalLaps = raceConfig.laps || 3;
  raceState = "COUNTDOWN";
  countdownTimer = 3.99;

  // Reset cars to starting grid
  playerCar.position.set(-3.5, 0.6, -35.0);
  playerCar.velocity.set(0, 0, 0);
  playerCar.health = playerCar.maxHealth;
  playerCar.isWrecked = false;

  for (let i = 0; i < aiCars.length; i++) {
    const ai = aiCars[i].car;
    ai.position.copy(aiConfigs[i].pos);
    ai.velocity.set(0, 0, 0);
    ai.health = ai.maxHealth;
    ai.isWrecked = false;
  }

  // Handle Boss Duel Mode
  if (raceConfig.mode === "boss_duel") {
    const bossRival = aiCars[aiCars.length - 1].car;
    bossController.startBossEncounter(bossRival, raceConfig.boss_name, raceConfig.boss_hp, raceConfig.boss_hp > 8000 ? 4 : 3);
  } else {
    bossController.container.style.display = 'none';
    bossController.isActive = false;
  }

  if (window.addBattleFeed) {
    window.addBattleFeed(`LAUNCHING ${raceConfig.name.toUpperCase()} (${raceConfig.mode.toUpperCase()})`);
  }
}
window.startCampaignRace = startCampaignRace;

// Grid Spawn: Player + 5 AI Rivals
const playerCar = new VehicleController(scene, 0xee1808, false, "Player");
playerCar.position.set(-3.5, 0.6, -35.0);

const aiConfigs = [
  { name: "Viktor 'Rotor' Hale", style: "Aggressive", color: 0xf23518, pos: new THREE.Vector3(3.5, 0.6, 15.0) },
  { name: "Mina Cross", style: "Tactical", color: 0x189bee, pos: new THREE.Vector3(-3.5, 0.6, 5.0) },
  { name: "Dozer Okafor", style: "Bully", color: 0x24d436, pos: new THREE.Vector3(3.5, 0.6, -5.0) },
  { name: "Lena Vash", style: "Drifter", color: 0xecb414, pos: new THREE.Vector3(-3.5, 0.6, -15.0) },
  { name: "'Hollow' Pike", style: "Trickster", color: 0xa828e0, pos: new THREE.Vector3(3.5, 0.6, -25.0) }
];

const allCars = [playerCar];
const aiCars = [];

for (let cfg of aiConfigs) {
  const ai = new VehicleController(scene, cfg.color, true, cfg.name);
  ai.position.copy(cfg.pos);
  allCars.push(ai);
  aiCars.push({ car: ai, cfg: cfg });
}

// Race Progression State
let raceState = "COUNTDOWN"; // COUNTDOWN, RACING, FINISHED
let countdownTimer = 3.99;
let totalLaps = 3;
let raceTime = 0;
let currentLapTime = 0;
let bestLapTime = 9999;

const carProgress = new Map();
for (let c of allCars) {
  carProgress.set(c, { lap: 1, nextGate: 1, score: 0, isFinished: false, lapTimer: 0 });
}

// Controls Listeners
const keys = {};
let mouseLeftDown = false;
let mouseRightDown = false;

window.addEventListener('keydown', (e) => {
  keys[e.code] = true;
  if (e.code === 'KeyC') cameraMode = (cameraMode + 1) % 3;
  if (e.code === 'F4') { e.preventDefault(); cheatMenu.toggle(); }
  if (e.code === 'KeyG') {
    const gModal = document.getElementById('garage-modal');
    if (gModal && gModal.style.display === 'flex') garage.closeGarageUI();
    else garage.openGarageUI();
  }
  if (e.code === 'KeyE' || e.code === 'KeyL') triggerDropMine();
  if (e.code === 'KeyK') triggerFireRocket();
});
window.addEventListener('keyup', (e) => { keys[e.code] = false; });

window.addEventListener('mousedown', (e) => {
  if (e.button === 0) mouseLeftDown = true;
  if (e.button === 2) {
    mouseRightDown = true;
    triggerFireRocket();
  }
});
window.addEventListener('mouseup', (e) => {
  if (e.button === 0) mouseLeftDown = false;
  if (e.button === 2) mouseRightDown = false;
});
window.addEventListener('contextmenu', (e) => e.preventDefault());

// Mobile Touch Wire-up
function bindTouch(id, onStart, onEnd) {
  const el = document.getElementById(id);
  if (!el) return;
  el.addEventListener('touchstart', (e) => { e.preventDefault(); onStart(); }, { passive: false });
  el.addEventListener('touchend', (e) => { e.preventDefault(); onEnd(); }, { passive: false });
}
bindTouch('btn-gas', () => { keys['KeyW'] = true; }, () => { keys['KeyW'] = false; });
bindTouch('btn-brake', () => { keys['KeyS'] = true; }, () => { keys['KeyS'] = false; });
bindTouch('dpad-left', () => { keys['KeyA'] = true; }, () => { keys['KeyA'] = false; });
bindTouch('dpad-right', () => { keys['KeyD'] = true; }, () => { keys['KeyD'] = false; });
bindTouch('btn-fire', () => { mouseLeftDown = true; }, () => { mouseLeftDown = false; });
bindTouch('btn-rocket', () => { triggerFireRocket(); }, () => {});
bindTouch('btn-mine', () => { triggerDropMine(); }, () => {});
bindTouch('btn-nitro', () => { keys['ShiftLeft'] = true; }, () => { keys['ShiftLeft'] = false; });

function triggerFireRocket() {
  if (raceState !== "RACING" || !playerCar.weapons.canFireRoof()) return;
  combatManager.launchRocket(playerCar, playerCar.weapons.roofWeapon, playerCar.weapons.currentTarget);
  playerCar.weapons.roofAmmo--;
  playerCar.weapons.roofCooldown = 1.0 / playerCar.weapons.roofWeapon.fireRate;
}

function triggerDropMine() {
  if (raceState !== "RACING" || !playerCar.weapons.canFireRear()) return;
  combatManager.dropMine(playerCar, playerCar.weapons.rearWeapon);
  playerCar.weapons.rearAmmo--;
  playerCar.weapons.rearCooldown = 1.5;
}

// Camera Modes
let cameraMode = 0; // 0 = Chase, 1 = Cockpit, 2 = Tactical

function updateCamera(dt) {
  if (cameraMode === 0) {
    const speedNorm = Math.min(1.0, playerCar.speedKmh / 200.0);
    camera.fov = 68.0 + speedNorm * 14.0 + (playerCar.nitroActive ? 10.0 : 0.0);
    camera.updateProjectionMatrix();
    const forward = new THREE.Vector3(0, 0, -1).applyQuaternion(playerCar.quaternion);
    const targetPos = playerCar.position.clone().sub(forward.multiplyScalar(5.8 + speedNorm * 1.5)).add(new THREE.Vector3(0, 2.2 + speedNorm * 0.6, 0));
    camera.position.lerp(targetPos, dt * 10.0);
    camera.lookAt(playerCar.position.clone().add(new THREE.Vector3(0, 0.8, 0)));
  } else if (cameraMode === 1) {
    camera.fov = 75.0;
    camera.updateProjectionMatrix();
    const eyeOffset = new THREE.Vector3(-0.35, 0.85, -0.2).applyQuaternion(playerCar.quaternion);
    camera.position.copy(playerCar.position.clone().add(eyeOffset));
    const forward = new THREE.Vector3(0, 0, -1).applyQuaternion(playerCar.quaternion);
    camera.lookAt(camera.position.clone().add(forward.multiplyScalar(10)));
  } else {
    camera.fov = 55.0;
    camera.updateProjectionMatrix();
    const lead = playerCar.velocity.clone().multiplyScalar(0.35);
    camera.position.lerp(playerCar.position.clone().add(lead).add(new THREE.Vector3(0, 22, 12)), dt * 8.0);
    camera.lookAt(playerCar.position.clone().add(lead));
  }
}

// Main Animation & 120Hz Loop
let lastTime = performance.now();
let physicsAccumulator = 0;
const fixedTimeStep = 1.0 / 120.0;

function animate(currentTime) {
  requestAnimationFrame(animate);

  const delta = Math.min(0.1, (currentTime - lastTime) / 1000.0);
  lastTime = currentTime;

  // Process Countdown & Inputs
  if (raceState === "COUNTDOWN") {
    countdownTimer -= delta;
    playerCar.throttleInput = 0;
    playerCar.brakeInput = 1.0;
    const banner = document.getElementById('countdown-banner');
    banner.style.display = 'block';

    if (countdownTimer > 3.0) banner.innerText = "3";
    else if (countdownTimer > 2.0) banner.innerText = "2";
    else if (countdownTimer > 1.0) banner.innerText = "1";
    else if (countdownTimer > 0.0) { banner.innerText = "GO!"; banner.style.color = "#00ff66"; }
    else {
      raceState = "RACING";
      banner.style.display = 'none';
      playerCar.brakeInput = 0;
    }
  } else if (raceState === "RACING") {
    raceTime += delta;
    currentLapTime += delta;

    playerCar.throttleInput = THREE.MathUtils.lerp(playerCar.throttleInput, (keys['KeyW'] || keys['ArrowUp']) ? 1.0 : 0.0, delta * 6.0);
    playerCar.brakeInput = THREE.MathUtils.lerp(playerCar.brakeInput, (keys['KeyS'] || keys['ArrowDown']) ? 1.0 : 0.0, delta * 8.0);
    playerCar.steerInput = THREE.MathUtils.lerp(playerCar.steerInput, ((keys['KeyA'] || keys['ArrowLeft']) ? 1.0 : 0.0) - ((keys['KeyD'] || keys['ArrowRight']) ? 1.0 : 0.0), delta * 6.0);
    playerCar.handbrake = !!keys['Space'];

    if (keys['ShiftLeft'] && playerCar.nitroAmount > 0) {
      playerCar.nitroActive = true;
      playerCar.nitroAmount = Math.max(0, playerCar.nitroAmount - delta * 25);
    } else {
      playerCar.nitroActive = false;
      playerCar.nitroAmount = Math.min(100, playerCar.nitroAmount + delta * 6);
    }

    // Player Weapon Firing
    playerCar.weapons.update(delta, allCars);
    if ((mouseLeftDown || keys['KeyJ'] || keys['KeyF']) && playerCar.weapons.canFirePrimary()) {
      combatManager.fireBullets(playerCar, playerCar.weapons.primaryWeapon, playerCar.weapons.currentTarget);
      playerCar.weapons.primaryCooldown = 1.0 / playerCar.weapons.primaryWeapon.fireRate;
    }

    // AI Control & Combat updates
    for (let ai of aiCars) updateAI(ai, delta, allCars, combatManager);
  }

  // 120 Hz Fixed Timestep Physics Accumulator
  physicsAccumulator += delta;
  let steps = 0;
  while (physicsAccumulator >= fixedTimeStep && steps < 5) {
    for (let c of allCars) {
      // Wrecked vehicle respawn check
      if (c.isWrecked && c.respawnTimer <= 0) {
        const prog = carProgress.get(c);
        const spawnGate = checkpointGates[prog ? prog.nextGate : 0];
        const nextGate = checkpointGates[((prog ? prog.nextGate : 0) + 1) % numCheckpoints];
        const fwd = nextGate.clone().sub(spawnGate).normalize();
        const quat = new THREE.Quaternion().setFromUnitVectors(new THREE.Vector3(0, 0, -1), fwd);
        c.respawn(spawnGate.clone().add(new THREE.Vector3(0, 0.8, 0)), quat);
      }
      c.physicsStep(fixedTimeStep);
    }
    physicsAccumulator -= fixedTimeStep;
    steps++;
  }

  // Update Combat Systems & Pickups
  combatManager.update(delta, allCars);
  pickupManager.update(delta, allCars);
  bossController.update(delta, playerCar, combatManager);

  // Checkpoint & Leaderboard Progression
  if (raceState === "RACING") {
    for (let c of allCars) {
      const prog = carProgress.get(c);
      if (prog.isFinished) continue;

      prog.lapTimer += delta;
      const targetGate = checkpointGates[prog.nextGate];
      if (c.position.distanceTo(targetGate) < 14.0) {
        prog.nextGate = (prog.nextGate + 1) % numCheckpoints;
        if (prog.nextGate === 1) { // Lap completed
          if (c === playerCar) {
            bestLapTime = Math.min(bestLapTime, currentLapTime);
            currentLapTime = 0;
          }
          if (prog.lap >= totalLaps) {
            prog.isFinished = true;
            if (c === playerCar) finishRace();
          } else {
            prog.lap++;
          }
        }
      }
      prog.score = (prog.lap * 10000.0) + (prog.nextGate * 100.0) - c.position.distanceTo(checkpointGates[prog.nextGate]);
    }

    allCars.sort((a, b) => carProgress.get(b).score - carProgress.get(a).score);
  }

  // Turntable & Garage Update
  garage.update(delta);

  // Audio Update
  let maxSlip = 0;
  for (let w of playerCar.wheels) maxSlip = Math.max(maxSlip, Math.abs(w.slipAngle) + Math.abs(w.slipRatio));
  audio.update(playerCar.engineRPM, playerCar.throttleInput, playerCar.turboBoost, maxSlip);

  // Camera & Lights
  updateCamera(delta);
  sunLight.position.set(playerCar.position.x - 60, 80, playerCar.position.z - 60);
  sunLight.target = playerCar.meshGroup;

  // UI & HUD Update
  updateHUD(playerCar, allCars, carProgress, currentLapTime, bestLapTime, totalLaps, camera);

  renderer.render(scene, camera);
}

function finishRace() {
  raceState = "FINISHED";
  const modal = document.getElementById('results-modal');
  modal.style.display = 'block';

  let html = "";
  for (let i = 0; i < allCars.length; i++) {
    const c = allCars[i];
    const isP = c === playerCar;
    html += `<div><strong>${i + 1}.</strong> ${isP ? '<span style="color:#ff8800;">YOU (Sprinter R2)</span>' : c.driverName} ${c.isWrecked ? '<span style="color:#ff3300;">[WRECKED]</span>' : ''}</div>`;
  }
  document.getElementById('results-standings').innerHTML = html;
}

// Window resize
window.addEventListener('resize', () => {
  camera.aspect = window.innerWidth / window.innerHeight;
  camera.updateProjectionMatrix();
  renderer.setSize(window.innerWidth, window.innerHeight);
});

// Boot Unlocker
document.getElementById('boot-screen').addEventListener('click', () => {
  audio.init();
  document.getElementById('boot-screen').style.opacity = '0';
  setTimeout(() => {
    document.getElementById('boot-screen').style.display = 'none';
    garage.openGarageUI();
  }, 400);
});

requestAnimationFrame(animate);
