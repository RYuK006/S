# raycast_wheel.gd
# 4-corner raycast suspension with bump/rebound damping, bump stops, and anti-roll bar coupling.
class_name RaycastWheel
extends Node3D

const GameConstants = preload("res://scripts/core/constants.gd")
const PacejkaTire = preload("res://scripts/vehicle/pacejka_tire.gd")

@export var is_front: bool = false
@export var is_left: bool = true

# Wheel & Suspension Parameters
var rest_length: float = 0.38
var travel: float = 0.18
var spring_rate: float = 28000.0     # N/m
var damping_bump: float = 2400.0     # N.s/m
var damping_rebound: float = 3600.0  # N.s/m
var anti_roll_rate: float = 6500.0   # N/rad
var wheel_radius: float = 0.32
var wheel_width: float = 0.22

# State variables
var is_grounded: bool = false
var contact_point: Vector3 = Vector3.ZERO
var contact_normal: Vector3 = Vector3.UP
var compression: float = 0.0          # 0.0 = fully extended, travel = fully compressed
var compression_velocity: float = 0.0
var normal_force: float = 0.0
var slip_angle: float = 0.0
var slip_ratio: float = 0.0
var steer_angle: float = 0.0
var wheel_angular_velocity: float = 0.0
var drive_torque: float = 0.0
var brake_torque: float = 0.0
var handbrake_factor: float = 1.0     # When handbrake is pulled on rear, scales grip down
var surface_type: String = "asphalt_dry"
var surface_mu: float = 1.0

# Dependencies
var tire_model: PacejkaTire
var opposite_wheel: RaycastWheel = null # Paired wheel for anti-roll bar
var raycast: RayCast3D
var wheel_visual: Node3D

func setup(config: Dictionary, tire_cfg: Dictionary):
	if config.has("rest_length"): rest_length = config.rest_length
	if config.has("travel"): travel = config.travel
	if config.has("spring_rate"): spring_rate = config.spring_rate
	if config.has("damping_bump"): damping_bump = config.damping_bump
	if config.has("damping_rebound"): damping_rebound = config.damping_rebound
	if config.has("anti_roll"): anti_roll_rate = config.anti_roll
	if config.has("wheel_radius"): wheel_radius = config.wheel_radius
	if config.has("wheel_width"): wheel_width = config.wheel_width
	
	tire_model = PacejkaTire.new(tire_cfg)
	
	# Create internal RayCast3D
	raycast = RayCast3D.new()
	raycast.target_position = Vector3(0, -(rest_length + travel + wheel_radius), 0)
	raycast.enabled = true
	raycast.collision_mask = 1 # World & road colliders
	add_child(raycast)

func update_suspension(chassis: RigidBody3D, dt: float) -> Vector3:
	var total_force = Vector3.ZERO
	if not raycast.is_colliding():
		is_grounded = false
		compression = 0.0
		compression_velocity = 0.0
		normal_force = 0.0
		# Update visual mesh to hang at full droop
		if wheel_visual:
			wheel_visual.position = Vector3(0, -rest_length, 0)
		return total_force
	
	is_grounded = true
	contact_point = raycast.get_collision_point()
	contact_normal = raycast.get_collision_normal()
	
	# Determine surface type from collider metadata if present
	var collider = raycast.get_collider()
	if collider and collider.has_meta("surface"):
		surface_type = collider.get_meta("surface")
	else:
		surface_type = "asphalt_dry"
	surface_mu = GameConstants.SURFACES[surface_type].mu
	
	var hit_dist = global_position.distance_to(contact_point) - wheel_radius
	var target_comp = clamp(rest_length - hit_dist, 0.0, travel)
	compression_velocity = (target_comp - compression) / max(0.0001, dt)
	compression = target_comp
	
	# Visual wheel position updates smoothly
	if wheel_visual:
		wheel_visual.position = Vector3(0, -hit_dist, 0)
		wheel_visual.rotation.y = steer_angle
		wheel_visual.rotate_x(wheel_angular_velocity * dt)
	
	# 1. Spring Force with Bump Stop exponential stiffness near limit
	var spring_f = compression * spring_rate
	if compression > travel * 0.85:
		var excess = compression - (travel * 0.85)
		spring_f += pow(excess / (travel * 0.15), 2.0) * spring_rate * 2.5
	
	# 2. Damper Force (separate bump and rebound damping)
	var damper_f = 0.0
	if compression_velocity > 0.0:
		damper_f = compression_velocity * damping_bump
	else:
		damper_f = compression_velocity * damping_rebound
	
	# 3. Anti-Roll Bar Force
	var anti_roll_f = 0.0
	if opposite_wheel:
		var delta_comp = compression - opposite_wheel.compression
		anti_roll_f = delta_comp * anti_roll_rate
	
	normal_force = max(0.0, spring_f + damper_f + anti_roll_f)
	var suspension_vec = contact_normal * normal_force
	
	# 4. Tire Kinematics in Wheel Frame
	var wheel_basis = global_transform.basis.rotated(Vector3.UP, steer_angle)
	var forward_dir = -wheel_basis.z.normalized()
	var right_dir = wheel_basis.x.normalized()
	
	# Local velocity of wheel contact patch relative to ground
	var wheel_vel = chassis.linear_velocity + chassis.angular_velocity.cross(global_position - chassis.global_position)
	var v_long = forward_dir.dot(wheel_vel)
	var v_lat = right_dir.dot(wheel_vel)
	
	# Calculate slip angle and slip ratio
	var abs_v_long = max(0.5, abs(v_long))
	slip_angle = -atan2(v_lat, abs_v_long)
	
	var wheel_ground_speed = wheel_angular_velocity * wheel_radius
	slip_ratio = (wheel_ground_speed - v_long) / abs_v_long
	
	# Effective surface factor (scaled by handbrake on rear wheels)
	var effective_surface = surface_mu * (handbrake_factor if not is_front else 1.0)
	
	# Solve Tire Force
	var tire_res = tire_model.solve(normal_force, slip_ratio, slip_angle, effective_surface)
	var tire_force_vec = (forward_dir * tire_res.fx) + (right_dir * tire_res.fy)
	
	# Integrate wheel rotation velocity
	var net_torque = drive_torque - (tire_res.fx * wheel_radius) - (sign(wheel_angular_velocity) * brake_torque)
	var wheel_inertia = 0.5 * 14.0 * pow(wheel_radius, 2.0) # ~14kg wheel assembly
	wheel_angular_velocity += (net_torque / wheel_inertia) * dt
	
	total_force = suspension_vec + tire_force_vec
	return total_force
