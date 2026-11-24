// web/economy.js
// Versioned Save System, In-Memory Fallback, Currency & Economy Transactions

class SaveManager {
  constructor() {
    this.SAVE_KEY = "gridlethal_save";
    this.SAVE_VERSION = 1;
    this.currentSlot = 1;
    this.memorySaves = {};
    this.state = this.loadSlot(1);
  }

  getDefaultState() {
    return {
      save_version: this.SAVE_VERSION,
      player_name: "RYuK006",
      player_level: 1,
      player_xp: 0,
      cash: 25000,
      gold: 50,
      scrap: 150,
      selected_car: "sprinter_r2",
      selected_driver: "hex",
      owned_cars: {
        sprinter_r2: {
          paint_color: "#ee1808",
          finish: "metallic",
          rim_style: "spoke_5",
          upgrades: {
            engine: 0, turbo: 0, transmission: 0, brakes: 0,
            suspension: 0, tyres: 0, armour: 0, nitro: 0,
            cooling: 0, weight_reduction: 0
          },
          equipped_weapons: {
            primary: "twin_mg",
            roof: "rocket_pod",
            rear: "mine_dropper",
            passive: "armour_plating"
          }
        }
      },
      unlocked_weapons: ["twin_mg", "heavy_mg", "rocket_pod", "mine_dropper", "armour_plating"],
      completed_races: [],
      achievements: []
    };
  }

  loadSlot(slot = 1) {
    this.currentSlot = slot;
    try {
      const raw = localStorage.getItem(`${this.SAVE_KEY}_slot${slot}`);
      if (raw) {
        const parsed = JSON.parse(raw);
        if (parsed && typeof parsed === 'object') {
          return this.sanitize(parsed);
        }
      }
    } catch (e) {
      console.warn("localStorage read failed, falling back to memory:", e.message);
    }

    if (this.memorySaves[slot]) return this.memorySaves[slot];
    const def = this.getDefaultState();
    this.memorySaves[slot] = def;
    return def;
  }

  saveSlot(slot = this.currentSlot) {
    this.memorySaves[slot] = JSON.parse(JSON.stringify(this.state));
    try {
      localStorage.setItem(`${this.SAVE_KEY}_slot${slot}`, JSON.stringify(this.state));
      return true;
    } catch (e) {
      console.warn("localStorage write failed, persistent in memory:", e.message);
      return false;
    }
  }

  sanitize(data) {
    const def = this.getDefaultState();
    for (let k of Object.keys(def)) {
      if (data[k] === undefined) data[k] = def[k];
    }
    data.save_version = this.SAVE_VERSION;
    return data;
  }

  exportBase64() {
    try {
      const str = JSON.stringify(this.state);
      return btoa(str);
    } catch (e) {
      return "";
    }
  }

  importBase64(b64) {
    try {
      const str = atob(b64);
      const data = JSON.parse(str);
      if (data && typeof data === 'object') {
        this.state = this.sanitize(data);
        this.saveSlot(this.currentSlot);
        return true;
      }
    } catch (e) {
      console.error("Save import error:", e);
    }
    return false;
  }

  canAfford(amount) {
    return (this.state.cash || 0) >= amount;
  }

  buyCar(carId) {
    const car = CAR_RECIPES[carId];
    if (!car || this.state.owned_cars[carId]) return false;
    if (!this.canAfford(car.price)) return false;

    this.state.cash -= car.price;
    this.state.owned_cars[carId] = {
      paint_color: car.colorHex ? `#${car.colorHex.toString(16).padStart(6, '0')}` : "#ff6600",
      finish: "metallic",
      rim_style: "default",
      upgrades: {
        engine: 0, turbo: 0, transmission: 0, brakes: 0,
        suspension: 0, tyres: 0, armour: 0, nitro: 0,
        cooling: 0, weight_reduction: 0
      },
      equipped_weapons: {
        primary: "twin_mg",
        roof: "rocket_pod",
        rear: "mine_dropper",
        passive: "armour_plating"
      }
    };
    this.state.selected_car = carId;
    this.saveSlot();
    return true;
  }

  selectCar(carId) {
    if (this.state.owned_cars[carId]) {
      this.state.selected_car = carId;
      this.saveSlot();
      return true;
    }
    return false;
  }

  buyUpgrade(carId, category) {
    if (!this.state.owned_cars[carId]) return false;
    const carData = CAR_RECIPES[carId];
    const carSave = this.state.owned_cars[carId];
    const currentTier = carSave.upgrades[category] || 0;
    if (currentTier >= 5) return false;

    const cost = calculateUpgradeCost(carData.price, category, currentTier + 1);
    if (!this.canAfford(cost)) return false;

    this.state.cash -= cost;
    carSave.upgrades[category] = currentTier + 1;
    this.saveSlot();
    return true;
  }

  selectDriver(driverId) {
    if (DRIVERS[driverId]) {
      this.state.selected_driver = driverId;
      this.saveSlot();
      return true;
    }
    return false;
  }
}
