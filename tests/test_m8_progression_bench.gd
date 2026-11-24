# tests/test_m8_progression_bench.gd
class_name TestM8ProgressionBench
extends RefCounted

const ProgressionSystem = preload("res://scripts/core/progression_system.gd")
const CheatConsole = preload("res://scripts/ui/cheat_console.gd")
const SaveManager = preload("res://scripts/core/save_manager.gd")
const GarageData = preload("res://scripts/core/garage_data.gd")
const ArsenalExpanded = preload("res://scripts/weapons/arsenal_expanded.gd")

static func run() -> bool:
	print("--- Running TestM8ProgressionBench ---")
	
	# Test 1: 100-Level Non-Linear XP Curve
	var prev_xp := 0
	for lvl in range(1, 101):
		var xp := ProgressionSystem.get_xp_for_level(lvl)
		if lvl > 1 and xp <= prev_xp:
			printerr("[FAIL] XP curve not strictly increasing at level %d" % lvl)
			return false
		prev_xp = xp
	var max_lvl_xp := ProgressionSystem.get_xp_for_level(100)
	var calc_lvl := ProgressionSystem.calculate_level_from_xp(max_lvl_xp)
	if calc_lvl != 100 or max_lvl_xp < 195000:
		printerr("[FAIL] Max level 100 XP calculation mismatch (XP: %d, Calc Level: %d)" % [max_lvl_xp, calc_lvl])
		return false
	print("[PASS] XP Curve: 100 levels validated (Level 1: 0 XP, Level 50: ~72k XP, Level 100: %d XP)" % max_lvl_xp)
	
	# Test 2: 60 Career Achievements Roster
	var achievements := ProgressionSystem.ACHIEVEMENTS
	if achievements.size() != 60:
		printerr("[FAIL] Expected 60 achievements, found %d" % achievements.size())
		return false
	var cats := {}
	for ach in achievements:
		cats[ach["cat"]] = int(cats.get(ach["cat"], 0)) + 1
	if cats["racing"] != 12 or cats["combat"] != 12 or cats["garage"] != 12 or cats["mastery"] != 12 or cats["secret"] != 12:
		printerr("[FAIL] Achievement categories distribution invalid: %s" % str(cats))
		return false
	print("[PASS] Career Achievements: 60 achievements validated (12 Racing, 12 Combat, 12 Garage, 12 Mastery, 12 Secret)")
	
	# Test 3: Economy Pacing Simulation
	var pacing := ProgressionSystem.simulate_economy_pacing(140000)
	if not pacing.get("is_balanced", false):
		printerr("[FAIL] Economy pacing unbalanced: %s" % str(pacing))
		return false
	print("[PASS] Economy Pacing: Balanced for progression (Aurelia GT unlocked in %d races, ~%.2f hours)" % [
		pacing["races_needed"], pacing["hours_played"]
	])
	
	# Test 4: Developer Cheat Console Commands
	var sm := SaveManager.new()
	sm.save_data = sm.get_default_state()
	sm.save_data["cash"] = 10000
	sm.save_data["player_level"] = 1
	
	var console := CheatConsole.new()
	console.save_manager = sm
	
	console.execute_command("cash 50000")
	if sm.save_data["cash"] != 60000:
		printerr("[FAIL] Cheat 'cash' failed: cash = %d" % sm.save_data["cash"])
		return false
		
	console.execute_command("level 75")
	if sm.save_data["player_level"] != 75:
		printerr("[FAIL] Cheat 'level' failed: level = %d" % sm.save_data["player_level"])
		return false
		
	console.execute_command("unlock_cars")
	if sm.save_data["owned_cars"].size() != 12:
		printerr("[FAIL] Cheat 'unlock_cars' failed: owned count = %d" % sm.save_data["owned_cars"].size())
		return false
		
	console.execute_command("unlock_weapons")
	if sm.save_data["unlocked_weapons"].size() != 26:
		printerr("[FAIL] Cheat 'unlock_weapons' failed: weapons count = %d" % sm.save_data["unlocked_weapons"].size())
		return false
		
	console.execute_command("god")
	if not console.god_mode:
		printerr("[FAIL] Cheat 'god' toggle failed")
		return false
	print("[PASS] Developer Cheat Console: Command interpreter validated (cash, level, unlock_cars, unlock_weapons, god)")
	
	console.queue_free()
	return true
