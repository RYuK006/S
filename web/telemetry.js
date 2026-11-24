// web/telemetry.js
// F3 Telemetry HUD & Dynamic Resolution Scaling (DRS)

class TelemetryController {
  constructor(renderer, playerCar, combatMgr) {
    this.renderer = renderer;
    this.playerCar = playerCar;
    this.combatMgr = combatMgr;
    this.isVisible = false;

    this.frameCount = 0;
    this.lastFpsUpdate = performance.now();
    this.currentFps = 60;
    this.frameTimeMs = 16.6;
    this.renderScale = 1.0;
    this.basePixelRatio = Math.min(window.devicePixelRatio || 1, 2);

    this.overlay = document.createElement('div');
    this.overlay.id = 'telemetry-overlay';
    this.overlay.style.cssText = "position:absolute; top:20px; left:24px; background:rgba(8,10,14,0.92); border:1px solid #00f0ff; border-radius:4px; padding:12px 18px; font-family:monospace; font-size:12px; color:#00f0ff; z-index:200; display:none; pointer-events:none; line-height:1.6; text-shadow:0 1px 2px #000;";
    document.body.appendChild(this.overlay);
  }

  toggle() {
    this.isVisible = !this.isVisible;
    this.overlay.style.display = this.isVisible ? 'block' : 'none';
  }

  update(dt) {
    this.frameCount++;
    const now = performance.now();
    this.frameTimeMs = dt * 1000.0;

    if (now - this.lastFpsUpdate >= 1000) {
      this.currentFps = Math.round((this.frameCount * 1000) / (now - this.lastFpsUpdate));
      this.frameCount = 0;
      this.lastFpsUpdate = now;

      // Automatic Dynamic Resolution Scaling (DRS)
      if (this.currentFps < 50 && this.renderScale > 0.60) {
        this.renderScale = Math.max(0.60, this.renderScale - 0.05);
        this.renderer.setPixelRatio(this.basePixelRatio * this.renderScale);
      } else if (this.currentFps > 58 && this.renderScale < 1.0) {
        this.renderScale = Math.min(1.0, this.renderScale + 0.05);
        this.renderer.setPixelRatio(this.basePixelRatio * this.renderScale);
      }
    }

    if (this.isVisible && this.playerCar) {
      const p = this.playerCar;
      const numProj = this.combatMgr ? this.combatMgr.projectiles.length : 0;
      const numMines = this.combatMgr ? this.combatMgr.mines.length : 0;

      this.overlay.innerHTML = `
        <strong style="color:#ffaa00;">GRIDLETHAL TELEMETRY (F3)</strong><br>
        FPS: <span style="color:${this.currentFps < 50 ? '#ff3300' : '#00ff88'};">${this.currentFps}</span> (${this.frameTimeMs.toFixed(1)} ms)<br>
        DRS Scale: ${(this.renderScale * 100).toFixed(0)}% (Pixel Ratio: ${(this.basePixelRatio * this.renderScale).toFixed(2)})<br>
        Speed: ${Math.round(p.speedKmh)} km/h | Gear: ${p.currentGear}<br>
        RPM: ${Math.round(p.engineRPM)} / 7200 | Boost: ${(p.turboBoost * 100).toFixed(0)}%<br>
        Armour: ${Math.round(p.health)} / ${p.maxHealth} HP<br>
        Active Projectiles: ${numProj} | Active Mines: ${numMines}<br>
        Physics Step: 120 Hz Sub-stepped (Fixed 8.33ms)
      `;
    }
  }
}
