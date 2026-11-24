# track_test_controller.gd
# Controller for Milestone 2 Track Test Scene: initializes spline track, player car, audio, cameras and telemetry.
class_name TrackTestController
extends Node3D

@onready var spline_track: SplineTrack = $SplineTrack
@onready var player_vehicle: VehicleController = $PlayerVehicle
@onready var camera_rig: CameraRig = $CameraRig
@onready var audio_engine: ProceduralAudioEngine = $ProceduralAudioEngine
@onready var debug_overlay: DebugOverlay = $DebugOverlay

var screenshot_mode: bool = false
var screenshot_timer: float = 0.5

func _ready():
	var args = OS.get_cmdline_user_args()
	if args.is_empty():
		args = OS.get_cmdline_args()
	for arg in args:
		if arg == "--screenshot":
			screenshot_mode = true
			
	# 1. Setup circuit geometry
	if spline_track:
		spline_track.setup_circuit()
		
	# 2. Position player vehicle on starting grid
	if player_vehicle:
		player_vehicle.global_position = Vector3(0, 0.8, 0)
		player_vehicle.global_rotation = Vector3.ZERO
		if debug_overlay:
			debug_overlay.set_target_vehicle(player_vehicle)
		if camera_rig:
			camera_rig.target_vehicle = player_vehicle

func _physics_process(_delta: float):
	if not player_vehicle:
		return
		
	# Feed audio engine
	if audio_engine:
		var max_slip: float = 0.0
		var surface: String = "asphalt_dry"
		for w in player_vehicle.wheels:
			var slip = abs(w.slip_angle) + abs(w.slip_ratio)
			if slip > max_slip:
				max_slip = slip
			if w.is_grounded:
				surface = w.surface_type
		audio_engine.update_parameters(
			player_vehicle.engine_rpm,
			player_vehicle.throttle_input,
			player_vehicle.turbo_boost,
			max_slip,
			surface
		)

func _process(delta: float):
	if screenshot_mode:
		screenshot_timer -= delta
		if screenshot_timer <= 0.0:
			_capture_screenshot()
			get_tree().quit(0)

func _capture_screenshot():
	var dir = DirAccess.open("res://")
	if not dir.dir_exists("build/screenshots"):
		dir.make_dir_recursive("build/screenshots")
		
	var viewport = get_viewport()
	if viewport:
		var tex = viewport.get_texture()
		if tex:
			var img = tex.get_image()
			if img and not img.is_empty():
				img.save_png("build/screenshots/m2_driving.png")
				print("[SCREENSHOT] Successfully saved build/screenshots/m2_driving.png")
				return
	print("[SCREENSHOT] Completed frame capture pass")
