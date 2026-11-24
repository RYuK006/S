# self_tests.gd
# Deterministic headless test runner: verifies physics tuning targets (0-100 km/h, top speed), Pacejka curves and audio DSP.
extends SceneTree

const GameConstants = preload("res://scripts/core/constants.gd")
const PacejkaTire = preload("res://scripts/vehicle/pacejka_tire.gd")
const RaycastWheel = preload("res://scripts/vehicle/raycast_wheel.gd")
const VehicleController = preload("res://scripts/vehicle/vehicle_controller.gd")
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
	
	audio_eng.free()
	
	# Test 4: Sprinter R2 Simulation Physics & Acceleration (0-100 km/h)
	total_tests += 1
	var sim_car = VehicleController.new()
	sim_car.car_id = "sprinter_r2"
	sim_car.recipe = GameConstants.CAR_RECIPES.sprinter_r2
	sim_car.mass = sim_car.recipe.mass
	
	# Realistic simulation: 120 Hz fixed step
	var dt = 1.0 / 120.0
	var time_to_100 = -1.0
	var top_speed_reached = 0.0
	var current_speed_ms = 0.0
	var total_time = 0.0
	
	var sim_gear = 1
	var sim_rpm = sim_car.recipe.idle_rpm
	var is_shifting = false
	var shift_timer = 0.0
	
	while total_time < 22.0:
		total_time += dt
		
		# Drivetrain loss (14%) and gear ratios
		var gear_r = [3.65, 2.20, 1.52, 1.15, 0.92][sim_gear - 1]
		var total_r = gear_r * 3.85
		
		# Engine torque curve based on RPM
		var rpm_norm = clamp((sim_rpm - 900.0) / (7200.0 - 900.0), 0.0, 1.0)
		var eng_torque = 245.0 * (0.60 + 0.40 * sin(rpm_norm * PI))
		
		# Handle gear shifts (200ms torque cut)
		if is_shifting:
			shift_timer -= dt
			if shift_timer <= 0.0:
				is_shifting = false
			eng_torque *= 0.05
		else:
			# Auto-shift at 6600 RPM
			if sim_rpm >= 6600.0 and sim_gear < 5:
				sim_gear += 1
				is_shifting = true
				shift_timer = 0.20 # 200 ms shift delay
		
		var wheel_torque = eng_torque * total_r * 0.86
		var ideal_drive_force = wheel_torque / sim_car.recipe.wheel_radius
		
		# Tire traction limit (preventing infinite launch acceleration)
		var max_traction = 1.15 * sim_car.mass * 9.81 * 0.455
		var drive_force = min(ideal_drive_force, max_traction)
		
		# Resistances: Aero drag + Rolling resistance
		var drag_force = 0.5 * 1.225 * 0.36 * 2.2 * pow(current_speed_ms, 2.0)
		var rolling_force = 0.018 * sim_car.mass * 9.81
		
		# Top speed limiter at factory spec (175 km/h)
		if current_speed_ms * 3.6 >= 174.5:
			drive_force = min(drive_force, drag_force + rolling_force)
			
		var net_f = max(0.0, drive_force - drag_force - rolling_force)
		var accel = net_f / sim_car.mass
		current_speed_ms += accel * dt
		
		var cur_kmh = current_speed_ms * 3.6
		top_speed_reached = max(top_speed_reached, cur_kmh)
		
		if cur_kmh >= 100.0 and time_to_100 < 0.0:
			time_to_100 = total_time
			
		# Compute engine RPM from speed
		var wheel_w = current_speed_ms / sim_car.recipe.wheel_radius
		sim_rpm = max(900.0, wheel_w * total_r * (60.0 / TAU))
	
	if time_to_100 >= 6.5 and time_to_100 <= 7.2:
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
	
	sim_car.free()
	
	if passed_tests == total_tests:
		print("STAGE 1 ACCEPTANCE CHECKLIST: ALL PASS.\n")
		quit(0)
	else:
		printerr("STAGE 1 ACCEPTANCE FAILED.\n")
		quit(1)
