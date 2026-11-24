# tests/test_stage5_campaign.gd
extends Node

const CampaignData = preload("res://src/campaign/campaign_data.gd")
const ArsenalExpanded = preload("res://src/weapons/arsenal_expanded.gd")
const BossManager = preload("res://src/campaign/boss_manager.gd")

func _ready():
	print("\n=======================================================")
	print("       GRIDLETHAL STAGE 5 CAMPAIGN & BIOMES SUITE     ")
	print("=======================================================\n")

	var passes = 0

	# Test 1: 28 Campaign Races Across 4 Regions
	var races = CampaignData.CAMPAIGN_RACES
	if races.size() == 28:
		var has_r1 = races[0]["name"] == "Rust Gate Sprint" and races[0]["region"] == "dust_bowl"
		var has_r28 = races[27]["name"] == "FINAL BOSS: The Warden" and races[27]["region"] == "volcano_ridge"
		if has_r1 and has_r28:
			print("[PASS] Test 1: 28 Campaign Races Validated Across 4 Biomes (Race 1: %s, Final: %s)" % [races[0]["name"], races[27]["name"]])
			passes += 1
		else:
			print("[FAIL] Test 1: Missing start or final race specifications")
	else:
		print("[FAIL] Test 1: Expected 28 races, found %d" % races.size())

	# Test 2: 8 Race Modes Validated
	var modes = {}
	for r in races:
		modes[r["mode"]] = true
	if modes.size() == 8 and modes.has("classic") and modes.has("elimination") and modes.has("derby") and modes.has("boss_duel"):
		print("[PASS] Test 2: 8 Race Modes Validated (Classic, Derby, Time Attack, Rush, Elimination, Boss, Escort, Survival)")
		passes += 1
	else:
		print("[FAIL] Test 2: Expected 8 distinct race modes, found %d" % modes.size())

	# Test 3: Complete 26-Item Arsenal Specification
	var weapons = ArsenalExpanded.ALL_WEAPONS
	if weapons.size() == 26:
		var has_railgun = weapons.has("railgun") and weapons["railgun"]["damage"] == 420.0
		var has_saw = weapons.has("saw_blades") and weapons["saw_blades"]["slot"] == "melee"
		var has_shield = weapons.has("shield_generator") and weapons["shield_generator"]["slot"] == "defensive"
		if has_railgun and has_saw and has_shield:
			print("[PASS] Test 3: Complete 26-Weapon Arsenal Validated (Railgun 420 dmg, Saw Blades melee, Shield Generator defensive)")
			passes += 1
		else:
			print("[FAIL] Test 3: Key weapons missing from 26-item roster")
	else:
		print("[FAIL] Test 3: Expected 26 weapons, found %d" % weapons.size())

	# Test 4: Multi-Phase Boss Duel Encounter Dynamics
	var bm = BossManager.new()
	bm.initialize_boss("The Hauler", 3000.0, 3)
	bm.apply_boss_damage(1200.0) # Down to 1800 (Phase 2)
	var p2 = bm.current_phase
	bm.apply_boss_damage(1200.0) # Down to 600 (Phase 3)
	var p3 = bm.current_phase
	bm.apply_boss_damage(700.0) # Down to 0 (Defeated)
	if p2 == 2 and p3 == 3 and not bm.is_active:
		print("[PASS] Test 4: Boss Encounter Dynamics Validated (Phase 1 -> 2 -> 3 -> Defeated)")
		passes += 1
	else:
		print("[FAIL] Test 4: Boss phase transition failed (p2: %d, p3: %d, active: %s)" % [p2, p3, bm.is_active])

	# Test 5: Biome Surface Grip Modifiers
	var grips = CampaignData.SURFACE_GRIP_TABLE
	if grips["asphalt_dry"] == 1.0 and grips["asphalt_wet"] == 0.72 and grips["snow"] == 0.42 and grips["ice"] == 0.18:
		print("[PASS] Test 5: Biome Surface Grip Multipliers Validated (Dry: 1.0, Wet: 0.72, Snow: 0.42, Ice: 0.18)")
		passes += 1
	else:
		print("[FAIL] Test 5: Surface grip table values do not match physics standard")

	print("\n-------------------------------------------------------")
	print("STAGE 5 RESULTS: %d / 5 TESTS PASSED" % passes)
	print("-------------------------------------------------------\n")

	if passes == 5:
		print("STAGE 5 ACCEPTANCE CHECKLIST: ALL PASS.\n")
		get_tree().quit(0)
	else:
		print("STAGE 5 ACCEPTANCE CHECKLIST: FAILURES DETECTED.\n")
		get_tree().quit(1)
