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

    if (tab === "showroom") {
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
    }
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
