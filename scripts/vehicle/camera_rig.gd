# camera_rig.gd
# Multi-mode camera system: Dynamic Chase Cam, Cockpit View, and Death-Rally Top-Down Tactical Cam.
class_name CameraRig
extends Node3D

enum CameraMode {
	CHASE = 0,
	COCKPIT = 1,
	TACTICAL = 2
}

@export var target_vehicle: VehicleController
var current_mode: CameraMode = CameraMode.CHASE

var camera: Camera3D
var base_fov: float = 68.0

# Chase camera parameters
var chase_distance: float = 5.6
var chase_height: float = 2.1
var chase_pos_smooth: float = 12.0
var chase_look_smooth: float = 16.0

# Cockpit camera offset (relative to car)
var cockpit_offset: Vector3 = Vector3(-0.35, 0.95, -0.2)

# Tactical camera parameters
var tactical_height: float = 16.0
var tactical_pitch_deg: float = 65.0

# Look behind toggle
var is_looking_behind: bool = false

func _ready():
	if not camera:
		camera = Camera3D.new()
		camera.fov = base_fov
		camera.current = true
		add_child(camera)

func _input(event: InputEvent):
	if event.is_action_pressed("camera_switch"):
		current_mode = CameraMode.values()[(int(current_mode) + 1) % CameraMode.size()]
	
	if event.is_action_pressed("look_behind"):
		is_looking_behind = true
	elif event.is_action_released("look_behind"):
		is_looking_behind = false

func _physics_process(delta: float):
	if not target_vehicle or not is_inside_tree() or not target_vehicle.is_inside_tree():
		return
		
	match current_mode:
		CameraMode.CHASE:
			_update_chase_camera(delta)
		CameraMode.COCKPIT:
			_update_cockpit_camera(delta)
		CameraMode.TACTICAL:
			_update_tactical_camera(delta)

func _update_chase_camera(delta: float):
	var car_trans = target_vehicle.global_transform
	var car_pos = car_trans.origin
	var speed_norm = clamp(target_vehicle.speed_kmh / 200.0, 0.0, 1.0)
	
	# Dynamic FOV widens with speed and nitro
	var target_fov = base_fov + (speed_norm * 14.0) + (10.0 if target_vehicle.nitro_active else 0.0)
	camera.fov = lerp(camera.fov, target_fov, delta * 4.0)
	
	# Distance & height increase with speed
	var cur_dist = chase_distance + (speed_norm * 1.5)
	var cur_height = chase_height + (speed_norm * 0.6)
	
	var forward_dir = -car_trans.basis.z.normalized()
	if is_looking_behind:
		forward_dir = -forward_dir
		
	var target_cam_pos = car_pos - (forward_dir * cur_dist) + (Vector3.UP * cur_height)
	camera.global_position = camera.global_position.lerp(target_cam_pos, delta * chase_pos_smooth)
	
	var look_target = car_pos + (forward_dir * 3.0) + (Vector3.UP * 0.8)
	camera.look_at(look_target, Vector3.UP)

func _update_cockpit_camera(delta: float):
	var car_trans = target_vehicle.global_transform
	camera.fov = 75.0
	
	# Driver eye-point with gentle acceleration sway
	var sway = Vector3.ZERO
	sway.z = -target_vehicle.throttle_input * 0.04 + target_vehicle.brake_input * 0.06
	sway.x = -target_vehicle.steer_input * 0.05
	
	var eye_pos = car_trans * (cockpit_offset + sway)
	camera.global_position = eye_pos
	
	var forward_dir = -car_trans.basis.z.normalized()
	if is_looking_behind:
		forward_dir = -forward_dir
	camera.look_at(eye_pos + forward_dir * 10.0 + Vector3.UP * 0.1, car_trans.basis.y)

func _update_tactical_camera(delta: float):
	var car_pos = target_vehicle.global_position
	camera.fov = 55.0
	
	# Camera leads ahead of vehicle velocity
	var lead_offset = target_vehicle.linear_velocity * 0.35
	var target_cam_pos = car_pos + lead_offset + Vector3(0, tactical_height, tactical_height * 0.45)
	
	camera.global_position = camera.global_position.lerp(target_cam_pos, delta * 8.0)
	camera.look_at(car_pos + lead_offset, Vector3.UP)

func snap_to_target() -> void:
	if not target_vehicle or not camera:
		return
	var car_trans := target_vehicle.global_transform
	var car_pos := car_trans.origin
	var forward_dir := -car_trans.basis.z.normalized()
	var cur_dist := chase_distance
	var cur_height := chase_height
	var target_cam_pos := car_pos - (forward_dir * cur_dist) + (Vector3.UP * cur_height)
	camera.global_position = target_cam_pos
	var look_target := car_pos + (forward_dir * 3.0) + (Vector3.UP * 0.8)
	camera.look_at(look_target, Vector3.UP)

