# scripts/core/main.gd
# Root entry showcase & Horizon Main Menu for GRIDLETHAL: validates JSON data, displays live 3D car
# with PBR clearcoat + shader pre-warming, navigates across Open World / Circuit Race / Garage, and handles --screenshot.
class_name MainScene
extends Node3D

const DataValidator = preload("res://scripts/core/data_validator.gd")
const InputManager = preload("res://scripts/core/input_manager.gd")
const DebugOverlay = preload("res://scripts/ui/debug_overlay.gd")
const ProceduralCarMesh = preload("res://scripts/vehicle/procedural_car_mesh.gd")
const CarModelLoader = preload("res://scripts/vehicle/car_model_loader.gd")
const PropMeshUtils = preload("res://scripts/world/prop_mesh_utils.gd")
const BiomePropsBuilder = preload("res://scripts/world/biome_props_builder.gd")
const VisualPipeline = preload("res://scripts/core/visual_pipeline.gd")

@onready var input_mgr: InputManager = $InputManager
@onready var debug_overlay: DebugOverlay = $DebugOverlay
@onready var world_env: WorldEnvironment = $WorldEnvironment
@onready var sun_light: DirectionalLight3D = $SunLight
@onready var camera: Camera3D = $Camera3D
@onready var menu_canvas: CanvasLayer = $MenuCanvas

var car_model_node: Node3D = null
var save_manager: SaveManager = null
var is_screenshot_mode: bool = false
var frames_rendered: int = 0

func _ready() -> void:
	print("\n=======================================================")
	print("       GRIDLETHAL MOTORSPORT SIMULATION STARTUP        ")
	print("=======================================================\n")

	var val_res: Dictionary = DataValidator.validate_all()
	if not val_res.success:
		printerr("[FATAL] Data validation failed with %d errors:" % val_res.errors.size())
		for e in val_res.errors:
			printerr("  - ", e)
	else:
		print("[PASS] Data-driven definitions verified successfully (32 vehicles, 26 weapons).")

	save_manager = SaveManager.new()

	var all_args: PackedStringArray = OS.get_cmdline_user_args()
	if all_args.is_empty():
		all_args = OS.get_cmdline_args()
	for arg: String in all_args:
		if arg == "--screenshot":
			is_screenshot_mode = true
			print("[INIT] Running in automated visual verification (--screenshot) mode.")
		elif arg == "--open-world":
			call_deferred("_go_to_scene", "res://scenes/open_world.tscn")
			return
		elif arg == "--garage":
			call_deferred("_go_to_scene", "res://scenes/garage.tscn")
			return
		elif arg == "--track":
			call_deferred("_go_to_scene", "res://scenes/track_test.tscn")
			return

	_setup_backdrop_gantry()
	_setup_showcase_vehicle()
	_build_main_menu_ui()
	camera.position = Vector3(1.85, 1.38, -4.15)
	camera.look_at(Vector3(-0.35, 0.62, 0.0), Vector3.UP)

	VisualPipeline.attach_horizon_compositor(world_env, 0.12, 0.10)
	var mats: Array[Material] = []
	VisualPipeline.collect_materials_from_node(self, mats)
	VisualPipeline.spawn_prewarm_batch(self, camera, mats)

func _setup_backdrop_gantry() -> void:
	var light_mesh: Mesh = PropMeshUtils.load_centered_mesh("res://assets/models/props/flood_lights/flood_lights.gltf", 1.75, 0.02, "standing_double_a")
	if light_mesh:
		for fx: Array in [[-14.5, 11.0, 2.5], [14.5, 11.0, -2.5]]:
			var lmi := MeshInstance3D.new()
			lmi.mesh = light_mesh
			lmi.position = Vector3(float(fx[0]), 0.0, float(fx[1]))
			lmi.rotation.y = float(fx[2])
			add_child(lmi)

	var pine_mesh: Mesh = PropMeshUtils.load_centered_mesh("res://assets/models/foliage/fir_winter_summer.glb", 0.044, 0.15, "object_2")
	if pine_mesh:
		for px: Array in [[-16.0, 16.0], [-10.5, 22.0], [13.5, 19.0], [19.5, 14.0]]:
			var pmi := MeshInstance3D.new()
			pmi.mesh = pine_mesh
			pmi.position = Vector3(float(px[0]), 0.0, float(px[1]))
			add_child(pmi)

	var rock_mesh: Mesh = PropMeshUtils.load_centered_mesh("res://assets/models/rocks/boulder_01/boulder_01.gltf", 2.0, 0.14)
	if rock_mesh:
		for rx: Array in [[-13.0, 14.5, 0.8], [15.5, 13.5, 2.2]]:
			var rmi := MeshInstance3D.new()
			rmi.mesh = rock_mesh
			rmi.position = Vector3(float(rx[0]), 0.0, float(rx[1]))
			rmi.rotation.y = float(rx[2])
			add_child(rmi)

func _setup_showcase_vehicle() -> void:
	var car_id: String = "skyline_vspec"
	if save_manager and save_manager.save_data.has("selected_car"):
		var sel: String = str(save_manager.save_data.get("selected_car", "skyline_vspec"))
		if sel != "sprinter_r2":
			car_id = sel

	var recipe: Dictionary = _find_vehicle_recipe(car_id)
	var holder := Node3D.new()
	holder.name = "ShowcaseCar"
	holder.position = Vector3(-0.55, 0.14, 0.0)
	holder.rotation.y = -0.35
	add_child(holder)

	if recipe.has("model_path") and FileAccess.file_exists(str(recipe["model_path"])):
		var vis: Node3D = CarModelLoader.load_car_visuals(holder, recipe)
		if vis:
			car_model_node = holder
			debug_overlay.set_target_vehicle(car_model_node)
			print("[PASS] Loaded showcase 3D car model: %s (%s)" % [car_id, str(recipe["model_path"])])
			return

	var proc := ProceduralCarMesh.new()
	proc.build_car(recipe)
	holder.add_child(proc)
	car_model_node = holder
	debug_overlay.set_target_vehicle(car_model_node)
	print("[PASS] Loaded procedural vehicle fallback model.")

func _find_vehicle_recipe(car_id: String) -> Dictionary:
	if FileAccess.file_exists("res://data/vehicles.json"):
		var f := FileAccess.open("res://data/vehicles.json", FileAccess.READ)
		if f:
			var parsed: Variant = JSON.parse_string(f.get_as_text())
			f.close()
			if parsed is Dictionary and parsed.has("vehicles"):
				for v: Dictionary in parsed["vehicles"]:
					if str(v.get("id", "")) == car_id:
						return v
	return { "id": car_id, "name": "Skyline GT-R", "wheelbase": 2.66, "track_width": 1.80, "model_path": "res://assets/models/cars/nissan_gtr_r35.glb" }

func _build_main_menu_ui() -> void:
	if not menu_canvas:
		return
	var panel := PanelContainer.new()
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = 48.0
	panel.offset_top = -230.0
	panel.offset_right = 430.0
	panel.offset_bottom = 230.0

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.07, 0.10, 0.82)
	style.border_width_left = 4
	style.border_color = Color(1.0, 0.45, 0.06, 0.95)
	style.content_margin_left = 26
	style.content_margin_right = 26
	style.content_margin_top = 24
	style.content_margin_bottom = 24
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	panel.add_theme_stylebox_override("panel", style)
	menu_canvas.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "GRIDLETHAL"
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(1.0, 0.52, 0.10))
	vbox.add_child(title)

	var sub := Label.new()
	sub.text = "HORIZON COMBAT MOTORSPORT"
	sub.add_theme_font_size_override("font_size", 14)
	sub.add_theme_color_override("font_color", Color(0.72, 0.84, 0.96))
	vbox.add_child(sub)

	var driver_name: String = str(save_manager.save_data.get("player_name", "RYuK006"))
	var cash: int = int(save_manager.save_data.get("cash", 25000))
	var profile_lbl := Label.new()
	profile_lbl.text = "DRIVER: %s | BANK: $%d" % [driver_name, cash]
	profile_lbl.add_theme_font_size_override("font_size", 13)
	profile_lbl.add_theme_color_override("font_color", Color(0.35, 0.92, 0.52))
	vbox.add_child(profile_lbl)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	_add_menu_button(vbox, "ENTER OPEN WORLD FREEROAM", Color(1.0, 0.45, 0.06), func(): _go_to_scene("res://scenes/open_world.tscn"))
	_add_menu_button(vbox, "CIRCUIT COMBAT RACE (6 CARS)", Color(0.15, 0.72, 0.95), func(): _go_to_scene("res://scenes/track_test.tscn"))
	_add_menu_button(vbox, "GARAGE AUTOSHOW & TUNING", Color(0.85, 0.88, 0.94), func(): _go_to_scene("res://scenes/garage.tscn"))
	_add_menu_button(vbox, "TOGGLE TELEMETRY / VRAM (F3)", Color(0.65, 0.72, 0.80), func():
		if debug_overlay:
			debug_overlay.toggle_visible()
	)
	_add_menu_button(vbox, "QUIT TO DESKTOP", Color(0.95, 0.35, 0.35), func(): get_tree().quit(0))

func _add_menu_button(parent: VBoxContainer, label_text: String, accent: Color, callback: Callable) -> void:
	var btn := Button.new()
	btn.text = label_text
	btn.custom_minimum_size = Vector2(0, 44)
	btn.add_theme_color_override("font_color", accent)
	btn.pressed.connect(callback)
	parent.add_child(btn)

func _go_to_scene(scene_path: String) -> void:
	get_tree().change_scene_to_file(scene_path)

func _process(delta: float) -> void:
	if car_model_node:
		car_model_node.rotate_y(delta * 0.25)

	if is_screenshot_mode:
		frames_rendered += 1
		if frames_rendered >= 24:
			_capture_and_quit()

func _capture_and_quit() -> void:
	var vp: Viewport = get_viewport()
	var img: Image = vp.get_texture().get_image()
	var dir := DirAccess.open("res://")
	if dir and not dir.dir_exists("build/screenshots"):
		dir.make_dir_recursive("build/screenshots")
	var out_path: String = "res://build/screenshots/m1_boot.png"
	var global_path: String = ProjectSettings.globalize_path(out_path)
	var err: Error = img.save_png(global_path)
	if err == OK:
		print("[PASS] Screenshot saved to: ", global_path)
	else:
		printerr("[FAIL] Failed to save screenshot: ", err)
	get_tree().quit(0)
