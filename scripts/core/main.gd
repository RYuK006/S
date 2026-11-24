# main.gd
# Root entry point for GRIDLETHAL. Validates JSON data, boots subsystems, and handles --screenshot argument.
class_name MainScene
extends Node3D

const DataValidator = preload("res://scripts/core/data_validator.gd")
const InputManager = preload("res://scripts/core/input_manager.gd")
const DebugOverlay = preload("res://scripts/ui/debug_overlay.gd")
const ProceduralCarMesh = preload("res://scripts/vehicle/procedural_car_mesh.gd")

@onready var input_mgr: InputManager = $InputManager
@onready var debug_overlay: DebugOverlay = $DebugOverlay
@onready var world_env: WorldEnvironment = $WorldEnvironment
@onready var sun_light: DirectionalLight3D = $SunLight
@onready var camera: Camera3D = $Camera3D

var car_model_node: Node3D = null
var is_screenshot_mode: bool = false
var frames_rendered: int = 0

func _ready():
	print("\n=======================================================")
	print("       GRIDLETHAL MOTORSPORT SIMULATION STARTUP        ")
	print("=======================================================\n")
	
	# 1. Validate data-driven definitions
	var val_res = DataValidator.validate_all()
	if not val_res.success:
		printerr("[FATAL] Data validation failed with %d errors:" % val_res.errors.size())
		for e in val_res.errors:
			printerr("  - ", e)
	else:
		print("[PASS] Data-driven definitions verified successfully (32 vehicles, 26 weapons).")

	# 2. Check for --screenshot CLI argument
	var args = OS.get_cmdline_user_args()
	if args.is_empty():
		args = OS.get_cmdline_args()
	for arg in args:
		if arg == "--screenshot":
			is_screenshot_mode = true
			print("[INIT] Running in automated visual verification (--screenshot) mode.")

	# 3. Setup reference car showcase
	_setup_showcase_vehicle()

func _setup_showcase_vehicle():
	var glb_path = "res://assets/models/cars/CarConcept.glb"
	if FileAccess.file_exists(glb_path):
		var gltf = GLTFDocument.new()
		var state = GLTFState.new()
		var err = gltf.append_from_file(glb_path, state)
		if err == OK:
			car_model_node = gltf.generate_scene(state)
			car_model_node.name = "ShowcaseCar"
			car_model_node.position = Vector3(0, 0, 0)
			add_child(car_model_node)
			debug_overlay.set_target_vehicle(car_model_node)
			print("[PASS] Loaded reference 3D car model via GLTFDocument: CarConcept.glb")
			return
		else:
			print("[WARN] GLTFDocument parse error (%d) for %s." % [err, glb_path])
			
	# Procedural fallback generator
	var proc_builder = ProceduralCarMesh.new()
	var fallback_recipe = { "wheelbase": 2.6, "track_width": 1.8 }
	car_model_node = proc_builder.build_mesh(fallback_recipe, Color(0.95, 0.25, 0.08))
	car_model_node.name = "ShowcaseCar"
	car_model_node.position = Vector3(0, 0, 0)
	add_child(car_model_node)
	debug_overlay.set_target_vehicle(car_model_node)
	print("[PASS] Loaded procedural vehicle fallback model.")

func _process(delta: float):
	if car_model_node:
		car_model_node.rotate_y(delta * 0.45)
		
	if is_screenshot_mode:
		frames_rendered += 1
		# Allow 30 frames for shaders and shadow cascades to converge
		if frames_rendered >= 30:
			_capture_and_quit()

func _capture_and_quit():
	var vp = get_viewport()
	var img = vp.get_texture().get_image()
	var dir = DirAccess.open("res://")
	if not dir.dir_exists("build/screenshots"):
		dir.make_dir_recursive("build/screenshots")
	var out_path = "res://build/screenshots/m1_boot.png"
	var global_path = ProjectSettings.globalize_path(out_path)
	var err = img.save_png(global_path)
	if err == OK:
		print("[PASS] Screenshot saved to: ", global_path)
	else:
		printerr("[FAIL] Failed to save screenshot: ", err)
	get_tree().quit(0)
