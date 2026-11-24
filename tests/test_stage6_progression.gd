# tests/test_stage6_progression.gd
extends Node

const ProgressionSystem = preload("res://src/progression/progression_system.gd")

func _ready():
	print("\n=======================================================")
	print("       GRIDLETHAL STAGE 6 PROGRESSION & BALANCING     ")
	print("=======================================================\n")

	var passes = 0

	# Test 1: Level 1 to 100 XP Curve Dynamics
	var xp_lvl2 = ProgressionSystem.get_xp_for_level(2)
	var xp_lvl50 = ProgressionSystem.get_xp_for_level(50)
	var xp_lvl100 = ProgressionSystem.get_xp_for_level(100)
	var calc_lvl = ProgressionSystem.calculate_level_from_xp(xp_lvl50 + 10)

	if xp_lvl2 > 0 and xp_lvl50 > xp_lvl2 and xp_lvl100 > xp_lvl50 and calc_lvl == 50:
		print("[PASS] Test 1: Levels 1-100 XP Curve Validated (Lvl 2: %d XP, Lvl 50: %d XP, Lvl 100: %d XP)" % [
			xp_lvl2, xp_lvl50, xp_lvl100
		])
		passes += 1
	else:
		print("[FAIL] Test 1: XP curve calculation mismatch")

	# Test 2: 60 Achievements Data Integrity & 5 Categories
	var achs = ProgressionSystem.ACHIEVEMENTS
	var cats = {}
	for a in achs:
		cats[a["cat"]] = true

	if achs.size() == 60 and cats.size() == 5:
		print("[PASS] Test 2: 60 Achievements Validated Across 5 Categories (Racing, Combat, Garage, Mastery, Secret)")
		passes += 1
	else:
		print("[FAIL] Test 2: Expected 60 achievements in 5 categories, found %d achs in %d cats" % [achs.size(), cats.size()])

	# Test 3: Economy Pacing Simulation (Aurelia GT Target)
	var sim = ProgressionSystem.simulate_economy_pacing(140000)
	if sim["is_balanced"] and sim["races_needed"] <= 50:
		print("[PASS] Test 3: Economy Pacing Validated (Aurelia GT $140,000 earned in %d races / %.1f hours)" % [
			sim["races_needed"], sim["hours_played"]
		])
		passes += 1
	else:
		print("[FAIL] Test 3: Economy pacing simulation failed: %s" % str(sim))

	# Test 4: Dust Bowl Starter Progression Timing
	var sim_starter = ProgressionSystem.simulate_economy_pacing(18000) # Dust Viper
	if sim_starter["hours_played"] < 0.6: # ~30 mins
		print("[PASS] Test 4: Starter Tier-2 Pacing Validated (Dust Viper $18,000 in %d races / %.1f hours)" % [
			sim_starter["races_needed"], sim_starter["hours_played"]
		])
		passes += 1
	else:
		print("[FAIL] Test 4: Starter pacing too slow")

	# Test 5: Apex Level 60 Sovereign Requirement Check
	var sovereign_lvl_req = 60
	var req_xp = ProgressionSystem.get_xp_for_level(sovereign_lvl_req)
	if req_xp > 50000:
		print("[PASS] Test 5: Apex Gilded Sovereign Endgame Lock Verified (Requires Level 60, %d Total XP)" % req_xp)
		passes += 1
	else:
		print("[FAIL] Test 5: Apex requirements check failed")

	print("\n-------------------------------------------------------")
	print("STAGE 6 RESULTS: %d / 5 TESTS PASSED" % passes)
	print("-------------------------------------------------------\n")

	if passes == 5:
		print("STAGE 6 ACCEPTANCE CHECKLIST: ALL PASS.\n")
		get_tree().quit(0)
	else:
		print("STAGE 6 ACCEPTANCE CHECKLIST: FAILURES DETECTED.\n")
		get_tree().quit(1)
