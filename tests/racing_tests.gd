# racing_tests.gd
# Headless verification of Stage 2 Racing: Spline track, checkpoints, race state machine, and AI navigation.
extends SceneTree

const SplineTrack = preload("res://src/tracks/spline_track.gd")
const RaceManager = preload("res://src/core/race_manager.gd")
const VehicleController = preload("res://src/vehicles/vehicle_controller.gd")
const AIDriver = preload("res://src/ai/ai_driver.gd")

func _init():
	print("\n=======================================================")
	print("       GRIDLETHAL STAGE 2 RACING VERIFICATION SUITE    ")
	print("=======================================================\n")
	
	var total_tests = 0
	var passed_tests = 0
	
	# Test 1: Catmull-Rom Spline Track Generation
	total_tests += 1
	var track = SplineTrack.new()
	track.setup_circuit()
	
	if track.track_points.size() == 180 and track.total_length > 800.0 and track.checkpoints.size() == 18:
		print("[PASS] Test 1: Spline Track Generation (Samples: %d, Length: %.1fm, Gates: %d)" % [
			track.track_points.size(), track.total_length, track.checkpoints.size()
		])
		passed_tests += 1
	else:
		printerr("[FAIL] Test 1: Spline track generation failed!")
		
	# Test 2: Race State Machine & Countdown Progression
	total_tests += 1
	var race_mgr = RaceManager.new()
	var player = VehicleController.new()
	player.car_id = "sprinter_r2"
	var ai1 = VehicleController.new()
	ai1.car_id = "sprinter_r2"
	
	race_mgr.setup_race(track, player, [ai1], 3)
	
	if race_mgr.state == RaceManager.RaceState.COUNTDOWN:
		# Simulate 4.1 seconds of countdown
		for _step in range(int(4.1 * 120)):
			race_mgr._physics_process(1.0 / 120.0)
			
		if race_mgr.state == RaceManager.RaceState.RACING:
			print("[PASS] Test 2: Race State Machine (COUNTDOWN -> RACING verified)")
			passed_tests += 1
		else:
			printerr("[FAIL] Test 2: Countdown transition failed, state: %d" % race_mgr.state)
	else:
		printerr("[FAIL] Test 2: Initial state not COUNTDOWN!")
		
	# Test 3: Checkpoint Progression & Lap Counting
	total_tests += 1
	# Position player right at checkpoint 0 gate
	player.global_position = track.checkpoints[0].global_position
	race_mgr._physics_process(1.0 / 120.0)
	
	var p_prog = race_mgr.car_progress[player]
	if p_prog.next_checkpoint == 1:
		print("[PASS] Test 3: Checkpoint Gate Collision & Progression (Gate 0 -> Next: %d)" % p_prog.next_checkpoint)
		passed_tests += 1
	else:
		printerr("[FAIL] Test 3: Checkpoint advancement failed, next: %d" % p_prog.next_checkpoint)
		
	# Test 4: Dynamic Leaderboard Position Sorting
	total_tests += 1
	# Advance AI to gate 2 so AI is ahead of player
	ai1.global_position = track.checkpoints[2].global_position
	race_mgr.car_progress[ai1].next_checkpoint = 3
	race_mgr._physics_process(1.0 / 120.0)
	
	var player_pos = race_mgr.get_player_position()
	if player_pos == 2 and race_mgr.current_standings[0] == ai1:
		print("[PASS] Test 4: Leaderboard Position Sorting (AI in 1st, Player in 2nd)")
		passed_tests += 1
	else:
		printerr("[FAIL] Test 4: Leaderboard sort failed! Player pos: %d" % player_pos)
		
	# Test 5: AI Navigation & Curvature Braking
	total_tests += 1
	var ai_driver = AIDriver.new()
	ai_driver.setup(ai1, track, "Viktor 'Rotor' Hale", "Aggressive")
	ai1.speed_kmh = 160.0
	ai_driver._physics_process(1.0 / 120.0)
	
	if ai_driver.current_waypoint_idx > 0 and ai_driver.target_speed_kmh < 180.0:
		print("[PASS] Test 5: AI Racing Line Navigation & Curvature Speed Profiling (Target: %.1f km/h)" % ai_driver.target_speed_kmh)
		passed_tests += 1
	else:
		printerr("[FAIL] Test 5: AI Driver navigation failed!")
		
	# Cleanup
	track.free()
	race_mgr.free()
	player.free()
	ai1.free()
	ai_driver.free()
	
	print("\n-------------------------------------------------------")
	print("STAGE 2 RESULTS: %d / %d TESTS PASSED" % [passed_tests, total_tests])
	print("-------------------------------------------------------\n")
	
	if passed_tests == total_tests:
		print("STAGE 2 ACCEPTANCE CHECKLIST: ALL PASS.\n")
		quit(0)
	else:
		printerr("STAGE 2 ACCEPTANCE FAILED.\n")
		quit(1)
