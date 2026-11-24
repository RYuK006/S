// web/cheat_menu.js
// F4 Debug Cheat Console for Real-Time Testing & Economy Validation

class CheatMenuController {
  constructor(saveManager) {
    this.saveManager = saveManager;
    this.isVisible = false;
    this.godMode = false;
    this.infiniteNitro = false;

    this.menuEl = document.createElement('div');
    this.menuEl.id = 'cheat-menu';
    this.menuEl.style.cssText = "position:absolute; top:70px; left:24px; background:rgba(15,18,24,0.96); border:2px solid #00f0ff; border-radius:8px; padding:18px 24px; z-index:150; display:none; flex-direction:column; gap:10px; box-shadow:0 0 25px rgba(0,240,255,0.4); font-family:sans-serif; color:#fff; min-width:280px;";
    this.menuEl.innerHTML = `
      <div style="display:flex; justify-content:space-between; align-items:center; border-bottom:1px solid #333; padding-bottom:8px;">
        <strong style="color:#00f0ff; font-size:16px; letter-spacing:1px;">F4 DEBUG CHEAT MENU</strong>
        <span style="font-size:11px; color:#888; cursor:pointer;" onclick="window.cheatMenu.toggle()">[ESC/F4]</span>
      </div>
      <button class="btn-sm" onclick="window.cheatMenu.addCash(10000)">+10,000 CASH</button>
      <button class="btn-sm" onclick="window.cheatMenu.addGold(50)">+50 GOLD</button>
      <button class="btn-sm" onclick="window.cheatMenu.addLevel(5)">+5 LEVELS</button>
      <button class="btn-sm" onclick="window.cheatMenu.unlockAllCars()">UNLOCK ALL 12 CARS</button>
      <button class="btn-sm" onclick="window.cheatMenu.unlockAllWeapons()">UNLOCK ALL 26 WEAPONS</button>
      <button class="btn-sm" id="btn-cheat-god" onclick="window.cheatMenu.toggleGodMode()">GOD MODE: OFF</button>
      <button class="btn-sm" id="btn-cheat-nitro" onclick="window.cheatMenu.toggleInfiniteNitro()">INFINITE NITRO: OFF</button>
      <button class="btn-sm buy" onclick="window.cheatMenu.wreckAllRivals()">INSTANT WRECK RIVALS</button>
      <button class="btn-sm" style="background:#551111;" onclick="window.cheatMenu.resetSave()">RESET SAVE TO DEFAULT</button>
    `;
    document.body.appendChild(this.menuEl);
  }

  toggle() {
    this.isVisible = !this.isVisible;
    this.menuEl.style.display = this.isVisible ? 'flex' : 'none';
  }

  addCash(amt) {
    this.saveManager.state.cash = (this.saveManager.state.cash || 0) + amt;
    this.saveManager.saveSlot();
    if (window.garage) window.garage.renderHeader();
    if (window.addBattleFeed) window.addBattleFeed(`CHEAT: +$${amt.toLocaleString()} CASH ADDED`);
  }

  addGold(amt) {
    this.saveManager.state.gold = (this.saveManager.state.gold || 0) + amt;
    this.saveManager.saveSlot();
    if (window.garage) window.garage.renderHeader();
    if (window.addBattleFeed) window.addBattleFeed(`CHEAT: +${amt} GOLD ADDED`);
  }

  addLevel(lvls) {
    this.saveManager.state.player_level = Math.min(100, (this.saveManager.state.player_level || 1) + lvls);
    this.saveManager.saveSlot();
    if (window.garage) window.garage.renderHeader();
    if (window.addBattleFeed) window.addBattleFeed(`CHEAT: LEVEL INCREASED TO ${this.saveManager.state.player_level}`);
  }

  unlockAllCars() {
    for (let carId of Object.keys(CAR_RECIPES)) {
      if (!this.saveManager.state.owned_cars[carId]) {
        this.saveManager.buyCar(carId);
      }
    }
    if (window.garage) {
      window.garage.renderHeader();
      window.garage.renderTab(window.garage.activeTab);
    }
    if (window.addBattleFeed) window.addBattleFeed("CHEAT: ALL 12 CARS UNLOCKED");
  }

  unlockAllWeapons() {
    this.saveManager.state.unlocked_weapons = Object.keys(WEAPONS);
    this.saveManager.saveSlot();
    if (window.addBattleFeed) window.addBattleFeed("CHEAT: ALL 26 WEAPONS UNLOCKED");
  }

  toggleGodMode() {
    this.godMode = !this.godMode;
    const btn = document.getElementById('btn-cheat-god');
    if (btn) btn.innerText = `GOD MODE: ${this.godMode ? 'ON' : 'OFF'}`;
    btn.style.borderColor = this.godMode ? '#00ff66' : '#444';
    if (window.playerCar) {
      window.playerCar.invulnerableTimer = this.godMode ? 999999 : 0;
    }
  }

  toggleInfiniteNitro() {
    this.infiniteNitro = !this.infiniteNitro;
    const btn = document.getElementById('btn-cheat-nitro');
    if (btn) btn.innerText = `INFINITE NITRO: ${this.infiniteNitro ? 'ON' : 'OFF'}`;
    btn.style.borderColor = this.infiniteNitro ? '#00ff66' : '#444';
  }

  wreckAllRivals() {
    if (window.aiCars) {
      for (let ai of window.aiCars) {
        ai.car.applyDamage(99999);
      }
    }
    if (window.addBattleFeed) window.addBattleFeed("CHEAT: ALL RIVALS WRECKED");
  }

  resetSave() {
    if (confirm("Reset current save profile to defaults?")) {
      this.saveManager.state = this.saveManager.getDefaultState();
      this.saveManager.saveSlot();
      location.reload();
    }
  }
}
