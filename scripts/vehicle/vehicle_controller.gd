# vehicle_controller.gd
# Advanced vehicle simulation: Rigid body dynamics, torque curves, automatic gearbox, turbo lag, nitro, and aero.
class_name VehicleController
extends RigidBody3D

const GameConstants = preload("res://scripts/core/constants.gd")
const RaycastWheel = preload("res://scripts/vehicle/raycast_wheel.gd")
const ProceduralCarMesh = preload("res://scripts/vehicle/procedural_car_mesh.gd")

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
	recipe = _load_recipe()
	mass = recipe.mass
	health = recipe.health
	max_health = recipe.health
	
	# Calculate rectangular box inertia tensor
	var lx: float = recipe.track_width
	var ly: float = 1.35
	var lz: float = recipe.wheelbase + 1.2
	var ix = (1.0 / 12.0) * mass * (ly * ly + lz * lz)
	var iy = (1.0 / 12.0) * mass * (lx * lx + lz * lz)
	var iz = (1.0 / 12.0) * mass * (lx * lx + ly * ly)
	inertia = Vector3(ix, iy, iz)
	
	# Chassis collision
	_setup_chassis_collision()
	
	# Setup 4 raycast wheels
	_setup_wheels()
	
	# Setup visual model & bind wheels
	_setup_visual_model()

func _load_recipe() -> Dictionary:
	var base_recipe: Dictionary = GameConstants.CAR_RECIPES.get("sprinter_r2", {}).duplicate(true)
	if FileAccess.file_exists("res://data/vehicles.json"):
		var f = FileAccess.open("res://data/vehicles.json", FileAccess.READ)
		if f:
			var json_obj = JSON.parse_string(f.get_as_text())
			if json_obj is Dictionary and json_obj.has("vehicles"):
				for v in json_obj.vehicles:
					if v.get("id") == car_id:
						if v.has("name"): base_recipe["name"] = v.name
						if v.has("mass"): base_recipe["mass"] = float(v.mass)
						if v.has("max_torque_nm"): base_recipe["peak_torque_nm"] = float(v.max_torque_nm)
						if v.has("idle_rpm"): base_recipe["idle_rpm"] = float(v.idle_rpm)
						if v.has("redline_rpm"): base_recipe["redline_rpm"] = float(v.redline_rpm)
						if v.has("gear_ratios"): base_recipe["gear_ratios"] = v.gear_ratios
						if v.has("final_drive"): base_recipe["final_drive"] = float(v.final_drive)
						if v.has("wheelbase"): base_recipe["wheelbase"] = float(v.wheelbase)
						if v.has("track_width"): base_recipe["track_width"] = float(v.track_width)
						if v.has("drag_coeff"): base_recipe["drag_cd"] = float(v.drag_coeff)
						if v.has("frontal_area"): base_recipe["frontal_area"] = float(v.frontal_area)
						if v.has("health"): base_recipe["health"] = float(v.health)
						if v.has("tire_params") and base_recipe.has("tire"):
							for tk in v.tire_params:
								base_recipe.tire[tk] = float(v.tire_params[tk])
						if v.has("model_path"): base_recipe["model_path"] = v.model_path
						return base_recipe
	if GameConstants.CAR_RECIPES.has(car_id):
		return GameConstants.CAR_RECIPES[car_id]
	return base_recipe

func _setup_chassis_collision():
	var col_shape = CollisionShape3D.new()
	var box = BoxShape3D.new()
	var tw: float = recipe.get("track_width", 1.76)
	var wb: float = recipe.get("wheelbase", 2.45)
	box.size = Vector3(tw + 0.15, 0.75, wb + 1.4)
	col_shape.shape = box
	col_shape.position = Vector3(0, 0.55, 0)
	add_child(col_shape)

func _setup_visual_model():
	var glb_path = "res://assets/models/cars/CarConcept.glb"
	if recipe.has("model_path") and FileAccess.file_exists(recipe.model_path):
		glb_path = recipe.model_path
		
	var loaded_model: Node3D = null
	if FileAccess.file_exists(glb_path):
		var gltf = GLTFDocument.new()
		var state = GLTFState.new()
		var err = gltf.append_from_file(glb_path, state)
		if err == OK:
			loaded_model = gltf.generate_scene(state) as Node3D
			
	if loaded_model:
		car_mesh_instance = loaded_model
		# Rotate 180 degrees around Y so the hood and headlights point forward (-Z)
		loaded_model.rotation.y = PI
		add_child(car_mesh_instance)
		_bind_model_wheels(loaded_model)
	else:
		var proc = ProceduralCarMesh.new()
		car_mesh_instance = proc.build_car(recipe)
		add_child(car_mesh_instance)
		_bind_model_wheels(proc)

func _find_child_recursive(node: Node, names: Array[String]) -> Node3D:
	for n in names:
		if node.name.nocasecmp_to(n) == 0:
			return node as Node3D
	for child in node.get_children():
		var res = _find_child_recursive(child, names)
		if res:
			return res
	return null

func _bind_model_wheels(root: Node3D):
	var fl = _find_child_recursive(root, ["WheelFrontL", "wheel_FL", "Wheel_FL"])
	var fr = _find_child_recursive(root, ["WheelFrontR", "wheel_FR", "Wheel_FR"])
	var rl = _find_child_recursive(root, ["WheelRearL", "wheel_RL", "Wheel_RL"])
	var rr = _find_child_recursive(root, ["WheelRearR", "wheel_RR", "Wheel_RR"])
	
	if fl: _attach_wheel_visual(front_left_wheel, fl)
	if fr: _attach_wheel_visual(front_right_wheel, fr)
	if rl: _attach_wheel_visual(rear_left_wheel, rl)
	if rr: _attach_wheel_visual(rear_right_wheel, rr)

func _attach_wheel_visual(wheel: RaycastWheel, visual_node: Node3D):
	visual_node.owner = null
	if visual_node.get_parent():
		visual_node.get_parent().remove_child(visual_node)
	wheel.add_child(visual_node)
	visual_node.position = Vector3(0, -wheel.rest_length, 0)
	visual_node.rotation = Vector3.ZERO
	wheel.wheel_visual = visual_node

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
	
	# Shift logic & Forward/Reverse transition
	var fwd_dir: Vector3 = -global_transform.basis.z if is_inside_tree() else -transform.basis.z
	var forward_vel: float = fwd_dir.dot(linear_velocity)
	var rev_ratio: float = float(recipe.get("reverse_ratio", 3.4))
	
	if is_shifting:
		shift_timer -= delta
		if shift_timer <= 0.0:
			is_shifting = false
		engine_torque *= 0.1 # Cut torque during gear shifts
	else:
		if current_gear == 0:
			# Currently in REVERSE:
			# Shift to 1st gear if player presses throttle and car has stopped reversing
			if throttle_input > 0.2 and forward_vel > -0.6:
				current_gear = 1
				is_shifting = true
				shift_timer = 0.15
		else:
			# Currently in FORWARD gear (1..N):
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
			# Shift to Reverse if player holds brake and car is stopped or nearly stopped
			elif brake_input > 0.3 and forward_vel < 0.6 and throttle_input < 0.1:
				current_gear = 0
				is_shifting = true
				shift_timer = 0.15
	
	var max_brake_nm: float = 3800.0
	
	if current_gear == 0:
		# REVERSE DRIVETRAIN:
		# In reverse, brake_input acts as reverse throttle to propel the vehicle backward
		var rev_throttle := brake_input
		var rev_engine_torque: float = recipe.peak_torque_nm * (0.6 + 0.4 * torque_factor) * rev_throttle
		if is_shifting:
			rev_engine_torque *= 0.1
		var rev_total_ratio: float = rev_ratio * recipe.final_drive
		var rev_axle_torque: float = -rev_engine_torque * rev_total_ratio
		
		var front_torque: float = rev_axle_torque * recipe.torque_split * 0.5
		var rear_torque: float = rev_axle_torque * (1.0 - recipe.torque_split) * 0.5
		front_left_wheel.drive_torque = front_torque
		front_right_wheel.drive_torque = front_torque
		rear_left_wheel.drive_torque = rear_torque
		rear_right_wheel.drive_torque = rear_torque
		
		# Throttle input acts as brake when in reverse
		var rev_brake: float = throttle_input * max_brake_nm
		front_left_wheel.brake_torque = rev_brake * 0.65 * 0.5
		front_right_wheel.brake_torque = rev_brake * 0.65 * 0.5
		rear_left_wheel.brake_torque = rev_brake * 0.35 * 0.5
		rear_right_wheel.brake_torque = rev_brake * 0.35 * 0.5
		
		# Simulated engine RPM in reverse
		var avg_wheel_rad_s: float = (abs(rear_left_wheel.wheel_angular_velocity) + abs(rear_right_wheel.wheel_angular_velocity)) * 0.5
		var driven_rpm: float = abs(avg_wheel_rad_s * rev_total_ratio * (60.0 / (2.0 * PI)))
		target_rpm = max(recipe.idle_rpm, driven_rpm)
		if brake_input > 0.0 and avg_wheel_rad_s < 2.0:
			target_rpm = max(target_rpm, recipe.idle_rpm + brake_input * 2500.0)
	else:
		# FORWARD DRIVETRAIN (1..N):
		var gear_ratio: float = recipe.gear_ratios[current_gear - 1]
		var total_ratio: float = gear_ratio * recipe.final_drive
		var axle_torque: float = engine_torque * total_ratio
		
		# AWD split
		var front_torque: float = axle_torque * recipe.torque_split * 0.5
		var rear_torque: float = axle_torque * (1.0 - recipe.torque_split) * 0.5
		front_left_wheel.drive_torque = front_torque
		front_right_wheel.drive_torque = front_torque
		rear_left_wheel.drive_torque = rear_torque
		rear_right_wheel.drive_torque = rear_torque
		
		# Braking torque with front bias (65% front, 35% rear)
		front_left_wheel.brake_torque = brake_input * max_brake_nm * 0.65 * 0.5
		front_right_wheel.brake_torque = brake_input * max_brake_nm * 0.65 * 0.5
		rear_left_wheel.brake_torque = brake_input * max_brake_nm * 0.35 * 0.5
		rear_right_wheel.brake_torque = brake_input * max_brake_nm * 0.35 * 0.5
		
		# Calculate simulated engine RPM from driven wheels speed
		var avg_wheel_rad_s := (rear_left_wheel.wheel_angular_velocity + rear_right_wheel.wheel_angular_velocity) * 0.5
		var driven_rpm: float = abs(avg_wheel_rad_s * total_ratio * (60.0 / (2.0 * PI)))
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
	if car_mesh_instance and "body_mesh_instance" in car_mesh_instance and car_mesh_instance.body_mesh_instance:
		var wreck_mat = StandardMaterial3D.new()
		wreck_mat.albedo_color = Color(0.05, 0.05, 0.05)
		wreck_mat.roughness = 0.95
		car_mesh_instance.body_mesh_instance.material_override = wreck_mat

func apply_repair(amount: float):
	health = min(max_health, health + amount)
	if health > 0.0 and is_wrecked:
		is_wrecked = false
