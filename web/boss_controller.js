// web/boss_controller.js
// Multi-Phase Boss Duel Encounter Controller & Boss Health UI

class BossController {
  constructor(scene) {
    this.scene = scene;
    this.bossCar = null;
    this.bossName = "";
    this.maxHealth = 3000.0;
    this.currentHealth = 3000.0;
    this.currentPhase = 1;
    this.totalPhases = 3;
    this.isActive = false;

    // Create Boss HUD Element
    this.container = document.createElement('div');
    this.container.id = 'boss-hud';
    this.container.style.cssText = "position:absolute; top:24px; left:50%; transform:translateX(-50%); width:460px; display:none; flex-direction:column; align-items:center; z-index:45; text-shadow:0 2px 4px #000;";
    this.container.innerHTML = `
      <div id="boss-name" style="font-size:18px; font-weight:900; color:#ff3300; letter-spacing:2px; text-transform:uppercase;">BOSS: THE HAULER</div>
      <div id="boss-phase" style="font-size:12px; color:#ffaa00; font-weight:bold; margin-bottom:4px;">PHASE 1 / 3</div>
      <div style="width:100%; height:14px; background:rgba(0,0,0,0.7); border:2px solid #ff3300; border-radius:4px; overflow:hidden;">
        <div id="boss-hp-fill" style="width:100%; height:100%; background:linear-gradient(90deg, #ff0000, #ff8800); transition:width 0.1s;"></div>
      </div>
    `;
    document.body.appendChild(this.container);
  }

  startBossEncounter(bossCar, name, hp, phases = 3) {
    this.bossCar = bossCar;
    this.bossName = name;
    this.maxHealth = hp;
    this.currentHealth = hp;
    this.currentPhase = 1;
    this.totalPhases = phases;
    this.isActive = true;

    bossCar.health = hp;
    bossCar.maxHealth = hp;
    bossCar.driverName = name;

    this.container.style.display = 'flex';
    document.getElementById('boss-name').innerText = name;
    this.updateHUD();

    if (window.addBattleFeed) {
      window.addBattleFeed(`WARNING: ${name} ENTERED THE CIRCUIT!`);
    }
  }

  update(dt, playerCar, combatMgr) {
    if (!this.isActive || !this.bossCar) return;

    this.currentHealth = this.bossCar.health;
    const hpRatio = this.currentHealth / this.maxHealth;

    // Check Phase Transitions
    let targetPhase = 1;
    if (this.totalPhases === 4) {
      if (hpRatio < 0.25) targetPhase = 4;
      else if (hpRatio < 0.50) targetPhase = 3;
      else if (hpRatio < 0.75) targetPhase = 2;
    } else {
      if (hpRatio < 0.33) targetPhase = 3;
      else if (hpRatio < 0.66) targetPhase = 2;
    }

    if (targetPhase > this.currentPhase) {
      this.currentPhase = targetPhase;
      if (window.addBattleFeed) {
        window.addBattleFeed(`${this.bossName} ENRAGED! ENTERING PHASE ${this.currentPhase}!`);
      }
      if (window.audio) window.audio.playExplosion();
    }

    this.updateHUD();

    if (this.currentHealth <= 0) {
      this.isActive = false;
      this.container.style.display = 'none';
      if (window.addBattleFeed) {
        window.addBattleFeed(`${this.bossName} DESTROYED! CAMPAIGN BOUNTY CLAIMED!`);
      }
    }
  }

  updateHUD() {
    const pct = Math.max(0, (this.currentHealth / this.maxHealth) * 100);
    const fill = document.getElementById('boss-hp-fill');
    const phaseLabel = document.getElementById('boss-phase');
    if (fill) fill.style.width = `${pct}%`;
    if (phaseLabel) phaseLabel.innerText = `PHASE ${this.currentPhase} / ${this.totalPhases}`;
  }
}
