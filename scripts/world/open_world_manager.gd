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

var active_chunks: Dictionary = {} # Vector2i(chunk_x, chunk_z) -> MeshInstance3D
var current_player_chunk: Vector2i = Vector2i(999, 999)
const LOAD_RADIUS: int = 2 # 5x5 chunks active around player

# Open World UI
var open_world_hud: CanvasLayer
var label_biome: Label
var label_coords: Label
var label_speed_record: Label
var last_reported_biome: int = -1

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
	
	# 3. Position Player at Central Festival Hub
	var spawn_pos := Vector3(0, terrain_gen.get_height(0, 0) + 1.2, 0)
	if player_vehicle:
		player_vehicle.global_position = spawn_pos
		player_vehicle.global_rotation = Vector3.ZERO
		if camera_rig:
			camera_rig.target_vehicle = player_vehicle
			
	# 4. Initial chunk generation around spawn
	_update_chunks_around(Vector3.ZERO)
	
	# 5. Build Open World HUD
	_build_open_world_hud()
	
	# 6. Screenshot command check
	for arg in OS.get_cmdline_args():
		if arg == "--screenshot-dust-bowl":
			var db_pos := Vector3(-331.0, terrain_gen.get_height(-331.0, 482.0) + 1.2, 482.0)
			if player_vehicle:
				player_vehicle.global_position = db_pos
				player_vehicle.global_rotation = Vector3(0, PI * 0.25, 0)
				_update_chunks_around(db_pos)
			_take_world_screenshot("res://build/screenshots/open_world_dust_bowl.png")
		elif arg == "--screenshot" or arg == "-screenshot":
			_take_world_screenshot("res://build/screenshots/open_world_overview.png")

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

func _update_chunks_around(pos: Vector3) -> void:
	var center_cx := int(floor((pos.x + OpenWorldConfig.HALF_SIZE) / OpenWorldConfig.CHUNK_SIZE))
	var center_cz := int(floor((pos.z + OpenWorldConfig.HALF_SIZE) / OpenWorldConfig.CHUNK_SIZE))
	
	var needed_keys: Dictionary = {}
	
	for cz in range(center_cz - LOAD_RADIUS, center_cz + LOAD_RADIUS + 1):
		for cx in range(center_cx - LOAD_RADIUS, center_cx + LOAD_RADIUS + 1):
			if cx >= 0 and cx < OpenWorldConfig.GRID_CHUNKS and cz >= 0 and cz < OpenWorldConfig.GRID_CHUNKS:
				var key := Vector2i(cx, cz)
				needed_keys[key] = true
				if not active_chunks.has(key):
					var chunk_mesh := terrain_gen.generate_chunk_mesh(cx, cz, 24)
					add_child(chunk_mesh)
					active_chunks[key] = chunk_mesh
					
	# Cull distant chunks outside radius
	var to_remove: Array[Vector2i] = []
	for key in active_chunks.keys():
		if not needed_keys.has(key):
			to_remove.append(key)
			
	for key in to_remove:
		var node: Node = active_chunks[key]
		node.queue_free()
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
	await get_tree().create_timer(0.8).timeout
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
