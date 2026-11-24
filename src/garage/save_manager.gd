# src/garage/save_manager.gd
class_name SaveManager
extends RefCounted

const SAVE_VERSION = 1
const DEFAULT_SAVE_PATH = "user://gridlethal_save.json"

var current_slot: int = 1
var save_data: Dictionary = {}
var in_memory_fallback: Dictionary = {}

func _init():
	load_slot(1)

func get_default_state() -> Dictionary:
	return {
		"save_version": SAVE_VERSION,
		"player_name": "RYuK006",
		"player_level": 1,
		"player_xp": 0,
		"cash": 15000,
		"gold": 25,
		"scrap": 100,
		"selected_car": "sprinter_r2",
		"selected_driver": "hex",
		"owned_cars": {
			"sprinter_r2": {
				"paint_color": "#ee1808",
				"finish": "metallic",
				"rim_style": "spoke_5",
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

func load_slot(slot: int) -> bool:
	current_slot = slot
	var path = "user://gridlethal_save_slot%d.json" % slot
	var file = FileAccess.open(path, FileAccess.READ)
	if file:
		var text = file.get_as_text()
		var json = JSON.new()
		if json.parse(text) == OK and typeof(json.data) == TYPE_DICTIONARY:
			save_data = sanitize_and_migrate(json.data)
			return true
	
	if in_memory_fallback.has(slot):
		save_data = in_memory_fallback[slot]
	else:
		save_data = get_default_state()
		in_memory_fallback[slot] = save_data
	return true

func save_slot(slot: int) -> bool:
	current_slot = slot
	in_memory_fallback[slot] = save_data.duplicate(true)
	var path = "user://gridlethal_save_slot%d.json" % slot
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data, "\t"))
		return true
	return false

func sanitize_and_migrate(data: Dictionary) -> Dictionary:
	var def = get_default_state()
	for k in def.keys():
		if not data.has(k):
			data[k] = def[k]
	data["save_version"] = SAVE_VERSION
	return data

func export_base64() -> String:
	var json_str = JSON.stringify(save_data)
	return Marshalls.utf8_to_base64(json_str)

func import_base64(b64: String) -> bool:
	var decoded = Marshalls.base64_to_utf8(b64)
	if decoded.is_empty(): return false
	var json = JSON.new()
	if json.parse(decoded) == OK and typeof(json.data) == TYPE_DICTIONARY:
		save_data = sanitize_and_migrate(json.data)
		save_slot(current_slot)
		return true
	return false

func can_afford(amount: int) -> bool:
	return save_data.get("cash", 0) >= amount

func buy_car(car_id: String, price: int) -> bool:
	if not can_afford(price): return false
	if save_data["owned_cars"].has(car_id): return false

	save_data["cash"] -= price
	save_data["owned_cars"][car_id] = {
		"paint_color": "#ff6600",
		"finish": "gloss",
		"rim_style": "default",
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
	if not save_data["owned_cars"].has(car_id): return false
	if not can_afford(cost): return false

	var car_info = save_data["owned_cars"][car_id]
	var current_tier: int = car_info["upgrades"].get(category, 0)
	if current_tier >= 5: return false

	save_data["cash"] -= cost
	car_info["upgrades"][category] = current_tier + 1
	save_slot(current_slot)
	return true
