# run_all.gd
# Unified headless test runner for GRIDLETHAL.
extends SceneTree

const TestDataValidation = preload("res://tests/test_data_validation.gd")
const TestPhysicsBench = preload("res://tests/test_physics_bench.gd")
const TestAudioBench = preload("res://tests/test_audio_bench.gd")
const TestM2DrivingBench = preload("res://tests/test_m2_driving_bench.gd")
const TestM3VisualBench = preload("res://tests/test_m3_visual_bench.gd")
const TestM4RacingBench = preload("res://tests/test_m4_racing_bench.gd")

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
		
	print("\n-------------------------------------------------------")
	if all_pass:
		print("RESULTS: ALL HEADLESS TESTS PASSED (6/6)")
		print("-------------------------------------------------------\n")
		quit(0)
	else:
		printerr("RESULTS: ONE OR MORE TESTS FAILED!")
		print("-------------------------------------------------------\n")
		quit(1)
