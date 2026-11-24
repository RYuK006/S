# scripts/core/save_manager.gd
class_name SaveManager
extends RefCounted

const SAVE_VERSION: int = 2
const SAVE_DIR: String = "user://saves/"

var current_slot: int = 1
var save_data: Dictionary = {}
var in_memory_fallback: Dictionary = {}

func _init() -> void:
	_ensure_save_dir()
	load_slot(1)

func _ensure_save_dir() -> void:
	var dir := DirAccess.open("user://")
	if dir and not dir.dir_exists("saves"):
		dir.make_dir("saves")

func get_default_state() -> Dictionary:
	return {
		"save_version": SAVE_VERSION,
		"player_name": "RYuK006",
		"player_level": 1,
		"player_xp": 0,
		"cash": 25000,
		"gold": 50,
		"scrap": 150,
		"selected_car": "sprinter_r2",
		"selected_driver": "hex",
		"owned_cars": {
			"sprinter_r2": {
				"paint_color": "#ee1808",
				"finish": "metallic",
				"rim_style": "spoke_5",
				"has_spoiler": true,
				"upgrades": {
					"engine": 0, "turbo": 0, "transmission": 0, "brakes": 0,
					"suspension": 0, "tyres": 0, "armour": 0, "nitro": 0,
					"cooling": 0, "weight_reduction": 0
				},
				"equipped_weapons": {
					"primary": "twin_mg",
					"roof": "rocket_pod",
					"rear": "mine_dropper",
					"passive": "armour_plating"
				}
			}
		},
		"unlocked_weapons": ["twin_mg", "heavy_mg", "rocket_pod", "mine_dropper", "armour_plating"],
		"completed_races": [],
		"achievements": []
	}

func get_slot_path(slot: int) -> String:
	return "%sslot_%d.json" % [SAVE_DIR, slot]

func get_backup_path(slot: int) -> String:
	return "%sslot_%d.bak" % [SAVE_DIR, slot]

func get_temp_path(slot: int) -> String:
	return "%sslot_%d.json.tmp" % [SAVE_DIR, slot]

func load_slot(slot: int) -> bool:
	current_slot = clamp(slot, 1, 3)
	var path := get_slot_path(current_slot)
	
	if FileAccess.file_exists(path):
		var file := FileAccess.open(path, FileAccess.READ)
		if file:
			var text := file.get_as_text()
			var json := JSON.new()
			if json.parse(text) == OK and typeof(json.data) == TYPE_DICTIONARY:
				save_data = sanitize_and_migrate(json.data)
				return true
			file.close()
		
		# If primary corrupted, try rolling backup
		var bak_path := get_backup_path(current_slot)
		if FileAccess.file_exists(bak_path):
			var bak_file := FileAccess.open(bak_path, FileAccess.READ)
			if bak_file:
				var bak_text := bak_file.get_as_text()
				var bak_json := JSON.new()
				if bak_json.parse(bak_text) == OK and typeof(bak_json.data) == TYPE_DICTIONARY:
					save_data = sanitize_and_migrate(bak_json.data)
					return true
				bak_file.close()

	if in_memory_fallback.has(current_slot):
		save_data = in_memory_fallback[current_slot]
	else:
		save_data = get_default_state()
		in_memory_fallback[current_slot] = save_data.duplicate(true)
	return true

func save_slot(slot: int) -> bool:
	current_slot = clamp(slot, 1, 3)
	in_memory_fallback[current_slot] = save_data.duplicate(true)
	_ensure_save_dir()
	
	var primary_path := get_slot_path(current_slot)
	var backup_path := get_backup_path(current_slot)
	var temp_path := get_temp_path(current_slot)
	
	# Create rolling backup if primary exists
	if FileAccess.file_exists(primary_path):
		var dir := DirAccess.open(SAVE_DIR)
		if dir:
			dir.copy(primary_path, backup_path)
			
	# Atomic write to temp file then rename
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if not file:
		return false
		
	var payload := JSON.stringify(save_data, "\t")
	file.store_string(payload)
	file.flush()
	file.close()
	
	var dir := DirAccess.open(SAVE_DIR)
	if dir:
		if FileAccess.file_exists(primary_path):
			dir.remove(primary_path)
		var err := dir.rename(temp_path, primary_path)
		return err == OK
		
	return false

func sanitize_and_migrate(data: Dictionary) -> Dictionary:
	var def := get_default_state()
	for k in def.keys():
		if not data.has(k):
			data[k] = def[k]
	
	var ver: int = int(data.get("save_version", 1))
	if ver < SAVE_VERSION:
		# Run migration functions
		data = _migrate_v1_to_v2(data)
		
	data["save_version"] = SAVE_VERSION
	return data

func _migrate_v1_to_v2(data: Dictionary) -> Dictionary:
	# Version 2 adds spoiler option and scrap resource
	if not data.has("scrap"):
		data["scrap"] = 150
	var owned: Dictionary = data.get("owned_cars", {})
	for car_id in owned.keys():
		var car_info: Dictionary = owned[car_id]
		if not car_info.has("has_spoiler"):
			car_info["has_spoiler"] = true
	return data

func export_base64() -> String:
	var json_str := JSON.stringify(save_data)
	return Marshalls.utf8_to_base64(json_str)

func import_base64(b64: String) -> bool:
	var decoded := Marshalls.base64_to_utf8(b64)
	if decoded.is_empty():
		return false
	var json := JSON.new()
	if json.parse(decoded) == OK and typeof(json.data) == TYPE_DICTIONARY:
		save_data = sanitize_and_migrate(json.data)
		save_slot(current_slot)
		return true
	return false

func can_afford(amount: int) -> bool:
	return int(save_data.get("cash", 0)) >= amount

func buy_car(car_id: String, price: int) -> bool:
	if not can_afford(price):
		return false
	var owned: Dictionary = save_data.get("owned_cars", {})
	if owned.has(car_id):
		return false

	save_data["cash"] = int(save_data["cash"]) - price
	owned[car_id] = {
		"paint_color": "#ff6600",
		"finish": "gloss",
		"rim_style": "default",
		"has_spoiler": true,
		"upgrades": {
			"engine": 0, "turbo": 0, "transmission": 0, "brakes": 0,
			"suspension": 0, "tyres": 0, "armour": 0, "nitro": 0,
			"cooling": 0, "weight_reduction": 0
		},
		"equipped_weapons": {
			"primary": "twin_mg",
			"roof": "rocket_pod",
			"rear": "mine_dropper",
			"passive": "armour_plating"
		}
	}
	save_slot(current_slot)
	return true

func buy_upgrade(car_id: String, category: String, cost: int) -> bool:
	var owned: Dictionary = save_data.get("owned_cars", {})
	if not owned.has(car_id):
		return false
	if not can_afford(cost):
		return false

	var car_info: Dictionary = owned[car_id]
	var upgrades: Dictionary = car_info.get("upgrades", {})
	var current_tier: int = int(upgrades.get(category, 0))
	if current_tier >= 5:
		return false

	save_data["cash"] = int(save_data["cash"]) - cost
	upgrades[category] = current_tier + 1
	save_slot(current_slot)
	return true
