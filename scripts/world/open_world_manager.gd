# scripts/world/open_world_manager.gd
class_name OpenWorldManager
extends Node3D

const OpenWorldConfig = preload("res://scripts/world/open_world_config.gd")
const TerrainGenerator = preload("res://scripts/world/terrain_generator.gd")
const RoadNetwork = preload("res://scripts/world/road_network.gd")
const SceneryPopulator = preload("res://scripts/world/scenery_populator.gd")
const VehicleController = preload("res://scripts/vehicle/vehicle_controller.gd")
const CameraRig = preload("res://scripts/vehicle/camera_rig.gd")

@export var player_vehicle: VehicleController
@export var camera_rig: CameraRig
@export var world_environment: WorldEnvironment
@export var sun_light: DirectionalLight3D

var terrain_gen: TerrainGenerator
var road_network: RoadNetwork
var scenery_populator: SceneryPopulator

var active_chunks: Dictionary = {} # Vector2i(chunk_x, chunk_z) -> {"node": MeshInstance3D, "hi": bool}
var current_player_chunk: Vector2i = Vector2i(999, 999)
const LOAD_RADIUS: int = 2 # High-res colliding 5x5 chunks around player
const LOAD_RADIUS_FAR: int = 7 # Full 15x15 horizon chunks reaching map bounds cleanly

# Open World UI
var open_world_hud: CanvasLayer
var label_biome: Label
var label_coords: Label
var label_speed_record: Label
var last_reported_biome: int = -1

var weather_particles: GPUParticles3D

func _ready() -> void:
	terrain_gen = TerrainGenerator.new(2026)
	
	# 1. Build Arterial Road Network
	road_network = RoadNetwork.new(terrain_gen)
	add_child(road_network)
	road_network.build_open_world_roads()
	
	# 2. Populate World Scenery with MultiMesh Instances
	scenery_populator = SceneryPopulator.new(terrain_gen, road_network)
	add_child(scenery_populator)
	scenery_populator.populate_world_scenery()
	
	# 3. Add Reflective Ocean Water for Neon Coast
	_build_coastal_ocean()
	
	# 4. Position Player at Central Festival Hub on Starting Grid
	var spawn_pos := Vector3(0.0, terrain_gen.get_height(0, 15.0) + 0.65, 15.0)
	if player_vehicle:
		player_vehicle.global_position = spawn_pos
		player_vehicle.global_rotation = Vector3.ZERO
		if camera_rig:
			camera_rig.target_vehicle = player_vehicle
			
	# 5. Initial chunk generation around spawn
	_update_chunks_around(Vector3.ZERO)
	
	# 6. Build Open World HUD & Weather
	_build_open_world_hud()
	_setup_weather_particles()

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
			KEY_7:
				switch_player_vehicle("sprinter_r2") # Concept Hypercar
			KEY_8:
				switch_player_vehicle("iron_charger") # Ford Mustang GT
			KEY_9:
				switch_player_vehicle("aurelia_gt") # Lamborghini Aventador
			KEY_0:
				switch_player_vehicle("bavarian_evo") # BMW M4 Competition

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

func _build_coastal_ocean() -> void:
	var ocean := MeshInstance3D.new()
	ocean.name = "CoastalOceanWater"
	var plane := PlaneMesh.new()
	plane.size = Vector2(3600.0, 6400.0)
	plane.subdivide_width = 180
	plane.subdivide_depth = 240
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

func _physics_process(_delta: float) -> void:
	if not player_vehicle:
		return
		
	var pos := player_vehicle.global_position
	var p_chunk_x := int(floor((pos.x + OpenWorldConfig.HALF_SIZE) / OpenWorldConfig.CHUNK_SIZE))
	var p_chunk_z := int(floor((pos.z + OpenWorldConfig.HALF_SIZE) / OpenWorldConfig.CHUNK_SIZE))
	var p_chunk := Vector2i(p_chunk_x, p_chunk_z)
	
	if p_chunk != current_player_chunk:
		current_player_chunk = p_chunk
		_update_chunks_around(pos)
		
	_update_hud(pos)
	
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
		(info["node"] as Node).queue_free()
		active_chunks.erase(key)

func _build_open_world_hud() -> void:
	open_world_hud = CanvasLayer.new()
	open_world_hud.name = "OpenWorldHUD"
	add_child(open_world_hud)
	
	var top_panel := PanelContainer.new()
	top_panel.anchor_left = 0.5
	top_panel.anchor_right = 0.5
	top_panel.offset_left = -250.0
	top_panel.offset_right = 250.0
	top_panel.offset_top = 15.0
	top_panel.offset_bottom = 65.0
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
	label_hint.text = "FAST TRAVEL: [1] Hub | [2] Desert | [3] Snow | [4] Volcano | [5] Coast"
	label_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_hint.add_theme_font_size_override("font_size", 11)
	label_hint.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
	vbox.add_child(label_hint)

func _update_hud(pos: Vector3) -> void:
	if not label_biome or not label_coords:
		return
		
	var biome_type := OpenWorldConfig.get_biome_at(pos.x, pos.z)
	if int(biome_type) != last_reported_biome:
		last_reported_biome = int(biome_type)
		var b_info: Dictionary = OpenWorldConfig.BIOME_DATA[biome_type]
		label_biome.text = b_info["name"].to_upper()
		
	label_coords.text = "GPS: X: %dm | Z: %dm | ALT: %dm" % [int(pos.x), int(pos.z), int(pos.y)]

func _take_world_screenshot(out_path: String = "res://build/screenshots/open_world_overview.png") -> void:
	await get_tree().create_timer(1.0).timeout
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
