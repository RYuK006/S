// web/garage.js
// 3D Garage Hub Controller, Turntable Visuals, Customization & Economy UI

class GarageController {
  constructor(scene, saveManager) {
    this.scene = scene;
    this.saveManager = saveManager;
    this.activeTab = "showroom";
    this.previewCarId = this.saveManager.state.selected_car;

    // Turntable platform mesh
    this.turntableGroup = new THREE.Group();
    const ttGeo = new THREE.CylinderGeometry(4.2, 4.4, 0.35, 32);
    const ttMat = new THREE.MeshStandardMaterial({ color: 0x22242a, metalness: 0.85, roughness: 0.25 });
    const ttMesh = new THREE.Mesh(ttGeo, ttMat);
    ttMesh.position.y = -0.175;
    ttMesh.receiveShadow = true;
    this.turntableGroup.add(ttMesh);

    // Neon edge ring
    const ringGeo = new THREE.TorusGeometry(4.3, 0.05, 8, 32).rotateX(Math.PI / 2);
    const ringMat = new THREE.MeshBasicMaterial({ color: 0xff6600 });
    const ringMesh = new THREE.Mesh(ringGeo, ringMat);
    ringMesh.position.y = 0.02;
    this.turntableGroup.add(ringMesh);

    this.scene.add(this.turntableGroup);
    this.turntableAngle = 0;
  }

  update(dt) {
    this.turntableAngle += dt * 0.4;
    this.turntableGroup.rotation.y = this.turntableAngle;
  }

  openGarageUI() {
    const el = document.getElementById('garage-modal');
    if (!el) return;
    el.style.display = 'flex';
    this.renderHeader();
    this.renderTab(this.activeTab);
  }

  closeGarageUI() {
    const el = document.getElementById('garage-modal');
    if (el) el.style.display = 'none';
  }

  renderHeader() {
    const s = this.saveManager.state;
    const stats = computeCarStats(s.selected_car, (s.owned_cars[s.selected_car] || {}).upgrades || {});

    document.getElementById('garage-cash').innerText = `$${s.cash.toLocaleString()}`;
    document.getElementById('garage-gold').innerText = `${s.gold} GOLD`;
    document.getElementById('garage-car-name').innerText = (CAR_RECIPES[s.selected_car] || {}).name || "Sprinter R2";
    document.getElementById('garage-class-badge').innerText = `CLASS ${stats.class_rating}`;
  }

  setTab(tab) {
    this.activeTab = tab;
    document.querySelectorAll('.g-tab-btn').forEach(btn => {
      btn.classList.toggle('active', btn.dataset.tab === tab);
    });
    this.renderTab(tab);
  }

  renderTab(tab) {
    const content = document.getElementById('garage-tab-content');
    if (!content) return;
    content.innerHTML = "";

    if (tab === "campaign") {
      this.renderCampaign(content);
    } else if (tab === "showroom") {
      this.renderShowroom(content);
    } else if (tab === "upgrades") {
      this.renderUpgrades(content);
    } else if (tab === "customise") {
      this.renderCustomise(content);
    } else if (tab === "weapons") {
      this.renderWeapons(content);
    } else if (tab === "driver") {
      this.renderDriver(content);
    } else if (tab === "profile") {
      this.renderProfile(content);
    } else if (tab === "achievements") {
      this.renderAchievements(content);
    } else if (tab === "multiplayer") {
      this.renderMultiplayer(content);
    }
  }

  renderMultiplayer(container) {
    const net = window.netManager;
    const peerId = net ? net.peerId : "OFFLINE";
    const peerCount = net ? net.connectedPeers.size : 0;
    const wsConnected = net && net.ws && net.ws.readyState === WebSocket.OPEN;

    container.innerHTML = `
      <div style="background:#131720; border:1px solid #2a3242; border-radius:6px; padding:18px; max-width:600px; margin:0 auto;">
        <div style="display:flex; justify-content:space-between; align-items:center; border-bottom:1px solid #333; padding-bottom:10px; margin-bottom:14px;">
          <strong style="color:#00e5ff; font-size:18px; letter-spacing:1px;">MULTIPLAYER LOBBY</strong>
          <span class="g-badge" style="background:#00cc66;">NETWORK ACTIVE</span>
        </div>
        <div style="font-size:13px; color:#ccc; line-height:1.8;">
          <div><strong>PILOT CALLSIGN:</strong> <span style="color:#ffaa00; font-family:monospace;">${peerId}</span></div>
          <div><strong>LOCAL MULTI-TAB SYNC:</strong> <span style="color:#00ff88;">BROADCASTCHANNEL ACTIVE</span></div>
          <div><strong>CONNECTED PEERS:</strong> <span style="color:#00e5ff; font-weight:bold;">${peerCount} Pilots in Circuit</span></div>
          <div><strong>DEDICATED RELAY SERVER:</strong> <span style="color:${wsConnected ? '#00ff88' : '#ffaa00'};">${wsConnected ? 'CONNECTED (ws://localhost:8080)' : 'STANDALONE READY (node gridlethal-server.js)'}</span></div>
        </div>
        <div style="margin-top:16px; background:#181e28; border:1px solid #333; border-radius:4px; padding:12px; font-size:12px; color:#aaa;">
          <strong style="color:#ff8800;">HOW TO PLAY LOCAL MULTI-TAB MULTIPLAYER:</strong>
          <p style="margin-top:4px;">1. Open a second tab or separate browser window with <code>index.html</code>.</p>
          <p>2. Both tabs automatically connect via 24-byte binary snapshots over <code>BroadcastChannel</code> with zero server setup!</p>
          <p>3. Drive, drift, and fire weapons in either window—both cars synchronize and damage each other in real-time.</p>
        </div>
        <button class="btn-restart" style="width:100%; margin-top:16px;" onclick="window.garage.closeGarageUI()">ENTER MULTIPLAYER CIRCUIT ▶</button>
      </div>
    `;
  }

  renderAchievements(container) {
    const s = this.saveManager.state;
    const unlocked = s.achievements || [];
    let html = `
      <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:14px; border-bottom:1px solid #333; padding-bottom:8px;">
        <strong style="color:#ff8800; font-size:16px;">CAREER ACHIEVEMENTS</strong>
        <span class="g-badge" style="background:#00cc66;">${unlocked.length} / 60 UNLOCKED</span>
      </div>
      <div style="display:grid; grid-template-columns:repeat(auto-fill, minmax(260px, 1fr)); gap:10px;">
    `;

    for (let ach of ACHIEVEMENTS_DATA) {
      const isUnl = unlocked.includes(ach.id);
      html += `
        <div style="background:#141822; border:1px solid ${isUnl ? '#00e5ff' : '#222'}; border-radius:4px; padding:10px; opacity:${isUnl ? '1.0' : '0.5'};">
          <div style="display:flex; justify-content:space-between;">
            <strong style="color:${isUnl ? '#fff' : '#888'}; font-size:13px;">${ach.name}</strong>
            <span style="font-size:10px; color:#ffaa00; text-transform:uppercase;">${ach.cat}</span>
          </div>
          <p style="font-size:11px; color:#aaa; margin-top:4px;">${ach.desc}</p>
        </div>
      `;
    }
    html += `</div>`;
    container.innerHTML = html;
  }

  renderCampaign(container) {
    const s = this.saveManager.state;
    let html = `<div style="display:flex; flex-direction:column; gap:16px;">`;

    for (let bKey of Object.keys(BIOMES)) {
      const bio = BIOMES[bKey];
      const bRaces = CAMPAIGN_RACES.filter(r => r.region === bKey);

      html += `
        <div style="background:#131720; border:1px solid #2a3242; border-radius:6px; padding:14px;">
          <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:10px; border-bottom:1px solid #333; padding-bottom:6px;">
            <div>
              <strong style="font-size:16px; color:#ff8800; letter-spacing:1px; text-transform:uppercase;">${bio.name}</strong>
              <span style="font-size:12px; color:#889; margin-left:8px;">${bio.theme}</span>
            </div>
            <span class="g-badge" style="background:#0099ff;">GRIP x${bio.surfaceGrip}</span>
          </div>
          <div style="display:grid; grid-template-columns:repeat(auto-fill, minmax(280px, 1fr)); gap:10px;">
      `;

      for (let r of bRaces) {
        const isLocked = (s.player_level || 1) < r.level_req;
        const isBoss = r.mode === "boss_duel";
        html += `
          <div style="background:#181e28; border:1px solid ${isBoss ? '#ff3300' : '#222'}; border-radius:4px; padding:10px; opacity:${isLocked ? '0.6' : '1.0'};">
            <div style="display:flex; justify-content:space-between;">
              <strong>#${r.id} ${r.name}</strong>
              <span style="font-size:10px; color:#ffaa00; text-transform:uppercase; font-weight:bold;">${r.mode}</span>
            </div>
            <div style="font-size:11px; color:#aaa; margin:6px 0;">
              Laps: ${r.laps} | Rivals: ${r.cars} | Weather: ${r.weather}
            </div>
            <div style="display:flex; justify-content:space-between; align-items:center; margin-top:8px;">
              <span style="font-size:11px; color:#00ff88; font-weight:bold;">+$${r.reward_cash.toLocaleString()}</span>
              ${isLocked ? `<span style="font-size:10px; color:#ff4444;">LVL ${r.level_req} REQ</span>` :
                `<button class="btn-sm buy" onclick="window.garage.launchCampaignRace(${r.id})">LAUNCH EVENT ▶</button>`}
            </div>
          </div>
        `;
      }
      html += `</div></div>`;
    }
    html += `</div>`;
    container.innerHTML = html;
  }

  launchCampaignRace(raceId) {
    const race = CAMPAIGN_RACES.find(r => r.id === raceId);
    if (!race) return;
    this.closeGarageUI();
    if (window.startCampaignRace) window.startCampaignRace(race);
  }

  renderShowroom(container) {
    const s = this.saveManager.state;
    let html = `<div class="g-car-grid">`;

    for (let carId of Object.keys(CAR_RECIPES)) {
      const car = CAR_RECIPES[carId];
      const isOwned = !!s.owned_cars[carId];
      const isSelected = s.selected_car === carId;
      const stats = computeCarStats(carId, (s.owned_cars[carId] || {}).upgrades || {});

      html += `
        <div class="g-car-card ${isSelected ? 'selected' : ''}">
          <div class="g-card-header">
            <strong>${car.name}</strong>
            <span class="g-badge">${car.class}</span>
          </div>
          <div class="g-stats-mini">
            <div>PWR: ${stats.power_kw} kW</div>
            <div>TOP: ${stats.top_speed} km/h</div>
            <div>ARMOUR: ${stats.health}</div>
            <div>MASS: ${stats.mass} kg</div>
          </div>
          <div class="g-perk-text"><em>Perk: ${car.perk}</em></div>
          <div class="g-action-bar">
            ${isSelected ? '<button class="btn-sm active">ACTIVE</button>' :
              isOwned ? `<button class="btn-sm" onclick="window.garage.selectCar('${carId}')">SELECT</button>` :
              `<button class="btn-sm buy" onclick="window.garage.buyCar('${carId}')">BUY $${car.price.toLocaleString()}</button>`}
          </div>
        </div>
      `;
    }
    html += `</div>`;
    container.innerHTML = html;
  }

  renderUpgrades(container) {
    const s = this.saveManager.state;
    const carId = s.selected_car;
    const carData = CAR_RECIPES[carId];
    const carSave = s.owned_cars[carId] || { upgrades: {} };

    let html = `<div class="g-upgrades-list">`;
    for (let catId of Object.keys(UPGRADE_CATEGORIES)) {
      const cat = UPGRADE_CATEGORIES[catId];
      const tier = carSave.upgrades[catId] || 0;
      const nextTier = tier + 1;
      const cost = calculateUpgradeCost(carData.price, catId, nextTier);
      const isMax = tier >= 5;

      html += `
        <div class="g-upgrade-row">
          <div class="g-upg-info">
            <strong>${cat.name}</strong> <span class="g-tier-tag">TIER ${tier} / 5</span>
            <div class="g-upg-desc">${cat.desc}</div>
          </div>
          <div class="g-upg-action">
            ${isMax ? '<span class="max-badge">MAXED</span>' :
              `<button class="btn-sm buy" onclick="window.garage.buyUpgrade('${catId}')">UPGRADE TIER ${nextTier} ($${cost.toLocaleString()})</button>`}
          </div>
        </div>
      `;
    }
    html += `</div>`;
    container.innerHTML = html;
  }

  renderCustomise(container) {
    const s = this.saveManager.state;
    const carSave = s.owned_cars[s.selected_car];
    const currentColor = carSave.paint_color || "#ee1808";

    container.innerHTML = `
      <div class="g-customise-panel">
        <h3>VEHICLE PAINT & FINISH</h3>
        <div class="g-color-row">
          <label>Primary Paint:</label>
          <input type="color" id="paint-picker" value="${currentColor}" onchange="window.garage.updatePaint(this.value)">
        </div>
        <div class="g-finish-row">
          <label>Finish Quality:</label>
          <select id="finish-select" onchange="window.garage.updateFinish(this.value)">
            <option value="gloss" ${carSave.finish==='gloss'?'selected':''}>High Gloss</option>
            <option value="metallic" ${carSave.finish==='metallic'?'selected':''}>Metallic Clearcoat</option>
            <option value="pearl" ${carSave.finish==='pearl'?'selected':''}>Pearlescent Shift</option>
            <option value="matte" ${carSave.finish==='matte'?'selected':''}>Matte Tactical</option>
            <option value="chrome" ${carSave.finish==='chrome'?'selected':''}>Mirrored Chrome</option>
            <option value="primer" ${carSave.finish==='primer'?'selected':''}>Rusty Primer</option>
          </select>
        </div>
      </div>
    `;
  }

  renderWeapons(container) {
    const s = this.saveManager.state;
    const carSave = s.owned_cars[s.selected_car];
    const equipped = carSave.equipped_weapons || {};

    let html = `<div class="g-weapons-bay">`;
    html += `<h3>EQUIPPED WEAPON SLOTS</h3>`;
    for (let slot of ['primary', 'roof', 'rear', 'passive']) {
      const wepId = equipped[slot];
      const wep = WEAPONS[wepId] || { name: "Empty Slot", description: "No weapon equipped" };
      html += `
        <div class="g-weapon-slot-row">
          <div class="w-slot-label">${slot.toUpperCase()}</div>
          <div class="w-slot-details">
            <strong>${wep.name}</strong>
            <p>${wep.description}</p>
          </div>
        </div>
      `;
    }
    html += `</div>`;
    container.innerHTML = html;
  }

  renderDriver(container) {
    const s = this.saveManager.state;
    let html = `<div class="g-driver-grid">`;
    for (let dId of Object.keys(DRIVERS)) {
      const drv = DRIVERS[dId];
      const isSel = s.selected_driver === dId;
      html += `
        <div class="g-driver-card ${isSel ? 'selected' : ''}">
          <div class="d-avatar">${drv.name[0]}</div>
          <strong>${drv.name}</strong>
          <div class="d-title">${drv.title}</div>
          <div class="d-perk">${drv.perk}</div>
          <button class="btn-sm ${isSel ? 'active' : ''}" onclick="window.garage.selectDriver('${dId}')">
            ${isSel ? 'SELECTED' : 'HIRE / SELECT'}
          </button>
        </div>
      `;
    }
    html += `</div>`;
    container.innerHTML = html;
  }

  renderProfile(container) {
    const s = this.saveManager.state;
    const b64 = this.saveManager.exportBase64();

    container.innerHTML = `
      <div class="g-profile-panel">
        <h3>PROFILE & SAVE SLOTS</h3>
        <div class="g-slot-buttons">
          <button class="btn-sm ${this.saveManager.currentSlot===1?'active':''}" onclick="window.garage.switchSlot(1)">Slot 1</button>
          <button class="btn-sm ${this.saveManager.currentSlot===2?'active':''}" onclick="window.garage.switchSlot(2)">Slot 2</button>
          <button class="btn-sm ${this.saveManager.currentSlot===3?'active':''}" onclick="window.garage.switchSlot(3)">Slot 3</button>
        </div>
        <h4 style="margin-top:16px;">EXPORT SAVE CODE:</h4>
        <textarea readonly style="width:100%; height:60px; background:#111; color:#0f0; font-family:monospace; font-size:11px;">${b64}</textarea>
        <h4 style="margin-top:14px;">IMPORT SAVE CODE:</h4>
        <div style="display:flex; gap:8px;">
          <input type="text" id="import-code-box" placeholder="Paste base64 save code here..." style="flex:1; background:#111; color:#fff; border:1px solid #444; padding:6px;">
          <button class="btn-sm buy" onclick="window.garage.importSave()">IMPORT</button>
        </div>
      </div>
    `;
  }

  buyCar(carId) {
    if (this.saveManager.buyCar(carId)) {
      this.renderHeader();
      this.renderTab(this.activeTab);
      if (window.addBattleFeed) window.addBattleFeed(`PURCHASED ${CAR_RECIPES[carId].name}!`);
    } else {
      alert("Insufficient Cash or Level Locked!");
    }
  }

  selectCar(carId) {
    if (this.saveManager.selectCar(carId)) {
      this.renderHeader();
      this.renderTab(this.activeTab);
    }
  }

  buyUpgrade(category) {
    if (this.saveManager.buyUpgrade(this.saveManager.state.selected_car, category)) {
      this.renderHeader();
      this.renderTab(this.activeTab);
    } else {
      alert("Insufficient Funds or Max Tier Reached!");
    }
  }

  selectDriver(driverId) {
    if (this.saveManager.selectDriver(driverId)) {
      this.renderHeader();
      this.renderTab(this.activeTab);
    }
  }

  updatePaint(colorHex) {
    const s = this.saveManager.state;
    s.owned_cars[s.selected_car].paint_color = colorHex;
    this.saveManager.saveSlot();
  }

  updateFinish(finish) {
    const s = this.saveManager.state;
    s.owned_cars[s.selected_car].finish = finish;
    this.saveManager.saveSlot();
  }

  switchSlot(slot) {
    this.saveManager.loadSlot(slot);
    this.renderHeader();
    this.renderTab(this.activeTab);
  }

  importSave() {
    const box = document.getElementById('import-code-box');
    if (box && this.saveManager.importBase64(box.value.trim())) {
      this.renderHeader();
      this.renderTab(this.activeTab);
      alert("Save profile imported successfully!");
    } else {
      alert("Invalid save code!");
    }
  }
}
