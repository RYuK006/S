# data_validator.gd
# Validates all JSON files in data/ at startup with descriptive error messages.
class_name DataValidator
extends RefCounted

const REQUIRED_VEHICLE_FIELDS: Array[String] = [
	"id", "name", "class_archetype", "benchmark", "mass", "engine_power_hp",
	"max_torque_nm", "idle_rpm", "redline_rpm", "gear_ratios", "reverse_ratio",
	"final_drive", "wheelbase", "track_width", "tire_params", "drag_coeff",
	"frontal_area", "health", "combat_rating", "hp_ton", "model_path"
]

const REQUIRED_WEAPON_FIELDS: Array[String] = [
	"id", "name", "slot", "damage", "price"
]

static func validate_all() -> Dictionary:
	var errors: Array[String] = []
	
	# 1. Vehicles
	var v_res = _load_and_validate_json("res://data/vehicles.json")
	if not v_res.error.is_empty():
		errors.append(v_res.error)
	else:
		errors.append_array(validate_vehicles(v_res.data))
		
	# 2. Weapons
	var w_res = _load_and_validate_json("res://data/weapons.json")
	if not w_res.error.is_empty():
		errors.append(w_res.error)
	else:
		errors.append_array(validate_weapons(w_res.data))
		
	# 3. Upgrades
	var u_res = _load_and_validate_json("res://data/upgrades.json")
	if not u_res.error.is_empty():
		errors.append(u_res.error)
	else:
		errors.append_array(validate_upgrades(u_res.data))
		
	# 4. Economy
	var e_res = _load_and_validate_json("res://data/economy.json")
	if not e_res.error.is_empty():
		errors.append(e_res.error)
	else:
		errors.append_array(validate_economy(e_res.data))
		
	return {
		"success": errors.is_empty(),
		"errors": errors
	}

static func validate_vehicles(data: Dictionary) -> Array[String]:
	var errs: Array[String] = []
	if not data.has("vehicles") or not (data["vehicles"] is Array):
		errs.append("vehicles.json is missing top-level 'vehicles' array")
		return errs
		
	var vehicles: Array = data["vehicles"]
	if vehicles.size() < 30:
		errs.append("vehicles.json has %d vehicles, expected at least 30" % vehicles.size())
		
	for i in range(vehicles.size()):
		var v = vehicles[i]
		if not (v is Dictionary):
			errs.append("Vehicle at index %d is not a Dictionary" % i)
			continue
		var v_id = v.get("id", "index_%d" % i)
		for f in REQUIRED_VEHICLE_FIELDS:
			if not v.has(f):
				errs.append("Vehicle '%s' is missing required field '%s'" % [v_id, f])
		if v.has("mass") and float(v["mass"]) <= 0.0:
			errs.append("Vehicle '%s' mass must be > 0 (got %s)" % [v_id, str(v["mass"])])
		if v.has("health") and float(v["health"]) <= 0.0:
			errs.append("Vehicle '%s' health must be > 0 (got %s)" % [v_id, str(v["health"])])
	return errs

static func validate_weapons(data: Dictionary) -> Array[String]:
	var errs: Array[String] = []
	if not data.has("weapons") or not (data["weapons"] is Array):
		errs.append("weapons.json is missing top-level 'weapons' array")
		return errs
		
	var weapons: Array = data["weapons"]
	for i in range(weapons.size()):
		var w = weapons[i]
		if not (w is Dictionary):
			errs.append("Weapon at index %d is not a Dictionary" % i)
			continue
		var w_id = w.get("id", "index_%d" % i)
		for f in REQUIRED_WEAPON_FIELDS:
			if not w.has(f):
				errs.append("Weapon '%s' is missing required field '%s'" % [w_id, f])
	return errs

static func validate_upgrades(data: Dictionary) -> Array[String]:
	var errs: Array[String] = []
	if not data.has("categories") or not (data["categories"] is Array):
		errs.append("upgrades.json is missing top-level 'categories' array")
		return errs
	var cats: Array = data["categories"]
	for c in cats:
		if not (c is Dictionary):
			errs.append("Upgrade category is not a Dictionary")
			continue
		var cid = c.get("id", "unknown")
		if not c.has("tiers") or not (c["tiers"] is Array):
			errs.append("Upgrade category '%s' is missing 'tiers' array" % cid)
		elif c["tiers"].size() < 5:
			errs.append("Upgrade category '%s' has %d tiers, expected 5" % [cid, c["tiers"].size()])
	return errs

static func validate_economy(data: Dictionary) -> Array[String]:
	var errs: Array[String] = []
	if not data.has("xp_curve"):
		errs.append("economy.json missing 'xp_curve'")
	if not data.has("race_purses"):
		errs.append("economy.json missing 'race_purses'")
	if not data.has("combat_bounties"):
		errs.append("economy.json missing 'combat_bounties'")
	return errs

static func _load_and_validate_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return { "data": {}, "error": "JSON file not found: %s" % path }
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		return { "data": {}, "error": "Failed to open JSON file: %s" % path }
	var content = file.get_as_text()
	file.close()
	var json = JSON.new()
	var err = json.parse(content)
	if err != OK:
		return { "data": {}, "error": "JSON parse error in %s at line %d: %s" % [path, json.get_error_line(), json.get_error_message()] }
	if not (json.data is Dictionary):
		return { "data": {}, "error": "JSON in %s root must be a Dictionary object" % path }
	return { "data": json.data, "error": "" }
