# src/garage/garage_data.gd
class_name GarageData
extends RefCounted

const CAR_RECIPES = {
	# RALLY CLASS
	"sprinter_r2": {
		"id": "sprinter_r2", "name": "Sprinter R2", "class": "Rally",
		"mass": 1050.0, "power_kw": 140.0, "top_speed": 175.0, "accel_0_100": 6.8,
		"health": 700.0, "price": 0, "level_req": 1,
		"drivetrain": "AWD", "slots": ["primary", "roof"],
		"perk": "Underdog", "perk_desc": "+10% weapon damage when below half health."
	},
	"dust_viper": {
		"id": "dust_viper", "name": "Dust Viper", "class": "Rally",
		"mass": 1150.0, "power_kw": 210.0, "top_speed": 205.0, "accel_0_100": 5.0,
		"health": 800.0, "price": 18000, "level_req": 3,
		"drivetrain": "AWD", "slots": ["primary", "roof", "rear"],
		"perk": "Drift King", "perk_desc": "Drifting fills nitro bar 30% faster."
	},
	"gravel_fang": {
		"id": "gravel_fang", "name": "Gravel Fang", "class": "Rally",
		"mass": 1200.0, "power_kw": 250.0, "top_speed": 215.0, "accel_0_100": 4.4,
		"health": 900.0, "price": 42000, "level_req": 7,
		"drivetrain": "AWD", "slots": ["primary", "roof", "rear", "passive"],
		"perk": "Gravel Specialist", "perk_desc": "No grip loss on dirt and gravel surfaces."
	},
	"tundra_wolf": {
		"id": "tundra_wolf", "name": "Tundra Wolf", "class": "Rally",
		"mass": 1300.0, "power_kw": 230.0, "top_speed": 200.0, "accel_0_100": 5.4,
		"health": 1000.0, "price": 55000, "level_req": 11,
		"drivetrain": "AWD", "slots": ["primary", "roof", "rear", "passive"],
		"perk": "Studded", "perk_desc": "Snow and ice grip equals asphalt grip."
	},

	# OFFROAD / MONSTER CLASS
	"bulldog_6x6": {
		"id": "bulldog_6x6", "name": "Bulldog 6x6", "class": "Offroad",
		"mass": 3600.0, "power_kw": 260.0, "top_speed": 150.0, "accel_0_100": 9.0,
		"health": 2200.0, "price": 35000, "level_req": 5,
		"drivetrain": "6x6", "slots": ["primary", "roof", "rear", "passive"],
		"perk": "Battering Ram", "perk_desc": "Ramming damage x1.5, takes 30% less ram damage."
	},
	"rock_crusher": {
		"id": "rock_crusher", "name": "Rock Crusher", "class": "Offroad",
		"mass": 2600.0, "power_kw": 330.0, "top_speed": 170.0, "accel_0_100": 6.9,
		"health": 1800.0, "price": 60000, "level_req": 10,
		"drivetrain": "4x4", "slots": ["primary", "roof", "rear", "passive"],
		"perk": "Crawler", "perk_desc": "Can climb steep slopes, no penalty in mud."
	},
	"mud_reaper": {
		"id": "mud_reaper", "name": "Mud Reaper", "class": "Offroad",
		"mass": 1500.0, "power_kw": 280.0, "top_speed": 185.0, "accel_0_100": 5.6,
		"health": 950.0, "price": 48000, "level_req": 8,
		"drivetrain": "RWD", "slots": ["primary", "roof", "rear"],
		"perk": "Airtime", "perk_desc": "Landing from jumps refills nitro."
	},
	"scrap_titan": {
		"id": "scrap_titan", "name": "Scrap Titan", "class": "Offroad",
		"mass": 4800.0, "power_kw": 450.0, "top_speed": 140.0, "accel_0_100": 8.2,
		"health": 3500.0, "price": 110000, "level_req": 18,
		"drivetrain": "4x4", "slots": ["primary", "roof", "rear", "passive", "side"],
		"perk": "Juggernaut", "perk_desc": "Small cars knocked aside, immune to spike strips."
	},

	# LUXURY / SUPER CLASS
	"aurelia_gt": {
		"id": "aurelia_gt", "name": "Aurelia GT", "class": "Super",
		"mass": 1600.0, "power_kw": 380.0, "top_speed": 285.0, "accel_0_100": 4.1,
		"health": 750.0, "price": 140000, "level_req": 22,
		"drivetrain": "RWD", "slots": ["primary", "roof", "passive"],
		"perk": "Grand Touring", "perk_desc": "Stable at high speed with extra aerodynamic downforce."
	},
	"noir_phantom": {
		"id": "noir_phantom", "name": "Noir Phantom", "class": "Super",
		"mass": 2300.0, "power_kw": 450.0, "top_speed": 270.0, "accel_0_100": 4.4,
		"health": 1500.0, "price": 220000, "level_req": 30,
		"drivetrain": "AWD", "slots": ["primary", "roof", "rear", "passive"],
		"perk": "Prestige", "perk_desc": "+15% reputation gain from all events."
	},
	"vandal_hyper": {
		"id": "vandal_hyper", "name": "Vandal Hyper", "class": "Super",
		"mass": 1350.0, "power_kw": 700.0, "top_speed": 345.0, "accel_0_100": 2.7,
		"health": 600.0, "price": 380000, "level_req": 42,
		"drivetrain": "AWD", "slots": ["primary", "roof", "passive"],
		"perk": "Hybrid Boost", "perk_desc": "Nitro bar recharges rapidly under hard braking."
	},
	"gilded_sovereign": {
		"id": "gilded_sovereign", "name": "Gilded Sovereign", "class": "Super",
		"mass": 3000.0, "power_kw": 400.0, "top_speed": 240.0, "accel_0_100": 5.5,
		"health": 2000.0, "price": 520000, "level_req": 60,
		"drivetrain": "RWD", "slots": ["primary", "roof", "rear", "passive", "side"],
		"perk": "Tax Collector", "perk_desc": "+20% cash payout from all races and bounties."
	}
}

const UPGRADE_CATEGORIES = {
	"engine": { "name": "Engine", "base_factor": 0.12, "stat": "power", "delta_per_tier": 0.06 },
	"turbo": { "name": "Turbocharger", "base_factor": 0.10, "stat": "boost", "delta_per_tier": 0.04 },
	"transmission": { "name": "Transmission", "base_factor": 0.08, "stat": "shift_speed", "delta_per_tier": 0.07 },
	"brakes": { "name": "Brakes", "base_factor": 0.07, "stat": "braking", "delta_per_tier": 0.08 },
	"suspension": { "name": "Suspension", "base_factor": 0.08, "stat": "handling", "delta_per_tier": 0.06 },
	"tyres": { "name": "Tyres", "base_factor": 0.09, "stat": "grip", "delta_per_tier": 0.05 },
	"armour": { "name": "Armour", "base_factor": 0.11, "stat": "health", "delta_per_tier": 0.10 },
	"nitro": { "name": "Nitro Tank", "base_factor": 0.06, "stat": "nitro_cap", "delta_per_tier": 0.20 },
	"cooling": { "name": "Cooling System", "base_factor": 0.05, "stat": "heat_dissipation", "delta_per_tier": 0.15 },
	"weight_reduction": { "name": "Weight Reduction", "base_factor": 0.10, "stat": "mass", "delta_per_tier": -0.03 }
}

const DRIVERS = {
	"hex": { "id": "hex", "name": "Hex", "title": "The Mechanic", "perk": "-15% repair & refuel costs." },
	"duster": { "id": "duster", "name": "Duster", "title": "The Daredevil", "perk": "Jumps instantly replenish 25% nitro." },
	"kestrel": { "id": "kestrel", "name": "Kestrel", "title": "The Gunner", "perk": "+10% weapon damage across all slots." },
	"rook": { "id": "rook", "name": "Rook", "title": "The Tank", "perk": "+10% total armour integrity." },
	"vee": { "id": "vee", "name": "Vee", "title": "The Ace", "perk": "+8% tire grip on all surfaces." },
	"maddox": { "id": "maddox", "name": "Maddox", "title": "The Scavenger", "perk": "+20% cash and pickup rewards." }
}

static func calculate_upgrade_cost(base_price: int, category: String, tier: int) -> int:
	var cat_data = UPGRADE_CATEGORIES.get(category, {})
	var base_fac: float = cat_data.get("base_factor", 0.08)
	var tier_multipliers: Array = [0.05, 0.09, 0.15, 0.25, 0.40]
	var mult: float = tier_multipliers[clamp(tier - 1, 0, 4)]
	var effective_base: float = float(max(base_price, 12000))
	return int(round(effective_base * base_fac * mult * 10.0))

static func get_all_showroom_recipes() -> Dictionary:
	var all_recipes: Dictionary = CAR_RECIPES.duplicate(true)
	if not FileAccess.file_exists("res://data/vehicles.json"):
		return all_recipes
	var f := FileAccess.open("res://data/vehicles.json", FileAccess.READ)
	if not f:
		return all_recipes
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if not (parsed is Dictionary):
		return all_recipes
	var list: Array = parsed.get("vehicles", [])
	for v_var: Variant in list:
		if not (v_var is Dictionary):
			continue
		var v: Dictionary = v_var
		var cid: String = str(v.get("id", ""))
		if cid.is_empty() or all_recipes.has(cid):
			continue
		var pw_kw: float = roundf(float(v.get("engine_power_hp", 350.0)) * 0.7457)
		var ms: float = float(v.get("mass", 1400.0))
		var top_sp: float = roundf(clampf(180.0 + pw_kw * 0.28, 170.0, 405.0))
		var arch: String = str(v.get("class_archetype", "Super"))
		all_recipes[cid] = {
			"id": cid,
			"name": str(v.get("name", cid)),
			"class": arch,
			"mass": ms,
			"power_kw": pw_kw,
			"top_speed": top_sp,
			"accel_0_100": clampf(ms / maxf(pw_kw, 80.0) * 1.15, 2.2, 8.5),
			"health": float(v.get("health", 800.0)),
			"price": int(roundf(pw_kw * 420.0)),
			"level_req": 1,
			"drivetrain": "AWD",
			"slots": ["primary", "roof", "passive"],
			"perk": "Autoshow Spec",
			"perk_desc": "Unlocked FH5-grade exotic machine.",
			"model_path": str(v.get("model_path", ""))
		}
	return all_recipes

static func compute_car_stats(car_id: String, upgrades: Dictionary) -> Dictionary:
	var all_recipes: Dictionary = get_all_showroom_recipes()
	var base_recipe: Dictionary = all_recipes.get(car_id, CAR_RECIPES["sprinter_r2"])
	var mass: float = base_recipe["mass"]
	var power: float = base_recipe["power_kw"]
	var top_speed: float = base_recipe["top_speed"]
	var health: float = base_recipe["health"]

	# Apply tier modifiers
	for cat in upgrades.keys():
		var tier: int = int(upgrades[cat])
		if tier <= 0: continue
		var info = UPGRADE_CATEGORIES.get(cat, {})
		var delta: float = info.get("delta_per_tier", 0.0)
		if cat == "engine":
			power *= (1.0 + delta * tier)
			top_speed *= (1.0 + delta * 0.5 * tier)
		elif cat == "armour":
			health *= (1.0 + delta * tier)
		elif cat == "weight_reduction":
			mass *= (1.0 + delta * tier)

	var rating_score = (power * 0.4) + (health * 0.15) + (top_speed * 0.35) - (mass * 0.05)
	var car_class = "D"
	if rating_score > 320: car_class = "S"
	elif rating_score > 240: car_class = "A"
	elif rating_score > 180: car_class = "B"
	elif rating_score > 130: car_class = "C"

	return {
		"mass": mass,
		"power_kw": power,
		"top_speed": top_speed,
		"health": health,
		"rating_score": rating_score,
		"class_rating": car_class
	}
