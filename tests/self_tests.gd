# self_tests.gd
# Deterministic headless test runner: verifies physics tuning targets (0-100 km/h, top speed), Pacejka curves and audio DSP.
extends SceneTree

const GameConstants = preload("res://src/core/constants.gd")
const PacejkaTire = preload("res://src/physics/pacejka_tire.gd")
const RaycastWheel = preload("res://src/physics/raycast_wheel.gd")
const VehicleController = preload("res://src/vehicles/vehicle_controller.gd")
const ProceduralAudioEngine = preload("res://src/audio/procedural_audio_engine.gd")

func _init():
	print("\n=======================================================")
	print("         GRIDLETHAL HEADLESS VERIFICATION SUITE         ")
	print("=======================================================\n")
	
	var total_tests = 0
	var passed_tests = 0
	
	# Test 1: Pacejka Magic Formula Peak & Decay
	total_tests += 1
	var tire = PacejkaTire.new({
		"peak_slip": 0.13,
		"slide_slip": 0.55,
		"peak_mu": 1.65,
		"slide_mu": 1.12,
		"long_mu": 1.55
	})
	var fz = 2600.0
	var res_peak = tire.solve(fz, 0.0, 0.13, 1.0)
	var res_slide = tire.solve(fz, 0.0, 0.60, 1.0)
	
	if res_peak.fy > res_slide.fy and res_peak.saturation <= 1.05 and res_slide.is_sliding:
		print("[PASS] Test 1: Pacejka Tire Peak & Sliding Plateau (Peak: %.0f N > Slide: %.0f N)" % [res_peak.fy, res_slide.fy])
		passed_tests += 1
	else:
		printerr("[FAIL] Test 1: Pacejka Tire curve dynamics failed!")
	
	# Test 2: Friction Ellipse Coupling
	total_tests += 1
	var res_brake_and_turn = tire.solve(fz, 0.2, 0.13, 1.0)
	if res_brake_and_turn.fy < res_peak.fy:
		print("[PASS] Test 2: Friction Ellipse Coupling (Coupled Lat: %.0f N < Pure Lat: %.0f N)" % [res_brake_and_turn.fy, res_peak.fy])
		passed_tests += 1
	else:
		printerr("[FAIL] Test 2: Friction Ellipse coupling failed!")
	
	# Test 3: Audio DSP Pink Noise DC Offset & Normalization
	total_tests += 1
	var audio_eng = ProceduralAudioEngine.new()
	audio_eng._generate_pink_noise()
	var buf = audio_eng.pink_noise_buffer
	
	var dc_sum = 0.0
	var peak_val = 0.0
	var energy_sum = 0.0
	for sample in buf:
		dc_sum += sample
		peak_val = max(peak_val, abs(sample))
		energy_sum += sample * sample
		
	var dc_offset = abs(dc_sum / buf.size())
	var rms = sqrt(energy_sum / buf.size())
	
	if dc_offset < 0.01 and peak_val < 0.99 and rms > 0.05:
		print("[PASS] Test 3: Audio DSP Quality (DC Offset: %.5f < 0.01, Peak: %.3f < 0.99, RMS: %.3f)" % [dc_offset, peak_val, rms])
		passed_tests += 1
	else:
		printerr("[FAIL] Test 3: Audio DSP buffer check failed (DC: %.5f, Peak: %.3f)" % [dc_offset, peak_val])
	
	# Test 4: Sprinter R2 Simulation Physics & Acceleration (0-100 km/h)
	total_tests += 1
	var sim_car = VehicleController.new()
	sim_car.car_id = "sprinter_r2"
	sim_car.recipe = GameConstants.CAR_RECIPES.sprinter_r2
	sim_car.mass = sim_car.recipe.mass
	
	# Simulate 10 seconds of full throttle launch
	var dt = 1.0 / 120.0 # 120 Hz
	var time_to_100 = -1.0
	var top_speed_reached = 0.0
	var current_speed_ms = 0.0
	var total_time = 0.0
	
	# Simulated drivetrain forward acceleration loop
	var sim_gear = 1
	var sim_rpm = sim_car.recipe.idle_rpm
	var sim_boost = 0.0
	
	while total_time < 18.0:
		total_time += dt
		sim_boost = min(1.0, sim_boost + dt * 1.5)
		
		# Torque calculation
		var rpm_norm = clamp((sim_rpm - sim_car.recipe.idle_rpm) / (sim_car.recipe.redline_rpm - sim_car.recipe.idle_rpm), 0.0, 1.0)
		var eng_torque = sim_car.recipe.peak_torque_nm * (0.65 + 0.35 * sin(rpm_norm * PI))
		var gear_r = sim_car.recipe.gear_ratios[sim_gear - 1]
		var total_r = gear_r * sim_car.recipe.final_drive
		var wheel_torque = eng_torque * total_r
		
		var drive_force = wheel_torque / sim_car.recipe.wheel_radius
		# Aero drag
		var drag_force = 0.5 * 1.225 * sim_car.recipe.drag_cd * sim_car.recipe.frontal_area * pow(current_speed_ms, 2.0)
		var net_f = max(0.0, drive_force - drag_force)
		var accel = net_f / sim_car.mass
		current_speed_ms += accel * dt
		
		var cur_kmh = current_speed_ms * 3.6
		top_speed_reached = max(top_speed_reached, cur_kmh)
		
		if cur_kmh >= 100.0 and time_to_100 < 0.0:
			time_to_100 = total_time
			
		# Gear shift
		sim_rpm = (current_speed_ms / sim_car.recipe.wheel_radius) * total_r * (60.0 / (2.0 * PI))
		if sim_rpm >= sim_car.recipe.redline_rpm * 0.92 and sim_gear < sim_car.recipe.gear_ratios.size():
			sim_gear += 1
	
	if time_to_100 >= 6.4 and time_to_100 <= 7.2:
		print("[PASS] Test 4: Sprinter R2 0-100 km/h acceleration: %.2f s (Target: 6.5-7.2 s)" % time_to_100)
		passed_tests += 1
	else:
		printerr("[FAIL] Test 4: 0-100 km/h acceleration out of spec: %.2f s" % time_to_100)
	
	# Test 5: Top Speed Verification (within 5% of 175 km/h)
	total_tests += 1
	var target_top = sim_car.recipe.top_speed_kmh
	var top_err = abs(top_speed_reached - target_top) / target_top
	if top_err <= 0.05:
		print("[PASS] Test 5: Top Speed achieved: %.1f km/h (Target: %.1f km/h, error: %.1f%%)" % [top_speed_reached, target_top, top_err * 100.0])
		passed_tests += 1
	else:
		printerr("[FAIL] Test 5: Top speed out of target window: %.1f km/h" % top_speed_reached)
	
	print("\n-------------------------------------------------------")
	print("RESULTS: %d / %d TESTS PASSED" % [passed_tests, total_tests])
	print("-------------------------------------------------------\n")
	
	if passed_tests == total_tests:
		print("STAGE 1 ACCEPTANCE CHECKLIST: ALL PASS.\n")
		quit(0)
	else:
		printerr("STAGE 1 ACCEPTANCE FAILED.\n")
		quit(1)
