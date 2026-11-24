# main.gd
# Main Game Coordinator for Stage 1: Assembles physics, procedural graphics, audio and telemetry.
class_name MainGame
extends Node3D

var car: VehicleController
var car_mesh: ProceduralCarMesh
var audio_engine: ProceduralAudioEngine
var camera_rig: CameraRig
var debug_overlay: DebugOverlay
var test_track: TestTrack

func _ready():
	_setup_lighting()
	_setup_world()
	_setup_player()
	_setup_audio()
	_setup_camera()
	_setup_ui()

func _setup_lighting():
	var sun = DirectionalLight3D.new()
	sun.name = "SunLight"
	sun.rotation = Vector3(deg_to_rad(-22.0), deg_to_rad(-45.0), 0)
	sun.light_color = Color(1.0, 0.92, 0.82) # Warm golden hour sunlight
	sun.light_energy = 3.6
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 250.0
	sun.directional_shadow_split_1 = 0.08
	sun.directional_shadow_split_2 = 0.22
	sun.directional_shadow_split_3 = 0.55
	sun.shadow_bias = 0.03
	add_child(sun)
	
	var world_env = WorldEnvironment.new()
	world_env.environment = load("res://src/render/default_env.tres")
	add_child(world_env)

func _setup_world():
	test_track = TestTrack.new()
	test_track.name = "TestTrack"
	add_child(test_track)

func _setup_player():
	car = VehicleController.new()
	car.name = "PlayerVehicle"
	car.car_id = "sprinter_r2"
	car.position = Vector3(0, 0.8, -120)
	add_child(car)
	
	# Attach procedural mesh
	car_mesh = ProceduralCarMesh.new()
	car_mesh.name = "ProceduralMesh"
	car_mesh.build_car(car.recipe)
	car.add_child(car_mesh)
	car.car_mesh_instance = car_mesh
	
	# Connect visual wheel links
	for i in range(car.wheels.size()):
		var w = car.wheels[i]
		# Find corresponding visual wheel in mesh
		if car_mesh.get_child_count() > i + 5: # After body, scoop, wing, lights
			w.wheel_visual = car_mesh.get_child(i + 5)

func _setup_audio():
	audio_engine = ProceduralAudioEngine.new()
	audio_engine.name = "ProceduralAudio"
	add_child(audio_engine)

func _setup_camera():
	camera_rig = CameraRig.new()
	camera_rig.name = "CameraRig"
	camera_rig.target_vehicle = car
	add_child(camera_rig)

func _setup_ui():
	debug_overlay = DebugOverlay.new()
	debug_overlay.name = "DebugOverlay"
	debug_overlay.target_vehicle = car
	add_child(debug_overlay)

func _process(_delta: float):
	if car and audio_engine:
		# Calculate maximum tire slip across all wheels
		var max_slip = 0.0
		var current_surface = "asphalt_dry"
		for w in car.wheels:
			max_slip = max(max_slip, abs(w.slip_angle) + abs(w.slip_ratio))
			if w.is_grounded:
				current_surface = w.surface_type
				
		audio_engine.update_parameters(
			car.engine_rpm,
			car.throttle_input,
			car.turbo_boost,
			max_slip,
			current_surface
		)
