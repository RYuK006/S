# main.gd
# Main Game Coordinator for Stage 2: 3-Lap Circuit Race with 5 AI rivals, countdown, HUD & minimap.
class_name MainGame
extends Node3D

const VehicleController = preload("res://src/vehicles/vehicle_controller.gd")
const ProceduralCarMesh = preload("res://src/vehicles/procedural_car_mesh.gd")
const ProceduralAudioEngine = preload("res://src/audio/procedural_audio_engine.gd")
const CameraRig = preload("res://src/core/camera_rig.gd")
const DebugOverlay = preload("res://src/ui/debug_overlay.gd")
const SplineTrack = preload("res://src/tracks/spline_track.gd")
const AIDriver = preload("res://src/ai/ai_driver.gd")
const RaceManager = preload("res://src/core/race_manager.gd")
const RaceHUD = preload("res://src/ui/race_hud.gd")
const SkidMarks = preload("res://src/fx/skid_marks.gd")

var player_car: VehicleController
var player_car_mesh: ProceduralCarMesh
var audio_engine: ProceduralAudioEngine
var camera_rig: CameraRig
var debug_overlay: DebugOverlay
var track: SplineTrack
var race_mgr: RaceManager
var race_hud: RaceHUD
var skid_marks: SkidMarks

var ai_cars: Array[VehicleController] = []

func _ready():
	_setup_lighting()
	_setup_track()
	_setup_skidmarks()
	_setup_player()
	_setup_ai_opponents()
	_setup_race_manager()
	_setup_audio()
	_setup_camera()
	_setup_ui()

func _setup_lighting():
	var sun = DirectionalLight3D.new()
	sun.name = "SunLight"
	sun.rotation = Vector3(deg_to_rad(-24.0), deg_to_rad(-40.0), 0)
	sun.light_color = Color(1.0, 0.94, 0.85)
	sun.light_energy = 3.6
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 350.0
	sun.shadow_bias = 0.02
	add_child(sun)
	
	var world_env = WorldEnvironment.new()
	world_env.environment = load("res://src/render/default_env.tres")
	add_child(world_env)

func _setup_track():
	track = SplineTrack.new()
	track.name = "SplineTrack"
	add_child(track)
	track.setup_circuit()

func _setup_skidmarks():
	skid_marks = SkidMarks.new()
	skid_marks.name = "SkidMarks"
	add_child(skid_marks)

func _setup_player():
	player_car = VehicleController.new()
	player_car.name = "PlayerVehicle"
	player_car.car_id = "sprinter_r2"
	# Grid position 6 (starting at back of grid)
	player_car.position = Vector3(-3.5, 0.6, -35.0)
	add_child(player_car)
	
	player_car_mesh = ProceduralCarMesh.new()
	player_car_mesh.build_car(player_car.recipe)
	player_car.add_child(player_car_mesh)
	player_car.car_mesh_instance = player_car_mesh
	
	for i in range(player_car.wheels.size()):
		var w = player_car.wheels[i]
		if player_car_mesh.get_child_count() > i + 5:
			w.wheel_visual = player_car_mesh.get_child(i + 5)

func _setup_ai_opponents():
	ai_cars.clear()
	var ai_configs = [
		{ "name": "Viktor 'Rotor' Hale", "style": "Aggressive", "pos": Vector3(3.5, 0.6, 15.0), "color": Color(0.95, 0.2, 0.1) },
		{ "name": "Mina Cross", "style": "Tactical", "pos": Vector3(-3.5, 0.6, 5.0), "color": Color(0.1, 0.6, 0.95) },
		{ "name": "Dozer Okafor", "style": "Bully", "pos": Vector3(3.5, 0.6, -5.0), "color": Color(0.2, 0.8, 0.2) },
		{ "name": "Lena Vash", "style": "Drifter", "pos": Vector3(-3.5, 0.6, -15.0), "color": Color(0.9, 0.7, 0.1) },
		{ "name": "'Hollow' Pike", "style": "Trickster", "pos": Vector3(3.5, 0.6, -25.0), "color": Color(0.7, 0.2, 0.8) }
	]
	
	for cfg in ai_configs:
		var ai_car = VehicleController.new()
		ai_car.name = "AI_" + cfg.name
		ai_car.car_id = "sprinter_r2"
		ai_car.position = cfg.pos
		add_child(ai_car)
		
		var ai_mesh = ProceduralCarMesh.new()
		ai_mesh.build_car(ai_car.recipe)
		# Unique livery color for each AI opponent
		if ai_mesh.body_mesh_instance:
			var mat = StandardMaterial3D.new()
			mat.albedo_color = cfg.color
			mat.metallic = 0.8
			mat.roughness = 0.15
			mat.clearcoat_enabled = true
			mat.clearcoat = 1.0
			ai_mesh.body_mesh_instance.material_override = mat
		ai_car.add_child(ai_mesh)
		ai_car.car_mesh_instance = ai_mesh
		
		for i in range(ai_car.wheels.size()):
			var w = ai_car.wheels[i]
			if ai_mesh.get_child_count() > i + 5:
				w.wheel_visual = ai_mesh.get_child(i + 5)
				
		var ai_driver = AIDriver.new()
		ai_driver.name = "Driver"
		ai_car.add_child(ai_driver)
		ai_driver.setup(ai_car, track, cfg.name, cfg.style)
		
		ai_cars.append(ai_car)

func _setup_race_manager():
	race_mgr = RaceManager.new()
	race_mgr.name = "RaceManager"
	add_child(race_mgr)
	race_mgr.setup_race(track, player_car, ai_cars, 3)

func _setup_audio():
	audio_engine = ProceduralAudioEngine.new()
	audio_engine.name = "ProceduralAudio"
	add_child(audio_engine)

func _setup_camera():
	camera_rig = CameraRig.new()
	camera_rig.name = "CameraRig"
	camera_rig.target_vehicle = player_car
	add_child(camera_rig)

func _setup_ui():
	race_hud = RaceHUD.new()
	race_hud.name = "RaceHUD"
	add_child(race_hud)
	race_hud.setup(player_car, race_mgr, track)
	
	debug_overlay = DebugOverlay.new()
	debug_overlay.name = "DebugOverlay"
	debug_overlay.target_vehicle = player_car
	add_child(debug_overlay)

func _process(_delta: float):
	if not player_car:
		return
		
	# 1. Update Audio
	var max_slip = 0.0
	var current_surf = "asphalt_dry"
	for w in player_car.wheels:
		max_slip = max(max_slip, abs(w.slip_angle) + abs(w.slip_ratio))
		if w.is_grounded:
			current_surf = w.surface_type
			# Spawn Skid Marks when sliding
			if (abs(w.slip_angle) > 0.16 or abs(w.slip_ratio) > 0.22) and skid_marks:
				var wheel_right = w.global_transform.basis.x.normalized()
				skid_marks.add_mark(w.contact_point, w.contact_normal, wheel_right, 0.22, 0.75)
				
	audio_engine.update_parameters(
		player_car.engine_rpm,
		player_car.throttle_input,
		player_car.turbo_boost,
		max_slip,
		current_surf
	)
