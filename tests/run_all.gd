# run_all.gd
# Unified headless test runner for GRIDLETHAL.
extends SceneTree

const TestDataValidation = preload("res://tests/test_data_validation.gd")
const TestPhysicsBench = preload("res://tests/test_physics_bench.gd")
const TestAudioBench = preload("res://tests/test_audio_bench.gd")
const TestM2DrivingBench = preload("res://tests/test_m2_driving_bench.gd")
const TestM3VisualBench = preload("res://tests/test_m3_visual_bench.gd")
const TestM4RacingBench = preload("res://tests/test_m4_racing_bench.gd")
const TestM5CombatBench = preload("res://tests/test_m5_combat_bench.gd")
const TestM6GarageBench = preload("res://tests/test_m6_garage_bench.gd")
const TestM7CampaignBench = preload("res://tests/test_m7_campaign_bench.gd")
const TestM8ProgressionBench = preload("res://tests/test_m8_progression_bench.gd")
const TestM9NetcodeBench = preload("res://tests/test_m9_netcode_bench.gd")

func _init():
	print("\n=======================================================")
	print("       GRIDLETHAL HEADLESS AUTOMATED TEST SUITE        ")
	print("=======================================================\n")
	
	var all_pass = true
	
	if not TestDataValidation.run():
		all_pass = false
		
	if not TestPhysicsBench.run():
		all_pass = false
		
	if not TestAudioBench.run():
		all_pass = false
		
	if not TestM2DrivingBench.run():
		all_pass = false
		
	if not TestM3VisualBench.run():
		all_pass = false
		
	if not TestM4RacingBench.run():
		all_pass = false
		
	if not TestM5CombatBench.run():
		all_pass = false
		
	if not TestM6GarageBench.run():
		all_pass = false
		
	if not TestM7CampaignBench.run():
		all_pass = false
		
	if not TestM8ProgressionBench.run():
		all_pass = false
		
	if not TestM9NetcodeBench.run():
		all_pass = false
		
	print("\n-------------------------------------------------------")
	if all_pass:
		print("RESULTS: ALL HEADLESS TESTS PASSED (11/11)")
		print("-------------------------------------------------------\n")
		quit(0)
	else:
		printerr("RESULTS: ONE OR MORE TESTS FAILED!")
		print("-------------------------------------------------------\n")
		quit(1)
