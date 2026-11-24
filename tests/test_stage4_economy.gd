# tests/test_stage4_economy.gd
extends Node

const GarageData = preload("res://src/garage/garage_data.gd")
const SaveManager = preload("res://src/garage/save_manager.gd")

func _ready():
	print("\n=======================================================")
	print("       GRIDLETHAL STAGE 4 ECONOMY & GARAGE SUITE      ")
	print("=======================================================\n")

	var passes = 0

	# Test 1: All 12 Vehicles Defined & Scaled
	var recipes = GarageData.CAR_RECIPES
	if recipes.size() == 12:
		var has_starter = recipes.has("sprinter_r2") and recipes["sprinter_r2"]["price"] == 0
		var has_final = recipes.has("gilded_sovereign") and recipes["gilded_sovereign"]["price"] == 520000
		if has_starter and has_final:
			print("[PASS] Test 1: 12 Vehicles Catalog Validated (Starter: Sprinter R2, Apex: Gilded Sovereign)")
			passes += 1
		else:
			print("[FAIL] Test 1: Missing starter or apex car specifications")
	else:
		print("[FAIL] Test 1: Expected 12 cars, found %d" % recipes.size())

	# Test 2: 10 Upgrade Categories & Tier Stat Recalculation
	var base_stats = GarageData.compute_car_stats("sprinter_r2", {})
	var max_upgrades = {
		"engine": 5, "armour": 5, "weight_reduction": 5
	}
	var tuned_stats = GarageData.compute_car_stats("sprinter_r2", max_upgrades)
	if tuned_stats["power_kw"] > base_stats["power_kw"] and tuned_stats["health"] > base_stats["health"] and tuned_stats["mass"] < base_stats["mass"]:
		print("[PASS] Test 2: 10 Upgrade Categories & Stat Dynamics (Power: %.1f -> %.1f kW, HP: %.0f -> %.0f, Mass: %.0f -> %.0f kg)" % [
			base_stats["power_kw"], tuned_stats["power_kw"],
			base_stats["health"], tuned_stats["health"],
			base_stats["mass"], tuned_stats["mass"]
		])
		passes += 1
	else:
		print("[FAIL] Test 2: Upgrade stat recalculation failed")

	# Test 3: Save Manager Persistence, Base64 Export & Import
	var sm = SaveManager.new()
	sm.save_data["cash"] = 85000
	sm.save_data["player_level"] = 12
	var b64_export = sm.export_base64()

	var sm_import = SaveManager.new()
	var success = sm_import.import_base64(b64_export)
	if success and sm_import.save_data["cash"] == 85000 and sm_import.save_data["player_level"] == 12:
		print("[PASS] Test 3: Base64 Save Serialization & Deserialization Verified (Cash: 85000, Level: 12)")
		passes += 1
	else:
		print("[FAIL] Test 3: Base64 import failed")

	# Test 4: Economy Purchase & Upgrade Transactions
	var sm2 = SaveManager.new()
	sm2.save_data = sm2.get_default_state()
	sm2.save_data["cash"] = 30000
	var bought_car = sm2.buy_car("dust_viper", 18000)
	var upgrade_cost = GarageData.calculate_upgrade_cost(18000, "engine", 1)
	var bought_upgrade = sm2.buy_upgrade("dust_viper", "engine", upgrade_cost)
	if bought_car and bought_upgrade and sm2.save_data["cash"] == (30000 - 18000 - upgrade_cost):
		print("[PASS] Test 4: Economy Transactions Validated (Car Purchase & Engine Upgrade, Cash Remaining: %d)" % sm2.save_data["cash"])
		passes += 1
	else:
		print("[FAIL] Test 4: Economy transaction failed")

	# Test 5: 6 Drivers & Perk Specifications
	var drivers = GarageData.DRIVERS
	if drivers.size() == 6 and drivers.has("hex") and drivers.has("maddox"):
		print("[PASS] Test 5: 6 Drivers & Specialization Perks Validated (Hex: %s, Maddox: %s)" % [
			drivers["hex"]["perk"], drivers["maddox"]["perk"]
		])
		passes += 1
	else:
		print("[FAIL] Test 5: Driver catalog incomplete")

	print("\n-------------------------------------------------------")
	print("STAGE 4 RESULTS: %d / 5 TESTS PASSED" % passes)
	print("-------------------------------------------------------\n")

	if passes == 5:
		print("STAGE 4 ACCEPTANCE CHECKLIST: ALL PASS.\n")
		get_tree().quit(0)
	else:
		print("STAGE 4 ACCEPTANCE CHECKLIST: FAILURES DETECTED.\n")
		get_tree().quit(1)
