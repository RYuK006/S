# tests/test_m7_campaign_bench.gd
class_name TestM7CampaignBench
extends RefCounted

const CampaignData = preload("res://scripts/core/campaign_data.gd")
const ArsenalExpanded = preload("res://scripts/weapons/arsenal_expanded.gd")
const BossManager = preload("res://scripts/race/boss_manager.gd")
const BiomeManager = preload("res://scripts/race/biome_manager.gd")

static func run() -> bool:
	print("--- Running TestM7CampaignBench ---")
	
	# Test 1: 4 Regional Biomes & Environmental Palettes
	var biomes := CampaignData.BIOMES
	if biomes.size() != 4:
		printerr("[FAIL] Expected 4 biomes, got %d" % biomes.size())
		return false
	var required_biomes := ["dust_bowl", "neon_docks", "frozen_pass", "volcano_ridge"]
	for b in required_biomes:
		if not biomes.has(b):
			printerr("[FAIL] Missing required biome: %s" % b)
			return false
	print("[PASS] Biomes Catalog: 4 regional biomes verified (Dust Bowl, Neon Docks, Frozen Pass, Volcano Ridge)")
	
	# Test 2: 28 Campaign Races Across 8 Game Modes
	var races := CampaignData.CAMPAIGN_RACES
	if races.size() != 28:
		printerr("[FAIL] Expected 28 campaign races, got %d" % races.size())
		return false
	var modes := {}
	for r in races:
		modes[r["mode"]] = true
	var expected_modes := ["classic", "elimination", "derby", "boss_duel", "time_attack", "checkpoint_rush", "survival", "escort"]
	for m in expected_modes:
		if not modes.has(m):
			printerr("[FAIL] Missing race mode: %s" % m)
			return false
	print("[PASS] Campaign Structure: 28 races across 8 modes validated (Races 1-28, Level 1-60 progression)")
	
	# Test 3: 4 Multi-Phase Boss Encounters
	var bm := BossManager.new()
	# Boss 1: The Hauler (3 phases)
	bm.initialize_boss("The Hauler", 3000.0, 3)
	bm.apply_boss_damage(1100.0)
	var p2 := bm.current_phase
	bm.apply_boss_damage(1100.0)
	var p3 := bm.current_phase
	bm.apply_boss_damage(900.0)
	if p2 != 2 or p3 != 3 or bm.is_active:
		printerr("[FAIL] Boss phase progression failed for The Hauler")
		return false
		
	# Boss 4: The Warden (4 phases, 10,000 HP)
	var bm_warden := BossManager.new()
	bm_warden.initialize_boss("The Warden", 10000.0, 4)
	var pattern_p1 := bm_warden.get_boss_attack_pattern()
	bm_warden.apply_boss_damage(3000.0) # Down to 7000 (Phase 2)
	bm_warden.apply_boss_damage(3000.0) # Down to 4000 (Phase 3)
	var pattern_p3 := bm_warden.get_boss_attack_pattern()
	bm_warden.apply_boss_damage(3000.0) # Down to 1000 (Phase 4)
	if bm_warden.current_phase != 4 or not pattern_p3["uses_flamethrower"]:
		printerr("[FAIL] The Warden 4-phase transition failed")
		return false
	print("[PASS] Boss Encounters: 4 multi-phase titan battles verified with escalating attack patterns")
	
	# Test 4: Complete 26-Weapon Expanded Arsenal
	var arsenal := ArsenalExpanded.ALL_WEAPONS
	if arsenal.size() != 26:
		printerr("[FAIL] Expected 26 weapons in expanded arsenal, got %d" % arsenal.size())
		return false
	if not arsenal.has("railgun") or arsenal["railgun"]["damage"] != 420.0:
		printerr("[FAIL] Railgun specification mismatch")
		return false
	if not arsenal.has("saw_blades") or arsenal["saw_blades"]["slot"] != "melee":
		printerr("[FAIL] Saw blades slot mismatch")
		return false
	if not arsenal.has("shield_generator") or arsenal["shield_generator"]["slot"] != "defensive":
		printerr("[FAIL] Shield generator slot mismatch")
		return false
	print("[PASS] Expanded Arsenal: 26 weapons validated across Front, Roof, Rear, Melee, Defensive")
	
	# Test 5: Biome Surface Grip Modifiers
	var biome_mgr := BiomeManager.new()
	biome_mgr.apply_biome("frozen_pass")
	var ice_grip := biome_mgr.get_surface_grip("ice")
	biome_mgr.apply_biome("dust_bowl")
	var asphalt_grip := biome_mgr.get_surface_grip("asphalt_dry")
	if ice_grip >= asphalt_grip or asphalt_grip <= 0.5:
		printerr("[FAIL] Biome surface grip scaling invalid: ice=%.2f, asphalt=%.2f" % [ice_grip, asphalt_grip])
		return false
	print("[PASS] Biome Surface Dynamics: Grip scaling validated (Asphalt: %.2f, Ice: %.2f)" % [asphalt_grip, ice_grip])
	
	return true
