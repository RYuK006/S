// web/ui.js
// Radar Minimap, 3D Target Reticle, Combat HUD & Battle Announcements

const minimapCanvas = document.getElementById('minimap-canvas');
const mCtx = minimapCanvas.getContext('2d');
const targetReticle = document.getElementById('target-reticle');
const targetDistLabel = document.getElementById('target-dist');
const battleFeed = document.getElementById('battle-feed');

function addBattleFeed(text) {
  const item = document.createElement('div');
  item.className = 'feed-item';
  item.innerText = text;
  battleFeed.appendChild(item);
  setTimeout(() => {
    if (item.parentNode) item.parentNode.removeChild(item);
  }, 3500);
}
window.addBattleFeed = addBattleFeed;

function drawMinimap(allCars, playerCar) {
  mCtx.clearRect(0, 0, 180, 180);
  mCtx.fillStyle = 'rgba(12, 16, 22, 0.9)';
  mCtx.beginPath();
  mCtx.arc(90, 90, 88, 0, Math.PI * 2);
  mCtx.fill();
  mCtx.strokeStyle = 'rgba(255, 120, 0, 0.5)';
  mCtx.lineWidth = 2;
  mCtx.stroke();

  // Draw Spline Loop
  mCtx.strokeStyle = 'rgba(150, 170, 190, 0.45)';
  mCtx.lineWidth = 3;
  mCtx.beginPath();
  const cX = 130, cZ = -70, scale = 0.45;
  for (let i = 0; i < splineSamples.length; i++) {
    let pt = splineSamples[i];
    let sx = 90 + ((pt.x - cX) * scale);
    let sy = 90 + ((pt.z - cZ) * scale);
    if (i === 0) mCtx.moveTo(sx, sy);
    else mCtx.lineTo(sx, sy);
  }
  mCtx.closePath();
  mCtx.stroke();

  // Draw AI Blips
  for (let car of allCars) {
    if (car === playerCar) continue;
    let sx = 90 + ((car.position.x - cX) * scale);
    let sy = 90 + ((car.position.z - cZ) * scale);
    mCtx.fillStyle = car.isWrecked ? '#555555' : '#ff2222';
    mCtx.beginPath();
    mCtx.arc(sx, sy, 3.5, 0, Math.PI * 2);
    mCtx.fill();
  }

  // Draw Player Blip
  let px = 90 + ((playerCar.position.x - cX) * scale);
  let py = 90 + ((playerCar.position.z - cZ) * scale);
  mCtx.fillStyle = '#00f0ff';
  mCtx.beginPath();
  mCtx.arc(px, py, 5.0, 0, Math.PI * 2);
  mCtx.fill();
}

function updateHUD(playerCar, allCars, carProgress, currentLapTime, bestLapTime, totalLaps, camera) {
  const pRank = allCars.indexOf(playerCar) + 1;
  const pProg = carProgress.get(playerCar);

  document.getElementById('pos-badge').innerHTML = `${pRank}<span>${['TH','ST','ND','RD','TH','TH','TH'][pRank]} / 6</span>`;
  document.getElementById('lap-info').innerText = `LAP ${pProg ? pProg.lap : 1} / ${totalLaps}`;
  document.getElementById('time-info').innerText = `TIME: ${fmtTime(currentLapTime)} | BEST: ${bestLapTime < 9000 ? fmtTime(bestLapTime) : '--:--.--'}`;
  document.getElementById('speed-num').innerHTML = `${Math.round(playerCar.speedKmh)}<span id="speed-unit">KM/H</span>`;
  document.getElementById('rpm-gauge').innerText = `GEAR ${playerCar.currentGear} | ${Math.round(playerCar.engineRPM)} RPM`;
  document.getElementById('nitro-fill').style.width = `${playerCar.nitroAmount}%`;

  // Armour Integrities
  const hpPct = Math.max(0, playerCar.health / playerCar.maxHealth) * 100;
  document.getElementById('health-fill').style.width = `${hpPct}%`;
  document.getElementById('health-num').innerText = `${Math.round(playerCar.health)} / ${playerCar.maxHealth}`;

  // Ammo Displays
  document.getElementById('ammo-roof').innerText = `${playerCar.weapons.roofAmmo} / ${playerCar.weapons.roofWeapon.maxAmmo}`;
  document.getElementById('ammo-rear').innerText = `${playerCar.weapons.rearAmmo} / ${playerCar.weapons.rearWeapon.maxAmmo}`;

  // 3D Target Reticle Screen Projection
  const target = playerCar.weapons.currentTarget;
  if (target && !target.isWrecked) {
    const screenPos = target.position.clone().add(new THREE.Vector3(0, 0.6, 0)).project(camera);
    if (screenPos.z < 1.0) {
      const x = (screenPos.x * 0.5 + 0.5) * window.innerWidth;
      const y = (-screenPos.y * 0.5 + 0.5) * window.innerHeight;
      targetReticle.style.display = 'block';
      targetReticle.style.left = `${x}px`;
      targetReticle.style.top = `${y}px`;
      targetDistLabel.innerText = `LOCK ${Math.round(playerCar.weapons.targetDist)}M`;
    } else {
      targetReticle.style.display = 'none';
    }
  } else {
    targetReticle.style.display = 'none';
  }

  drawMinimap(allCars, playerCar);
}

function fmtTime(sec) {
  let m = Math.floor(sec / 60);
  let s = Math.floor(sec) % 60;
  let ms = Math.floor((sec - Math.floor(sec)) * 100);
  return `${m}:${s < 10 ? '0' : ''}${s}.${ms < 10 ? '0' : ''}${ms}`;
}
