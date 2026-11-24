# run_all.gd
# Unified headless test runner for GRIDLETHAL.
extends SceneTree

const TestDataValidation = preload("res://tests/test_data_validation.gd")
const TestPhysicsBench = preload("res://tests/test_physics_bench.gd")
const TestAudioBench = preload("res://tests/test_audio_bench.gd")

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
		
	print("\n-------------------------------------------------------")
	if all_pass:
		print("RESULTS: ALL HEADLESS TESTS PASSED (3/3)")
		print("-------------------------------------------------------\n")
		quit(0)
	else:
		printerr("RESULTS: ONE OR MORE TESTS FAILED!")
		print("-------------------------------------------------------\n")
		quit(1)
