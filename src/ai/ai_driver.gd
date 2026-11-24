# ai_driver.gd
# Autonomous racing AI: spline racing lines, curvature-based braking, collision avoidance and personality profiles.
class_name AIDriver
extends Node

const VehicleController = preload("res://src/vehicles/vehicle_controller.gd")
const SplineTrack = preload("res://src/tracks/spline_track.gd")

@export var driver_name: String = "Viktor 'Rotor' Hale"
@export var personality: String = "Aggressive" # Aggressive, Tactical, Bully, Drifter, Trickster
@export var skill_rating: float = 0.95        # 0.8 to 1.1

var car: VehicleController
var track: SplineTrack

# Navigation state
var current_waypoint_idx: int = 0
var target_speed_kmh: float = 120.0
var stuck_timer: float = 0.0
var is_reversing: bool = false
var reverse_timer: float = 0.0

# Aggression & Personality parameters
var corner_aggression: float = 1.05
var braking_distance_scale: float = 0.90
var lane_offset: float = 0.0 # Lateral offset from track center (-1.0 to 1.0)

func setup(vehicle: VehicleController, spline_track: SplineTrack, p_name: String, p_style: String):
	car = vehicle
	track = spline_track
	driver_name = p_name
	personality = p_style
	
	match personality:
		"Aggressive":
			corner_aggression = 1.12
			braking_distance_scale = 0.82
			lane_offset = -0.2
		"Tactical":
			corner_aggression = 1.00
			braking_distance_scale = 1.05
			lane_offset = 0.0
		"Bully":
			corner_aggression = 1.08
			braking_distance_scale = 0.88
			lane_offset = 0.3
		"Drifter":
			corner_aggression = 1.15
			braking_distance_scale = 0.80
			lane_offset = -0.1
		_:
			corner_aggression = 1.00
			braking_distance_scale = 1.00

func _physics_process(delta: float):
	if not car or not track or track.track_points.is_empty():
		return
		
	# Check if upside down and trigger flip recovery
	if car.is_flipped:
		car.self_right_car()
		return
		
	# 1. Stuck / Collision Detection
	if car.speed_kmh < 10.0 and car.throttle_input > 0.5:
		stuck_timer += delta
		if stuck_timer > 2.0:
			is_reversing = true
			reverse_timer = 1.5
			stuck_timer = 0.0
	else:
		stuck_timer = max(0.0, stuck_timer - delta)
		
	if is_reversing:
		reverse_timer -= delta
		if reverse_timer <= 0.0:
			is_reversing = false
		_apply_reverse_controls()
		return
		
	# 2. Waypoint & Racing Line Target
	_update_target_waypoint()
	
	# 3. Steering & Curvature-Based Speed Profiling
	_drive_towards_waypoint(delta)

func _update_target_waypoint():
	var num_pts = track.track_points.size()
	var car_pos = car.global_position
	
	# Look ahead proportional to speed
	var lookahead_steps = int(clamp(car.speed_kmh * 0.12, 6.0, 22.0))
	var best_idx = current_waypoint_idx
	var best_d_sq = 1e9
	
	# Search forward from current waypoint
	for offset in range(-4, 12):
		var idx = (current_waypoint_idx + offset + num_pts) % num_pts
		var d_sq = track.track_points[idx].pos.distance_squared_to(car_pos)
		if d_sq < best_d_sq:
			best_d_sq = d_sq
			best_idx = idx
			
	current_waypoint_idx = (best_idx + lookahead_steps) % num_pts

func _drive_towards_waypoint(delta: float):
	var target_pt = track.track_points[current_waypoint_idx]
	var target_pos = target_pt.pos + (target_pt.right * (lane_offset * target_pt.width * 0.35))
	
	# Compute local angle to target point
	var car_trans = car.global_transform
	var local_target = car_trans.affine_inverse() * target_pos
	var angle_to_target = atan2(local_target.x, -local_target.z)
	
	# Steer towards target
	var steer = clamp(angle_to_target * 1.8, -1.0, 1.0)
	car.steer_input = move_toward(car.steer_input, steer, delta * 6.0)
	if car.front_left_wheel:
		car.front_left_wheel.steer_angle = car.steer_input * deg_to_rad(28.0)
	if car.front_right_wheel:
		car.front_right_wheel.steer_angle = car.steer_input * deg_to_rad(28.0)
	
	# Curvature profile: compute track angle deviation further ahead
	var num_pts = track.track_points.size()
	var curve_lookahead_idx = (current_waypoint_idx + 8) % num_pts
	var ahead_pt = track.track_points[curve_lookahead_idx]
	var track_turn_angle = abs(target_pt.forward.angle_to(ahead_pt.forward))
	
	# Target speed based on corner tightness and personality
	var safe_corner_speed = clamp(180.0 - (track_turn_angle * 120.0), 55.0, 175.0) * corner_aggression * skill_rating
	target_speed_kmh = safe_corner_speed
	
	# Drifter style: tap handbrake if entering sharp corner at speed
	if personality == "Drifter" and track_turn_angle > 0.45 and car.speed_kmh > 75.0:
		car.handbrake_input = true
	else:
		car.handbrake_input = false
	
	# Throttle / Brake decisions
	if car.speed_kmh < target_speed_kmh:
		car.throttle_input = 1.0
		car.brake_input = 0.0
		# Use nitro on straightaways if trailing
		if track_turn_angle < 0.15 and car.speed_kmh > 100.0 and car.nitro_amount > 40.0:
			car.nitro_active = true
		else:
			car.nitro_active = false
	else:
		var speed_excess = car.speed_kmh - target_speed_kmh
		car.throttle_input = 0.0
		car.brake_input = clamp(speed_excess * 0.06 * braking_distance_scale, 0.2, 1.0)
		car.nitro_active = false

func _apply_reverse_controls():
	car.throttle_input = 0.0
	car.brake_input = 1.0 # In automatic gearbox, brake triggers reverse when stopped
	car.steer_input = -0.8
	car.front_left_wheel.steer_angle = car.steer_input * deg_to_rad(28.0)
	car.front_right_wheel.steer_angle = car.steer_input * deg_to_rad(28.0)
