# vehicle_controller.gd
# Advanced vehicle simulation: Rigid body dynamics, torque curves, automatic gearbox, turbo lag, nitro, and aero.
class_name VehicleController
extends RigidBody3D

const GameConstants = preload("res://src/core/constants.gd")
const RaycastWheel = preload("res://src/physics/raycast_wheel.gd")

@export var car_id: String = "sprinter_r2"
var recipe: Dictionary

# Drivetrain & Engine state
var engine_rpm: float = 900.0
var target_rpm: float = 900.0
var current_gear: int = 1 # 0 = Reverse, 1..N = Forward
var is_shifting: bool = false
var shift_timer: float = 0.0
var turbo_boost: float = 0.0 # 0.0 to 1.0 (spools under load)

# Input states (smoothed)
var throttle_input: float = 0.0
var brake_input: float = 0.0
var steer_input: float = 0.0
var handbrake_input: bool = false
var nitro_active: bool = false

# Dynamics stats
var speed_kmh: float = 0.0
var nitro_capacity: float = 100.0
var nitro_amount: float = 100.0
var health: float = 700.0
var max_health: float = 700.0
var is_wrecked: bool = false
var respawn_timer: float = 0.0
var has_revenge_against = null

# Rollover timer
var upside_down_timer: float = 0.0
var is_flipped: bool = false

# Wheels array
var wheels: Array[RaycastWheel] = []
var front_left_wheel: RaycastWheel
var front_right_wheel: RaycastWheel
var rear_left_wheel: RaycastWheel
var rear_right_wheel: RaycastWheel

# Node references
var car_mesh_instance: Node3D

func _ready():
	recipe = GameConstants.CAR_RECIPES[car_id]
	mass = recipe.mass
	health = recipe.health
	max_health = recipe.health
	
	# Calculate rectangular box inertia tensor
	var lx = recipe.track_width
	var ly = 1.35
	var lz = recipe.wheelbase + 1.2
	var ix = (1.0 / 12.0) * mass * (ly * ly + lz * lz)
	var iy = (1.0 / 12.0) * mass * (lx * lx + lz * lz)
	var iz = (1.0 / 12.0) * mass * (lx * lx + ly * ly)
	inertia = Vector3(ix, iy, iz)
	
	# Setup 4 raycast wheels
	_setup_wheels()

func _setup_wheels():
	var wb_half = recipe.wheelbase * 0.5
	var tw_half = recipe.track_width * 0.5
	var y_offset = 0.0
	
	front_left_wheel = _create_wheel(Vector3(-tw_half, y_offset, -wb_half), true, true)
	front_right_wheel = _create_wheel(Vector3(tw_half, y_offset, -wb_half), true, false)
	rear_left_wheel = _create_wheel(Vector3(-tw_half, y_offset, wb_half), false, true)
	rear_right_wheel = _create_wheel(Vector3(tw_half, y_offset, wb_half), false, false)
	
	# Pair opposite wheels for anti-roll bars
	front_left_wheel.opposite_wheel = front_right_wheel
	front_right_wheel.opposite_wheel = front_left_wheel
	rear_left_wheel.opposite_wheel = rear_right_wheel
	rear_right_wheel.opposite_wheel = rear_left_wheel
	
	wheels = [front_left_wheel, front_right_wheel, rear_left_wheel, rear_right_wheel]

func _create_wheel(rel_pos: Vector3, is_f: bool, is_l: bool) -> RaycastWheel:
	var w = RaycastWheel.new()
	w.position = rel_pos
	w.is_front = is_f
	w.is_left = is_l
	add_child(w)
	w.setup(recipe.suspension, recipe.tire)
	return w

func _physics_process(delta: float):
	speed_kmh = linear_velocity.length() * 3.6
	
	# 1. Process Inputs & Smoothing
	_process_inputs(delta)
	
	# 2. Transmission & Drivetrain
	_update_drivetrain(delta)
	
	# 3. Aerodynamics (Drag & Downforce)
	_apply_aerodynamics()
	
	# 4. Wheel Simulation & Contact Forces
	var ground_contact_count = 0
	for w in wheels:
		var wheel_force = w.update_suspension(self, delta)
		apply_force(wheel_force, w.global_position - global_position)
		if w.is_grounded:
			ground_contact_count += 1
	
	# 5. Rollover Check
	var up_dot = global_transform.basis.y.dot(Vector3.UP)
	if up_dot < 0.2 and ground_contact_count == 0:
		upside_down_timer += delta
		if upside_down_timer >= 3.0:
			is_flipped = true
	else:
		upside_down_timer = 0.0
		is_flipped = false

func _process_inputs(delta: float):
	var raw_throttle = Input.get_action_strength("throttle")
	var raw_brake = Input.get_action_strength("brake")
	var raw_steer = Input.get_action_strength("steer_left") - Input.get_action_strength("steer_right")
	handbrake_input = Input.is_action_pressed("handbrake")
	
	# Smooth inputs
	throttle_input = move_toward(throttle_input, raw_throttle, delta * 6.0)
	brake_input = move_toward(brake_input, raw_brake, delta * 8.0)
	
	# Speed-sensitive steering lock (decreases at high speed to maintain stability)
	var max_steer_rad = deg_to_rad(clamp(34.0 - (speed_kmh * 0.12), 12.0, 34.0))
	var target_steer = raw_steer * max_steer_rad
	steer_input = move_toward(steer_input, target_steer, delta * 5.0)
	
	# Apply steering to front wheels
	front_left_wheel.steer_angle = steer_input
	front_right_wheel.steer_angle = steer_input
	
	# Nitro system
	if Input.is_action_pressed("nitro") and nitro_amount > 0.0:
		nitro_active = true
		nitro_amount = max(0.0, nitro_amount - delta * 25.0)
	else:
		nitro_active = false
		nitro_amount = min(nitro_capacity, nitro_amount + delta * 5.0)
	
	# Flip recovery
	if Input.is_action_just_pressed("reset_car") and is_flipped:
		self_right_car()

func _update_drivetrain(delta: float):
	# Turbo lag spool model
	if throttle_input > 0.3:
		turbo_boost = move_toward(turbo_boost, 1.0, delta * 1.5)
	else:
		turbo_boost = move_toward(turbo_boost, 0.0, delta * 3.0)
	
	# Torque curve calculation based on current RPM
	var rpm_norm = clamp((engine_rpm - recipe.idle_rpm) / (recipe.redline_rpm - recipe.idle_rpm), 0.0, 1.0)
	var torque_factor = sin(rpm_norm * PI) # Peak torque at mid-range
	var engine_torque = recipe.peak_torque_nm * (0.6 + 0.4 * torque_factor) * throttle_input
	
	# Nitro boost multiplier
	if nitro_active:
		engine_torque *= 1.8
	
	# Shift logic
	if is_shifting:
		shift_timer -= delta
		if shift_timer <= 0.0:
			is_shifting = false
		engine_torque *= 0.1 # Cut torque during gear shifts
	else:
		# Auto-upshift
		if engine_rpm > recipe.redline_rpm * 0.92 and current_gear < recipe.gear_ratios.size():
			current_gear += 1
			is_shifting = true
			shift_timer = recipe.shift_time_ms / 1000.0
		# Auto-downshift
		elif engine_rpm < recipe.idle_rpm * 1.6 and current_gear > 1:
			current_gear -= 1
			is_shifting = true
			shift_timer = recipe.shift_time_ms / 1000.0
	
	# Compute wheel drive torque via transmission & final drive
	var gear_ratio = recipe.gear_ratios[current_gear - 1]
	var total_ratio = gear_ratio * recipe.final_drive
	var axle_torque = engine_torque * total_ratio
	
	# AWD split
	var front_torque = axle_torque * recipe.torque_split * 0.5
	var rear_torque = axle_torque * (1.0 - recipe.torque_split) * 0.5
	
	front_left_wheel.drive_torque = front_torque
	front_right_wheel.drive_torque = front_torque
	rear_left_wheel.drive_torque = rear_torque
	rear_right_wheel.drive_torque = rear_torque
	
	# Braking torque with front bias (65% front, 35% rear)
	var max_brake_nm = 3800.0
	front_left_wheel.brake_torque = brake_input * max_brake_nm * 0.65 * 0.5
	front_right_wheel.brake_torque = brake_input * max_brake_nm * 0.65 * 0.5
	rear_left_wheel.brake_torque = brake_input * max_brake_nm * 0.35 * 0.5
	rear_right_wheel.brake_torque = brake_input * max_brake_nm * 0.35 * 0.5
	
	# Handbrake locks rear wheels and reduces lateral grip for drifting
	if handbrake_input:
		rear_left_wheel.brake_torque += max_brake_nm * 1.5
		rear_right_wheel.brake_torque += max_brake_nm * 1.5
		rear_left_wheel.handbrake_factor = 0.35
		rear_right_wheel.handbrake_factor = 0.35
	else:
		rear_left_wheel.handbrake_factor = 1.0
		rear_right_wheel.handbrake_factor = 1.0
	
	# Calculate simulated engine RPM from driven wheels speed
	var avg_wheel_rad_s = (rear_left_wheel.wheel_angular_velocity + rear_right_wheel.wheel_angular_velocity) * 0.5
	var driven_rpm = abs(avg_wheel_rad_s * total_ratio * (60.0 / (2.0 * PI)))
	target_rpm = max(recipe.idle_rpm, driven_rpm)
	if throttle_input > 0.0 and avg_wheel_rad_s < 2.0:
		target_rpm = max(target_rpm, recipe.idle_rpm + throttle_input * 2500.0) # Free rev when stalled/launching
	
	engine_rpm = move_toward(engine_rpm, clamp(target_rpm, recipe.idle_rpm, recipe.redline_rpm), delta * 5000.0)

func _apply_aerodynamics():
	var v = linear_velocity
	var v_sq = v.length_squared()
	if v_sq < 1.0:
		return
	
	# Drag = 0.5 * rho * Cd * A * v^2
	var rho = 1.225 # Air density kg/m3
	var drag_mag = 0.5 * rho * recipe.drag_cd * recipe.frontal_area * v_sq
	var drag_vec = -v.normalized() * drag_mag
	apply_central_force(drag_vec)
	
	# Downforce = 0.5 * rho * Cl * A * v^2
	var downforce_mag = 0.5 * rho * recipe.downforce_factor * recipe.frontal_area * v_sq
	apply_central_force(Vector3.DOWN * downforce_mag)

func self_right_car():
	global_rotation = Vector3(0, global_rotation.y, 0)
	global_position.y += 1.0
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	is_flipped = false
	upside_down_timer = 0.0

func apply_damage(amount: float, hit_point: Vector3, attacker = null):
	if is_wrecked:
		return
	health = max(0.0, health - amount)
	
	# Apply vertex dent to mesh
	if car_mesh_instance and car_mesh_instance.has_method("apply_dent"):
		var local_hit = car_mesh_instance.global_transform.affine_inverse() * hit_point
		car_mesh_instance.apply_dent(local_hit, amount * 25.0)
		
	# Revenge system: if player damages this AI, set revenge target
	if attacker and attacker != self:
		has_revenge_against = attacker
		
	if health <= 0.0:
		_wreck_car()

func _wreck_car():
	is_wrecked = true
	respawn_timer = 3.0
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	
	# Darken mesh into charred wreck
	if car_mesh_instance and car_mesh_instance.body_mesh_instance:
		var wreck_mat = StandardMaterial3D.new()
		wreck_mat.albedo_color = Color(0.05, 0.05, 0.05)
		wreck_mat.roughness = 0.95
		car_mesh_instance.body_mesh_instance.material_override = wreck_mat

func apply_repair(amount: float):
	health = min(max_health, health + amount)
	if health > 0.0 and is_wrecked:
		is_wrecked = false
