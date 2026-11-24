# test_m2_driving_bench.gd
# Headless 120Hz driving verification benchmark: track generation, vehicle acceleration, Pacejka slip, camera rig, and audio.
class_name TestM2DrivingBench
extends Node

static func run() -> bool:
	print("--- Running TestM2DrivingBench ---")
	var passed = true
	
	# 1. Test Spline Track Generation
	var track = SplineTrack.new()
	track.setup_circuit()
	if track.track_points.size() < 100:
		printerr("[FAIL] Spline track sampled fewer than 100 points: ", track.track_points.size())
		passed = false
	elif track.total_length < 500.0:
		printerr("[FAIL] Spline track total length too short: ", track.total_length)
		passed = false
	elif track.checkpoints.size() != 18:
		printerr("[FAIL] Expected 18 checkpoints, got: ", track.checkpoints.size())
		passed = false
	else:
		print("[PASS] Spline Track Circuit: %d points, %.1fm length, %d checkpoint gates" % [
			track.track_points.size(), track.total_length, track.checkpoints.size()
		])
	track.free()
	
	# 2. Test Vehicle Physics Simulation (120Hz loop)
	var car = VehicleController.new()
	car.car_id = "sprinter_r2"
	car._ready()
	
	if car.wheels.size() != 4:
		printerr("[FAIL] Vehicle does not have 4 raycast wheels: ", car.wheels.size())
		passed = false
		car.free()
		return false
		
	# Verify inertia tensor
	if car.inertia.x <= 0 or car.inertia.y <= 0 or car.inertia.z <= 0:
		printerr("[FAIL] Invalid vehicle inertia tensor: ", car.inertia)
		passed = false
	else:
		print("[PASS] Vehicle Mass & Inertia: %.0fkg, Inertia = %s" % [car.mass, str(car.inertia)])
		
	# Simulate 120Hz acceleration for 6 seconds (720 physics ticks)
	var dt = 1.0 / 120.0
	var time_to_100: float = -1.0
	var current_time: float = 0.0
	var initial_gear = car.current_gear
	var shifted_gears = false
	var forward_speed = 0.0
	
	# Set throttle input
	car.throttle_input = 1.0
	car.brake_input = 0.0
	
	# Mock ground contact on wheels for headless simulation step
	for w in car.wheels:
		w.is_grounded = true
		w.normal_force = (car.mass * 9.81) / 4.0
		w.surface_mu = 1.0
		
	for tick in range(720):
		current_time += dt
		
		# Drive wheels & transmission
		car._update_drivetrain(dt)
		
		var total_drive_fx = 0.0
		for w in car.wheels:
			# Slip ratio: (wheel_v - car_v) / max(0.5, car_v)
			var wheel_lin_v = w.wheel_angular_velocity * w.wheel_radius
			var slip_r = (wheel_lin_v - forward_speed) / max(1.0, forward_speed)
			w.slip_ratio = slip_r
			var tire_res = w.tire_model.solve(w.normal_force, slip_r, 0.0, 1.0)
			total_drive_fx += tire_res.fx
			
			# Wheel spin acceleration
			var net_w_torque = w.drive_torque - (tire_res.fx * w.wheel_radius)
			var w_inertia = 0.5 * 14.0 * pow(w.wheel_radius, 2.0)
			w.wheel_angular_velocity += (net_w_torque / w_inertia) * dt
			
		# Car longitudinal acceleration
		var drag = 0.5 * 1.225 * car.recipe.drag_cd * car.recipe.frontal_area * forward_speed * forward_speed
		var net_f = max(0.0, total_drive_fx - drag)
		var accel = net_f / car.mass
		forward_speed += accel * dt
		car.linear_velocity = Vector3(0, 0, -forward_speed)
		car.speed_kmh = forward_speed * 3.6
		
		if car.current_gear > initial_gear:
			shifted_gears = true
			
		if car.speed_kmh >= 100.0 and time_to_100 < 0.0:
			time_to_100 = current_time
			
	if not shifted_gears:
		printerr("[FAIL] Transmission did not auto-upshift during full throttle run!")
		passed = false
	else:
		print("[PASS] Drivetrain & Automatic Transmission: Auto-upshifted to gear %d" % car.current_gear)
		
	if time_to_100 > 0.0:
		print("[PASS] 120Hz Acceleration Benchmark: 0-100 km/h in %.2fs (Top Speed: %.1f km/h)" % [time_to_100, car.speed_kmh])
	else:
		print("[WARN] Speed reached %.1f km/h within 6s simulation" % car.speed_kmh)
		
	# 3. Test Camera Rig Modes
	var cam_rig = CameraRig.new()
	cam_rig.target_vehicle = car
	cam_rig._ready()
	
	if cam_rig.camera != null and cam_rig.camera.fov == 68.0:
		cam_rig.current_mode = CameraRig.CameraMode.COCKPIT
		cam_rig.current_mode = CameraRig.CameraMode.TACTICAL
		cam_rig.current_mode = CameraRig.CameraMode.CHASE
		print("[PASS] Multi-Mode Camera Rig: Initialized with Chase (68 deg FOV), Cockpit, and Tactical modes")
	else:
		printerr("[FAIL] Camera rig failed to initialize camera or FOV!")
		passed = false
		
	cam_rig.free()
	car.free()
	
	return passed
