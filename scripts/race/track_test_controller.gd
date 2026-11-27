# scripts/race/track_test_controller.gd
# Controller for Track Test Scene: initializes spline track, trackside FH5 scenery & occluders,
# player car, AI rivals, race manager, cameras, HUD, Pause menu, and shader pre-warming.
class_name TrackTestController
extends Node3D

const RaceManager = preload("res://scripts/race/race_manager.gd")
const RaceHUD = preload("res://scripts/ui/race_hud.gd")
const AIDriver = preload("res://scripts/ai/ai_driver.gd")
const WeaponSystem = preload("res://scripts/weapons/weapon_system.gd")
const TrackPickup = preload("res://scripts/race/pickups.gd")
const PropMeshUtils = preload("res://scripts/world/prop_mesh_utils.gd")
const VisualPipeline = preload("res://scripts/core/visual_pipeline.gd")
const HorizonCompositorEffect = preload("res://scripts/core/horizon_compositor_effect.gd")

@onready var spline_track: SplineTrack = $SplineTrack
@onready var player_vehicle: VehicleController = $PlayerVehicle
@onready var camera_rig: CameraRig = $CameraRig
@onready var audio_engine: ProceduralAudioEngine = $ProceduralAudioEngine
@onready var debug_overlay: DebugOverlay = $DebugOverlay

var race_mgr: RaceManager
var race_hud: RaceHUD
var ai_cars: Array[VehicleController] = []
var player_weapons: WeaponSystem
var pause_layer: CanvasLayer
var pause_panel: PanelContainer
var compositor_fx: HorizonCompositorEffect

var screenshot_mode: bool = false
var screenshot_timer: float = 1.1

func _ready() -> void:
	var all_args: PackedStringArray = OS.get_cmdline_user_args()
	all_args.append_array(OS.get_cmdline_args())
	for arg: String in all_args:
		if arg == "--screenshot":
			screenshot_mode = true

	# 1. Setup circuit geometry & trackside AAA scenery
	if spline_track:
		spline_track.setup_circuit()
		_build_trackside_scenery()

	# 2. Position player vehicle on starting grid & equip weapons
	if player_vehicle:
		var save_mgr := SaveManager.new()
		var sel_id: String = str(save_mgr.save_data.get("selected_car", "skyline_vspec"))
		if sel_id != "sprinter_r2":
			player_vehicle.car_id = sel_id
		player_vehicle.global_position = Vector3(0, 0.8, 0)
		player_vehicle.global_rotation = Vector3.ZERO
		if debug_overlay:
			debug_overlay.set_target_vehicle(player_vehicle)
		if camera_rig:
			camera_rig.target_vehicle = player_vehicle

		player_weapons = WeaponSystem.new()
		player_vehicle.add_child(player_weapons)
		player_weapons.setup(player_vehicle, "twin_mg", "rocket_pod", "mine_dropper")

	# 3. Spawn 5 AI rivals on starting grid
	_spawn_ai_rivals()

	# 4. Spawn Track Pickups
	_spawn_pickups()

	# 5. Setup Race Manager, HUD & Esc Pause Menu
	race_mgr = RaceManager.new()
	add_child(race_mgr)
	race_mgr.setup_race(spline_track, player_vehicle, ai_cars, 3)

	race_hud = RaceHUD.new()
	add_child(race_hud)
	race_hud.setup(player_vehicle, race_mgr, spline_track)
	_build_pause_menu()

	# 6. Attach Vulkan CompositorEffect & pre-warm shader pipelines upfront
	var we := get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we:
		compositor_fx = VisualPipeline.attach_horizon_compositor(we, 0.14, 0.12)
	var prewarm_mats: Array[Material] = []
	VisualPipeline.collect_materials_from_node(self, prewarm_mats)
	if camera_rig and camera_rig.camera:
		VisualPipeline.spawn_prewarm_batch(self, camera_rig.camera, prewarm_mats)

func _build_trackside_scenery() -> void:
	if not spline_track or spline_track.track_points.is_empty():
		return

	var scenery := Node3D.new()
	scenery.name = "CircuitScenery"
	add_child(scenery)

	# 1. Illuminated Horizon Start/Finish Gantry Bridge over Start Line
	var steel_mat := StandardMaterial3D.new()
	steel_mat.albedo_color = Color(0.14, 0.15, 0.18)
	steel_mat.metallic = 0.85
	steel_mat.roughness = 0.25
	var amber_mat := StandardMaterial3D.new()
	amber_mat.albedo_color = Color(1.0, 0.45, 0.05)
	amber_mat.emission_enabled = true
	amber_mat.emission = Color(1.0, 0.45, 0.05)
	amber_mat.emission_energy_multiplier = 2.2

	var truss_mesh: Mesh = PropMeshUtils.load_centered_mesh("res://assets/models/props/concert_truss.glb", 3.0, 0.0)
	for sx: float in [-8.5, 8.5]:
		if truss_mesh:
			var col := MeshInstance3D.new()
			col.mesh = truss_mesh
			col.position = Vector3(sx, 0.0, -3.5)
			scenery.add_child(col)
	var bridge := MeshInstance3D.new()
	var b_box := BoxMesh.new()
	b_box.size = Vector3(18.0, 0.9, 1.1)
	bridge.mesh = b_box
	bridge.material_override = steel_mat
	bridge.position = Vector3(0.0, 5.7, -3.5)
	scenery.add_child(bridge)
	var strip := MeshInstance3D.new()
	var s_box := BoxMesh.new()
	s_box.size = Vector3(17.2, 0.16, 1.15)
	strip.mesh = s_box
	strip.material_override = amber_mat
	strip.position = Vector3(0.0, 6.1, -3.5)
	scenery.add_child(strip)

	# 2. MultiMesh Bleachers, Floodlights, Tire Walls, Pines, Cactus & Sandstone Rocks
	var bleacher_mesh: Mesh = PropMeshUtils.load_centered_mesh("res://assets/models/props/festival_bleacher.glb", 22.0, 0.02)
	var tire_mesh: Mesh = PropMeshUtils.load_centered_mesh("res://assets/models/props/tire_barrier_wall.glb", 1.15, 0.02)
	var light_mesh: Mesh = PropMeshUtils.load_centered_mesh("res://assets/models/props/flood_lights/flood_lights.gltf", 1.85, 0.02, "standing_double_a")
	var pine_mesh: Mesh = PropMeshUtils.load_centered_mesh("res://assets/models/foliage/fir_winter_summer.glb", 0.046, 0.18, "object_2")
	var cactus_mesh: Mesh = PropMeshUtils.load_centered_mesh("res://assets/models/foliage/saguaro_cactus.glb", 1.35, 0.10, "bark")
	var rock_mesh: Mesh = PropMeshUtils.load_centered_mesh("res://assets/models/rocks/boulder_01/boulder_01.gltf", 2.2, 0.08)

	var bl_xforms: Array[Transform3D] = []
	var tire_xforms: Array[Transform3D] = []
	var light_xforms: Array[Transform3D] = []
	var pine_xforms: Array[Transform3D] = []
	var cactus_xforms: Array[Transform3D] = []
	var rock_xforms: Array[Transform3D] = []

	var rng := RandomNumberGenerator.new()
	rng.seed = 4040
	var pts: Array[Dictionary] = spline_track.track_points
	for i: int in range(pts.size()):
		var pt: Dictionary = pts[i]
		var pos: Vector3 = pt["pos"]
		var right: Vector3 = pt["right"]
		var fwd: Vector3 = pt["forward"]
		var yaw: float = atan2(fwd.x, fwd.z)

		if i % 2 == 0:
			for s_dir: float in [-1.0, 1.0]:
				var t_pos: Vector3 = pos + right * (s_dir * 8.6)
				tire_xforms.append(Transform3D(Basis(Vector3.UP, yaw), t_pos))
		if i % 6 == 0 or (absf(pos.x) < 12.0 and pos.z < -8.0 and pos.z > -110.0 and i % 3 == 0):
			var bl_pos: Vector3 = pos + right * (-13.5)
			bl_xforms.append(Transform3D(Basis(Vector3.UP, yaw + PI * 0.5), bl_pos))
			scenery.add_child(VisualPipeline.build_box_occluder("TrackBleacherOcc_%d" % i, Vector3(11.0, 4.0, 5.0), bl_pos + Vector3(0.0, 2.0, 0.0), yaw + PI * 0.5))
		if i % 8 == 0 or (absf(pos.x) < 12.0 and pos.z < -10.0 and pos.z > -110.0 and i % 4 == 0):
			var l_pos: Vector3 = pos + right * 13.0
			light_xforms.append(Transform3D(Basis(Vector3.UP, yaw - PI * 0.5), l_pos))
		if i % 1 == 0:
			var side: float = 1.0 if (i % 2 == 0) else -1.0
			var dist_out: float = rng.randf_range(20.0, 58.0)
			var p_pos: Vector3 = pos + right * (side * dist_out)
			var sc: float = rng.randf_range(1.1, 1.85)
			pine_xforms.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sc, sc, sc)), Vector3(p_pos.x, 0.0, p_pos.z)))
			var rs: float = rng.randf_range(1.4, 3.2)
			if i % 3 == 0:
				var r_pos: Vector3 = pos + right * (-side * rng.randf_range(16.0, 46.0))
				rock_xforms.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(rs, rs, rs)), Vector3(r_pos.x, 0.0, r_pos.z)))
			else:
				var c_pos: Vector3 = pos + right * (-side * rng.randf_range(14.0, 38.0))
				var cs: float = rng.randf_range(0.9, 1.4)
				cactus_xforms.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(cs, cs, cs)), Vector3(c_pos.x, 0.0, c_pos.z)))

	_add_mm(scenery, "CircuitBleachers", bleacher_mesh, bl_xforms, 550.0, true)
	_add_mm(scenery, "CircuitTireWalls", tire_mesh, tire_xforms, 380.0, true)
	_add_mm(scenery, "CircuitFloodLights", light_mesh, light_xforms, 460.0, true)
	_add_mm(scenery, "CircuitPines", pine_mesh, pine_xforms, 620.0, true)
	_add_mm(scenery, "CircuitCactus", cactus_mesh, cactus_xforms, 520.0, true)
	_add_mm(scenery, "CircuitRocks", rock_mesh, rock_xforms, 620.0, true)

func _add_mm(parent: Node3D, mm_name: String, mesh: Mesh, xforms: Array[Transform3D], vis_end: float, cast_shadow: bool) -> void:
	if not mesh or xforms.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i: int in range(xforms.size()):
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = mm_name
	mmi.multimesh = mm
	mmi.visibility_range_end = vis_end
	mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast_shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mmi)

func _build_pause_menu() -> void:
	pause_layer = CanvasLayer.new()
	pause_layer.name = "PauseLayer"
	add_child(pause_layer)

	pause_panel = PanelContainer.new()
	pause_panel.set_anchors_preset(Control.PRESET_CENTER)
	pause_panel.offset_left = -180.0
	pause_panel.offset_top = -150.0
	pause_panel.offset_right = 180.0
	pause_panel.offset_bottom = 150.0
	pause_panel.visible = false
	pause_layer.add_child(pause_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	pause_panel.add_child(vbox)

	var lbl := Label.new()
	lbl.text = "RACE PAUSED"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 24)
	vbox.add_child(lbl)

	var items: Array[Array] = [
		["RESUME RACE", func(): _toggle_pause()],
		["RESTART CIRCUIT", func(): get_tree().reload_current_scene()],
		["OPEN WORLD FREEROAM", func(): get_tree().change_scene_to_file("res://scenes/open_world.tscn")],
		["GARAGE AUTOSHOW", func(): get_tree().change_scene_to_file("res://scenes/garage.tscn")],
		["MAIN MENU", func(): get_tree().change_scene_to_file("res://scenes/main.tscn")]
	]
	for item: Array in items:
		var btn := Button.new()
		btn.text = str(item[0])
		btn.custom_minimum_size = Vector2(0, 38)
		btn.pressed.connect(item[1])
		vbox.add_child(btn)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_game"):
		_toggle_pause()

func _toggle_pause() -> void:
	if not pause_panel:
		return
	pause_panel.visible = not pause_panel.visible
	if race_mgr:
		if pause_panel.visible:
			race_mgr.state = RaceManager.RaceState.PAUSED
		else:
			race_mgr.state = RaceManager.RaceState.RACING

func _spawn_ai_rivals() -> void:
	var rivals: Array[Dictionary] = [
		{ "id": "dust_viper", "name": "Viktor 'Rotor' Hale", "style": "Aggressive", "pos": Vector3(-3.2, 0.9, -12.0), "front": "heavy_mg", "roof": "homing_missile" },
		{ "id": "gravel_fang", "name": "Mina Cross", "style": "Tactical", "pos": Vector3(3.2, 0.9, -18.0), "front": "twin_mg", "roof": "rocket_pod" },
		{ "id": "dune_reaper", "name": "Dozer Okafor", "style": "Bully", "pos": Vector3(-3.2, 0.9, -24.0), "front": "shotgun_cannon", "roof": "rocket_pod" },
		{ "id": "sand_striker", "name": "Lena Vash", "style": "Drifter", "pos": Vector3(3.2, 0.9, -30.0), "front": "twin_mg", "roof": "homing_missile" },
		{ "id": "phantom_gt", "name": "'Hollow' Pike", "style": "Trickster", "pos": Vector3(-3.2, 0.9, -36.0), "front": "heavy_mg", "roof": "rocket_pod" }
	]
	for r: Dictionary in rivals:
		var ai_car := VehicleController.new()
		ai_car.car_id = r["id"]
		ai_car.name = "AI_" + r["id"]
		add_child(ai_car)
		ai_car.global_position = r["pos"]
		ai_car.global_rotation = Vector3.ZERO
		ai_cars.append(ai_car)

		var driver := AIDriver.new()
		ai_car.add_child(driver)
		driver.setup(ai_car, spline_track, r["name"], r["style"])

		var ai_w := WeaponSystem.new()
		ai_car.add_child(ai_w)
		ai_w.setup(ai_car, r["front"], r["roof"], "mine_dropper")

func _spawn_pickups() -> void:
	if not spline_track or spline_track.track_points.size() < 60:
		return
	var pickup_types: Array = [
		TrackPickup.PickupType.REPAIR,
		TrackPickup.PickupType.AMMO,
		TrackPickup.PickupType.NITRO,
		TrackPickup.PickupType.REPAIR,
		TrackPickup.PickupType.AMMO,
		TrackPickup.PickupType.NITRO
	]
	var step: int = int(spline_track.track_points.size() / pickup_types.size())
	for i: int in range(pickup_types.size()):
		var pt: Dictionary = spline_track.track_points[i * step]
		var p := TrackPickup.new()
		p.type = pickup_types[i]
		add_child(p)
		p.position = pt["pos"] + Vector3(0, 1.2, 0)

func _physics_process(_delta: float) -> void:
	if not player_vehicle or (pause_panel and pause_panel.visible):
		return

	if player_weapons:
		if Input.is_action_pressed("fire_primary"):
			player_weapons.fire_front()
		if Input.is_action_just_pressed("fire_turret"):
			player_weapons.fire_roof()
		if Input.is_action_just_pressed("fire_rear"):
			player_weapons.fire_rear()

	if compositor_fx:
		compositor_fx.set_speed_norm(player_vehicle.speed_kmh / 260.0)

	if audio_engine:
		var max_slip: float = 0.0
		var surface: String = "asphalt_dry"
		for w in player_vehicle.wheels:
			var slip: float = absf(w.slip_angle) + absf(w.slip_ratio)
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

func _process(delta: float) -> void:
	if screenshot_mode:
		screenshot_timer -= delta
		if screenshot_timer <= 0.0:
			_capture_screenshot()
			get_tree().quit(0)

func _capture_screenshot() -> void:
	var dir := DirAccess.open("res://")
	if dir and not dir.dir_exists("build/screenshots"):
		dir.make_dir_recursive("build/screenshots")

	var target_filename: String = "m7_biome.png"
	var all_args: PackedStringArray = OS.get_cmdline_args()
	all_args.append_array(OS.get_cmdline_user_args())
	for arg: String in all_args:
		if arg.begins_with("--screenshot-name="):
			target_filename = arg.substr("--screenshot-name=".length())

	var viewport: Viewport = get_viewport()
	if viewport:
		var tex: ViewportTexture = viewport.get_texture()
		if tex:
			var img: Image = tex.get_image()
			if img and not img.is_empty():
				var full_path: String = "build/screenshots/" + target_filename
				img.save_png(full_path)
				print("[SCREENSHOT] Successfully saved " + full_path)
				return
	print("[SCREENSHOT] Completed frame capture pass")
