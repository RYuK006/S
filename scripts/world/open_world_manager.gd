# scripts/world/open_world_manager.gd
class_name OpenWorldManager
extends Node3D

const OpenWorldConfig = preload("res://scripts/world/open_world_config.gd")
const TerrainGenerator = preload("res://scripts/world/terrain_generator.gd")
const RoadNetwork = preload("res://scripts/world/road_network.gd")
const SceneryPopulator = preload("res://scripts/world/scenery_populator.gd")
const DestructiblePropManager = preload("res://scripts/world/destructible_prop_manager.gd")
const VehicleController = preload("res://scripts/vehicle/vehicle_controller.gd")
const CameraRig = preload("res://scripts/vehicle/camera_rig.gd")
const VisualPipeline = preload("res://scripts/core/visual_pipeline.gd")
const HorizonCompositorEffect = preload("res://scripts/core/horizon_compositor_effect.gd")
const DebugOverlay = preload("res://scripts/ui/debug_overlay.gd")

@export var player_vehicle: VehicleController
@export var camera_rig: CameraRig
@export var world_environment: WorldEnvironment
@export var sun_light: DirectionalLight3D

var terrain_gen: TerrainGenerator
var road_network: RoadNetwork
var scenery_populator: SceneryPopulator
var destruct_manager: DestructiblePropManager

var active_chunks: Dictionary = {} # Vector2i(chunk_x, chunk_z) -> {"node": MeshInstance3D, "hi": bool}
var current_player_chunk: Vector2i = Vector2i(999, 999)
const LOAD_RADIUS: int = 2 # High-res colliding 5x5 chunks around player
const LOAD_RADIUS_FAR: int = 5 # 11x11 horizon chunks (5.5km coverage, seamless fog blend)

# Open World UI
var open_world_hud: CanvasLayer
var label_biome: Label
var label_coords: Label
var label_speed_record: Label
var label_ow_speed: Label
var label_ow_gear_rpm: Label
var bar_ow_rpm: ProgressBar
var bar_ow_nitro: ProgressBar
var pause_panel: PanelContainer
var last_reported_biome: int = -1

var weather_particles: GPUParticles3D
var compositor_fx: HorizonCompositorEffect

func _ready() -> void:
	terrain_gen = TerrainGenerator.new(2026)
	
	# 1. Build Arterial Road Network
	road_network = RoadNetwork.new(terrain_gen)
	add_child(road_network)
	road_network.build_open_world_roads()
	
	# 2. Populate World Scenery & Heterogeneous Physics Destruction Pool
	destruct_manager = DestructiblePropManager.new()
	destruct_manager.name = "DestructiblePropManager"
	add_child(destruct_manager)
	scenery_populator = SceneryPopulator.new(terrain_gen, road_network, destruct_manager)
	add_child(scenery_populator)
	scenery_populator.populate_world_scenery()
	
	# 3. Add Reflective Ocean Water for Neon Coast
	_build_coastal_ocean()
	
	# 4. Position Player at Central Festival Hub on Starting Grid (honor Garage selected car)
	var save_mgr := SaveManager.new()
	var chosen_car: String = str(save_mgr.save_data.get("selected_car", "skyline_vspec"))
	if player_vehicle and chosen_car != "sprinter_r2" and chosen_car != player_vehicle.car_id:
		player_vehicle.car_id = chosen_car
	var spawn_pos := Vector3(0.0, terrain_gen.get_height(0, 15.0) + 0.65, 15.0)
	if player_vehicle:
		player_vehicle.global_position = spawn_pos
		player_vehicle.global_rotation = Vector3.ZERO
		if camera_rig:
			camera_rig.target_vehicle = player_vehicle
		var dbg := get_node_or_null("DebugOverlay") as DebugOverlay
		if dbg:
			dbg.set_target_vehicle(player_vehicle)
			
	# 5. Initial chunk generation around spawn
	_update_chunks_around(Vector3.ZERO)
	
	# 6. Build Open World HUD, Weather, CompositorEffect, and Startup Shader Pre-Warming
	_build_open_world_hud()
	_setup_weather_particles()
	if world_environment:
		compositor_fx = VisualPipeline.attach_horizon_compositor(world_environment, 0.14, 0.12)
	var prewarm_mats: Array[Material] = []
	VisualPipeline.collect_materials_from_node(self, prewarm_mats)
	if camera_rig and camera_rig.camera:
		VisualPipeline.spawn_prewarm_batch(self, camera_rig.camera, prewarm_mats)

func _setup_weather_particles() -> void:
	weather_particles = GPUParticles3D.new()
	weather_particles.name = "BiomeWeatherParticles"
	weather_particles.emitting = false
	weather_particles.amount = 350
	weather_particles.lifetime = 4.0
	weather_particles.preprocess = 2.0
	
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(45.0, 18.0, 45.0)
	mat.direction = Vector3(0.3, -1.0, 0.2).normalized()
	mat.spread = 15.0
	mat.initial_velocity_min = 2.5
	mat.initial_velocity_max = 6.0
	mat.gravity = Vector3(0.0, -2.5, 0.0)
	mat.scale_min = 0.04
	mat.scale_max = 0.12
	weather_particles.process_material = mat
	
	var p_img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for py: int in range(32):
		for px: int in range(32):
			var d: float = Vector2(float(px) - 15.5, float(py) - 15.5).length() / 15.5
			var a: float = clampf(1.0 - smoothstep(0.15, 0.98, d), 0.0, 1.0)
			p_img.set_pixel(px, py, Color(1.0, 1.0, 1.0, a * a))
	var p_tex := ImageTexture.create_from_image(p_img)

	var quad := QuadMesh.new()
	quad.size = Vector2(0.16, 0.16)
	var p_mat := StandardMaterial3D.new()
	p_mat.albedo_color = Color(0.95, 0.98, 1.0, 0.82)
	p_mat.albedo_texture = p_tex
	p_mat.vertex_color_use_as_albedo = true
	p_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	p_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	p_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	quad.material = p_mat
	weather_particles.draw_pass_1 = quad
	
	add_child(weather_particles)
	
	# 7. Screenshot command check
	var all_args := OS.get_cmdline_args()
	all_args.append_array(OS.get_cmdline_user_args())
	for arg in all_args:
		if arg == "--screenshot-volcano":
			_teleport_to_road("Volcano Ridge", 0.56)
			_take_world_screenshot("res://build/screenshots/open_world_volcano.png")
		elif arg == "--screenshot-snow":
			_teleport_to_road("Frozen Pass", 0.48)
			_take_world_screenshot("res://build/screenshots/open_world_snow.png")
		elif arg == "--screenshot-desert" or arg == "--screenshot-dust-bowl":
			_teleport_to_road("Dust Bowl", 0.52)
			_take_world_screenshot("res://build/screenshots/open_world_desert.png")
		elif arg == "--screenshot-coast":
			_teleport_to_road("Neon Coastline", 0.25)
			_take_world_screenshot("res://build/screenshots/open_world_coast.png")
		elif arg == "--screenshot-hub" or arg == "--screenshot" or arg == "-screenshot":
			_teleport_to_biome(Vector3(0.0, 0.0, 15.0), 0.0)
			_take_world_screenshot("res://build/screenshots/open_world_hub.png")
		elif arg == "--screenshot-mustang":
			switch_player_vehicle("iron_charger")
			_teleport_to_biome(Vector3(0.0, 0.0, 15.0), 0.0)
			_take_world_screenshot("res://build/screenshots/open_world_mustang.png")
		elif arg == "--screenshot-aventador":
			switch_player_vehicle("aurelia_gt")
			_teleport_to_biome(Vector3(0.0, 0.0, 15.0), 0.0)
			_take_world_screenshot("res://build/screenshots/open_world_aventador.png")
		elif arg == "--screenshot-bmw":
			switch_player_vehicle("bavarian_evo")
			_teleport_to_biome(Vector3(0.0, 0.0, 15.0), 0.0)
			_take_world_screenshot("res://build/screenshots/open_world_bmw.png")
		elif arg == "--screenshot-gtr":
			switch_player_vehicle("skyline_vspec")
			_teleport_to_biome(Vector3(0.0, 0.0, 15.0), 0.0)
			_take_world_screenshot("res://build/screenshots/open_world_gtr.png")
		elif arg == "--screenshot-p1":
			switch_player_vehicle("vandal_hyper")
			_teleport_to_biome(Vector3(0.0, 0.0, 15.0), 0.0)
			_take_world_screenshot("res://build/screenshots/open_world_p1.png")
		elif arg == "--screenshot-porsche":
			switch_player_vehicle("turbo_930")
			_teleport_to_biome(Vector3(0.0, 0.0, 15.0), 0.0)
			_take_world_screenshot("res://build/screenshots/open_world_porsche.png")

func _teleport_to_road(road_substr: String, t_norm: float) -> void:
	if road_network:
		var pose: Dictionary = road_network.get_road_pose(road_substr, t_norm)
		var rp: Vector3 = pose["pos"]
		var ry: float = float(pose["yaw"])
		_teleport_to_biome(rp, ry)
		return
	_teleport_to_biome(Vector3(0.0, 0.0, 15.0), 0.0)

func _teleport_to_biome(target_xz: Vector3, yaw_rad: float = 0.0) -> void:
	var base_y: float = target_xz.y if target_xz.y > 0.5 else terrain_gen.get_height(target_xz.x, target_xz.z)
	var y: float = maxf(base_y, terrain_gen.get_height(target_xz.x, target_xz.z)) + 0.55
	var final_pos := Vector3(target_xz.x, y, target_xz.z)
	if player_vehicle:
		player_vehicle.global_position = final_pos
		player_vehicle.global_rotation = Vector3(0, yaw_rad, 0)
		player_vehicle.linear_velocity = Vector3.ZERO
		player_vehicle.angular_velocity = Vector3.ZERO
	if camera_rig:
		camera_rig.snap_to_target()
	_update_chunks_around(final_pos)
	if weather_particles:
		weather_particles.global_position = final_pos + Vector3(0.0, 8.0, 0.0)
		weather_particles.restart()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_game"):
		if pause_panel:
			pause_panel.visible = not pause_panel.visible
			get_tree().paused = pause_panel.visible
		return
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1:
				_teleport_to_biome(Vector3(0.0, 0.0, 15.0), 0.0) # Festival Hub
			KEY_2:
				_teleport_to_road("Dust Bowl", 0.52)
			KEY_3:
				_teleport_to_road("Frozen Pass", 0.48)
			KEY_4:
				_teleport_to_road("Volcano Ridge", 0.52)
			KEY_5:
				_teleport_to_road("Neon Coastline", 0.25)
			KEY_6:
				_cycle_fleet_vehicle(1)
			KEY_7:
				switch_player_vehicle("sprinter_r2") # Concept Hypercar
			KEY_8:
				switch_player_vehicle("iron_charger") # Ford Mustang GT
			KEY_9:
				switch_player_vehicle("aurelia_gt") # Lamborghini Aventador
			KEY_0:
				switch_player_vehicle("bavarian_evo") # BMW M4 Competition

func _cycle_fleet_vehicle(step: int) -> void:
	var f := FileAccess.open("res://data/vehicles.json", FileAccess.READ)
	if not f:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if not (parsed is Dictionary):
		return
	var list: Array = parsed.get("vehicles", [])
	if list.is_empty():
		return
	var cur_id: String = player_vehicle.car_id if player_vehicle else ""
	var cur_i: int = 0
	for i: int in range(list.size()):
		if str((list[i] as Dictionary).get("id", "")) == cur_id:
			cur_i = i
			break
	var next_i: int = posmod(cur_i + step, list.size())
	var next_id: String = str((list[next_i] as Dictionary).get("id", "sprinter_r2"))
	switch_player_vehicle(next_id)

func switch_player_vehicle(car_id_to_spawn: String) -> void:
	if not player_vehicle:
		return
	var old_pos := player_vehicle.global_position
	var old_rot := player_vehicle.global_rotation
	var old_vel := player_vehicle.linear_velocity
	var old_ang := player_vehicle.angular_velocity
	
	player_vehicle.free()
	
	var new_v := VehicleController.new()
	new_v.name = "PlayerVehicle"
	new_v.car_id = car_id_to_spawn
	add_child(new_v)
	new_v.global_position = old_pos
	new_v.global_rotation = old_rot
	new_v.linear_velocity = old_vel
	new_v.angular_velocity = old_ang
	player_vehicle = new_v
	
	if camera_rig:
		camera_rig.target_vehicle = new_v
		camera_rig.snap_to_target()
	var dbg := get_node_or_null("DebugOverlay") as DebugOverlay
	if dbg:
		dbg.set_target_vehicle(new_v)

func _build_coastal_ocean() -> void:
	var ocean := MeshInstance3D.new()
	ocean.name = "CoastalOceanWater"
	ocean.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var plane := PlaneMesh.new()
	plane.size = Vector2(3600.0, 6400.0)
	plane.subdivide_width = 72
	plane.subdivide_depth = 110
	ocean.mesh = plane
	ocean.position = Vector3(3650.0, 0.85, 1100.0)
	
	var water_shader := load("res://shaders/ocean_water.gdshader") as Shader
	if water_shader:
		var s_mat := ShaderMaterial.new()
		s_mat.shader = water_shader
		ocean.material_override = s_mat
	else:
		var water_mat := StandardMaterial3D.new()
		water_mat.albedo_color = Color(0.06, 0.22, 0.44, 0.88)
		water_mat.roughness = 0.08
		water_mat.metallic = 0.35
		water_mat.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
		ocean.material_override = water_mat
	add_child(ocean)

func _physics_process(delta: float) -> void:
	if not player_vehicle:
		return
	if destruct_manager:
		destruct_manager.step_physics(player_vehicle, delta)
		
	var pos := player_vehicle.global_position
	var p_chunk_x := int(floor((pos.x + OpenWorldConfig.HALF_SIZE) / OpenWorldConfig.CHUNK_SIZE))
	var p_chunk_z := int(floor((pos.z + OpenWorldConfig.HALF_SIZE) / OpenWorldConfig.CHUNK_SIZE))
	var p_chunk := Vector2i(p_chunk_x, p_chunk_z)
	
	if p_chunk != current_player_chunk:
		current_player_chunk = p_chunk
		_update_chunks_around(pos)
		
	_update_hud(pos)
	if compositor_fx:
		compositor_fx.set_speed_norm(player_vehicle.speed_kmh / 260.0)
	
	if weather_particles:
		weather_particles.global_position = pos + Vector3(0.0, 8.0, 0.0)
		var biome_type := OpenWorldConfig.get_biome_at(pos.x, pos.z)
		var mat := weather_particles.process_material as ParticleProcessMaterial
		if mat:
			match biome_type:
				OpenWorldConfig.BiomeType.VOLCANO_RIDGE:
					weather_particles.emitting = true
					mat.gravity = Vector3(0.0, 1.8, 0.0)
					mat.color = Color(1.0, 0.45, 0.1, 0.85)
				OpenWorldConfig.BiomeType.FROZEN_PASS:
					weather_particles.emitting = true
					mat.gravity = Vector3(0.0, -2.5, 0.0)
					mat.color = Color(0.95, 0.98, 1.0, 0.8)
				OpenWorldConfig.BiomeType.DUST_BOWL:
					weather_particles.emitting = true
					mat.gravity = Vector3(1.2, -0.8, 0.5)
					mat.color = Color(0.85, 0.72, 0.55, 0.6)
				_:
					# Sunny clear festival conditions at Hub & Coastal Resort
					weather_particles.emitting = false

func _update_chunks_around(pos: Vector3) -> void:
	var center_cx := int(floor((pos.x + OpenWorldConfig.HALF_SIZE) / OpenWorldConfig.CHUNK_SIZE))
	var center_cz := int(floor((pos.z + OpenWorldConfig.HALF_SIZE) / OpenWorldConfig.CHUNK_SIZE))
	
	var needed_keys: Dictionary = {}
	
	for cz in range(center_cz - LOAD_RADIUS_FAR, center_cz + LOAD_RADIUS_FAR + 1):
		for cx in range(center_cx - LOAD_RADIUS_FAR, center_cx + LOAD_RADIUS_FAR + 1):
			if cx >= 0 and cx < OpenWorldConfig.GRID_CHUNKS and cz >= 0 and cz < OpenWorldConfig.GRID_CHUNKS:
				var key := Vector2i(cx, cz)
				var is_hi: bool = absf(float(cx - center_cx)) <= LOAD_RADIUS and absf(float(cz - center_cz)) <= LOAD_RADIUS
				needed_keys[key] = is_hi
				var needs_rebuild: bool = not active_chunks.has(key)
				if not needs_rebuild:
					var info: Dictionary = active_chunks[key]
					if bool(info["hi"]) != is_hi:
						(info["node"] as Node).queue_free()
						needs_rebuild = true
				if needs_rebuild:
					var res: int = 56 if is_hi else 14
					var chunk_mesh := terrain_gen.generate_chunk_mesh(cx, cz, res, is_hi)
					add_child(chunk_mesh)
					active_chunks[key] = {"node": chunk_mesh, "hi": is_hi}
					
	var to_remove: Array[Vector2i] = []
	for key in active_chunks.keys():
		if not needed_keys.has(key):
			to_remove.append(key)
			
	for key in to_remove:
		var info: Dictionary = active_chunks[key]
		var old_chunk: MeshInstance3D = info["node"] as MeshInstance3D
		if old_chunk:
			old_chunk.mesh = null
			old_chunk.queue_free()
		active_chunks.erase(key)

func _build_open_world_hud() -> void:
	open_world_hud = CanvasLayer.new()
	open_world_hud.name = "OpenWorldHUD"
	open_world_hud.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(open_world_hud)
	
	var top_panel := PanelContainer.new()
	top_panel.anchor_left = 0.5
	top_panel.anchor_right = 0.5
	top_panel.offset_left = -280.0
	top_panel.offset_right = 280.0
	top_panel.offset_top = 14.0
	top_panel.offset_bottom = 70.0
	open_world_hud.add_child(top_panel)
	
	var vbox := VBoxContainer.new()
	top_panel.add_child(vbox)
	
	label_biome = Label.new()
	label_biome.text = "HORIZON FESTIVAL CENTRAL"
	label_biome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_biome.add_theme_color_override("font_color", Color(1.0, 0.45, 0.0))
	vbox.add_child(label_biome)
	
	label_coords = Label.new()
	label_coords.text = "GPS: X: 0m | Z: 0m | ALT: 22m"
	label_coords.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_coords.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
	vbox.add_child(label_coords)
	
	var label_hint := Label.new()
	label_hint.text = "[1-5] Fast Travel | [6] Next Car | [7-0] Presets | [F3] Perf | [Esc] Menu"
	label_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_hint.add_theme_font_size_override("font_size", 11)
	label_hint.add_theme_color_override("font_color", Color(0.65, 0.75, 0.86))
	vbox.add_child(label_hint)

	# Bottom-Right FH5 Tachometer / Speedo / Nitro Cluster
	var speed_panel := PanelContainer.new()
	speed_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	speed_panel.offset_left = -290.0
	speed_panel.offset_top = -150.0
	speed_panel.offset_right = -24.0
	speed_panel.offset_bottom = -20.0
	var s_style := StyleBoxFlat.new()
	s_style.bg_color = Color(0.05, 0.07, 0.11, 0.78)
	s_style.border_width_bottom = 3
	s_style.border_color = Color(1.0, 0.45, 0.06, 0.95)
	s_style.content_margin_left = 14
	s_style.content_margin_right = 14
	s_style.content_margin_top = 8
	s_style.content_margin_bottom = 10
	s_style.corner_radius_top_left = 6
	s_style.corner_radius_top_right = 6
	s_style.corner_radius_bottom_left = 6
	s_style.corner_radius_bottom_right = 6
	speed_panel.add_theme_stylebox_override("panel", s_style)
	open_world_hud.add_child(speed_panel)

	var svbox := VBoxContainer.new()
	svbox.add_theme_constant_override("separation", 4)
	speed_panel.add_child(svbox)

	label_ow_speed = Label.new()
	label_ow_speed.text = "0 KM/H"
	label_ow_speed.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label_ow_speed.add_theme_font_size_override("font_size", 42)
	label_ow_speed.add_theme_color_override("font_color", Color(0.95, 0.98, 1.0))
	svbox.add_child(label_ow_speed)

	label_ow_gear_rpm = Label.new()
	label_ow_gear_rpm.text = "GEAR 1  |  900 RPM"
	label_ow_gear_rpm.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label_ow_gear_rpm.add_theme_font_size_override("font_size", 15)
	label_ow_gear_rpm.add_theme_color_override("font_color", Color(1.0, 0.65, 0.12))
	svbox.add_child(label_ow_gear_rpm)

	bar_ow_rpm = ProgressBar.new()
	bar_ow_rpm.min_value = 0.0
	bar_ow_rpm.max_value = 8500.0
	bar_ow_rpm.value = 900.0
	bar_ow_rpm.show_percentage = false
	bar_ow_rpm.custom_minimum_size = Vector2(220, 8)
	svbox.add_child(bar_ow_rpm)

	bar_ow_nitro = ProgressBar.new()
	bar_ow_nitro.min_value = 0.0
	bar_ow_nitro.max_value = 100.0
	bar_ow_nitro.value = 100.0
	bar_ow_nitro.show_percentage = false
	bar_ow_nitro.custom_minimum_size = Vector2(220, 6)
	svbox.add_child(bar_ow_nitro)

	# Esc Pause & Mode Switch Menu
	pause_panel = PanelContainer.new()
	pause_panel.set_anchors_preset(Control.PRESET_CENTER)
	pause_panel.offset_left = -180.0
	pause_panel.offset_top = -155.0
	pause_panel.offset_right = 180.0
	pause_panel.offset_bottom = 155.0
	pause_panel.visible = false
	open_world_hud.add_child(pause_panel)

	var pvbox := VBoxContainer.new()
	pvbox.add_theme_constant_override("separation", 10)
	pause_panel.add_child(pvbox)

	var ptitle := Label.new()
	ptitle.text = "GRIDLETHAL HORIZON MENU"
	ptitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ptitle.add_theme_font_size_override("font_size", 20)
	ptitle.add_theme_color_override("font_color", Color(1.0, 0.50, 0.08))
	pvbox.add_child(ptitle)

	var actions: Array[Array] = [
		["RESUME DRIVING", Callable(self, "_on_pause_resume")],
		["CIRCUIT COMBAT RACE", Callable(self, "_on_pause_circuit")],
		["GARAGE AUTOSHOW", Callable(self, "_on_pause_garage")],
		["TOGGLE F3 VRAM TELEMETRY", Callable(self, "_on_pause_telemetry")],
		["MAIN MENU", Callable(self, "_on_pause_menu")]
	]
	for act: Array in actions:
		var btn := Button.new()
		btn.text = str(act[0])
		btn.custom_minimum_size = Vector2(0, 36)
		btn.pressed.connect(act[1] as Callable)
		pvbox.add_child(btn)

func _on_pause_resume() -> void:
	if pause_panel:
		pause_panel.visible = false
	get_tree().paused = false

func _on_pause_circuit() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/track_test.tscn")

func _on_pause_garage() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/garage.tscn")

func _on_pause_telemetry() -> void:
	var dbg := get_node_or_null("DebugOverlay") as DebugOverlay
	if dbg:
		dbg.toggle_visible()

func _on_pause_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _update_hud(pos: Vector3) -> void:
	if not label_biome or not label_coords:
		return
		
	var biome_type := OpenWorldConfig.get_biome_at(pos.x, pos.z)
	if int(biome_type) != last_reported_biome:
		last_reported_biome = int(biome_type)
		var b_info: Dictionary = OpenWorldConfig.BIOME_DATA[biome_type]
		label_biome.text = b_info["name"].to_upper()
		if player_vehicle:
			var p := player_vehicle.get_node_or_null("CarDynamicReflectionProbe") as ReflectionProbe
			if p:
				p.update_mode = ReflectionProbe.UPDATE_ONCE
		
	label_coords.text = "GPS: X: %dm | Z: %dm | ALT: %dm" % [int(pos.x), int(pos.z), int(pos.y)]
	if player_vehicle and label_ow_speed and label_ow_gear_rpm:
		label_ow_speed.text = "%d KM/H" % int(roundf(player_vehicle.speed_kmh))
		var g_str: String = "R" if player_vehicle.current_gear == 0 else str(player_vehicle.current_gear)
		label_ow_gear_rpm.text = "GEAR %s  |  %d RPM" % [g_str, int(player_vehicle.engine_rpm)]
		if bar_ow_rpm:
			bar_ow_rpm.value = player_vehicle.engine_rpm
		if bar_ow_nitro:
			bar_ow_nitro.value = player_vehicle.nitro_amount

func _take_world_screenshot(out_path: String = "res://build/screenshots/open_world_overview.png") -> void:
	await get_tree().create_timer(1.8).timeout
	var vp := get_viewport()
	if vp:
		var img := vp.get_texture().get_image()
		if img and not img.is_empty():
			var dir := DirAccess.open("res://")
			if dir and not dir.dir_exists("build/screenshots"):
				dir.make_dir_recursive("build/screenshots")
			img.save_png(out_path)
			print("[SCREENSHOT] Successfully saved %s" % out_path)
	get_tree().quit(0)
