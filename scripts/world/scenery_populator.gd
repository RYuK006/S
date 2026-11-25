# scripts/world/scenery_populator.gd
class_name SceneryPopulator
extends Node3D

const TerrainGenerator = preload("res://scripts/world/terrain_generator.gd")
const RoadNetwork = preload("res://scripts/world/road_network.gd")
const OpenWorldConfig = preload("res://scripts/world/open_world_config.gd")

var terrain_gen: TerrainGenerator
var road_network: RoadNetwork

func _init(tg: TerrainGenerator = null, rn: RoadNetwork = null) -> void:
	terrain_gen = tg if tg else TerrainGenerator.new()
	road_network = rn

func populate_world_scenery() -> void:
	# 1. Highway Light Poles & Guardrails along Perimeter Highway
	if road_network and road_network.highway_waypoints.size() > 0:
		_populate_highway_props()
		
	# 2. Regional Biome Foliage & Rock MultiMeshes
	_populate_alpine_pines(400)
	_populate_desert_rocks_and_cacti(400)
	_populate_volcanic_spires(300)
	_populate_shipping_containers(250)
	_populate_festival_banners()

func _populate_highway_props() -> void:
	var wps := road_network.highway_waypoints
	var count := wps.size()
	
	# Light Poles MultiMesh
	var pole_mesh := CylinderMesh.new()
	pole_mesh.top_radius = 0.12
	pole_mesh.bottom_radius = 0.18
	pole_mesh.height = 7.5
	
	var pole_mat := StandardMaterial3D.new()
	pole_mat.albedo_color = Color(0.2, 0.22, 0.25)
	pole_mat.metallic = 0.85
	pole_mat.roughness = 0.25
	
	var mm_poles := MultiMesh.new()
	mm_poles.transform_format = MultiMesh.TRANSFORM_3D
	mm_poles.mesh = pole_mesh
	mm_poles.instance_count = count * 2 # Both sides of highway
	
	for i in range(count):
		var p := wps[i]
		var next_p := wps[(i + 1) % count]
		var fwd := (next_p - p).normalized()
		var right := fwd.cross(Vector3.UP).normalized()
		
		var left_pos := p - (right * 8.5)
		var right_pos := p + (right * 8.5)
		left_pos.y = terrain_gen.get_height(left_pos.x, left_pos.z) + 3.75
		right_pos.y = terrain_gen.get_height(right_pos.x, right_pos.z) + 3.75
		
		mm_poles.set_instance_transform(i * 2, Transform3D(Basis(), left_pos))
		mm_poles.set_instance_transform(i * 2 + 1, Transform3D(Basis(), right_pos))
		
	var inst_poles := MultiMeshInstance3D.new()
	inst_poles.multimesh = mm_poles
	inst_poles.material_override = pole_mat
	inst_poles.name = "MultiMesh_HighwayPoles"
	add_child(inst_poles)

func _populate_alpine_pines(count: int) -> void:
	var cone_mesh := CylinderMesh.new()
	cone_mesh.top_radius = 0.05
	cone_mesh.bottom_radius = 2.2
	cone_mesh.height = 8.0
	
	var pine_mat := StandardMaterial3D.new()
	pine_mat.albedo_color = Color(0.08, 0.22, 0.12)
	pine_mat.roughness = 0.8
	
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = cone_mesh
	mm.instance_count = count
	
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	
	for i in range(count):
		# Frozen Pass quadrant (North-West: x in -1800 to -200, z in -1800 to -200)
		var x := rng.randf_range(-1800.0, -250.0)
		var z := rng.randf_range(-1800.0, -250.0)
		var y := terrain_gen.get_height(x, z) + 4.0
		var s := rng.randf_range(0.7, 1.4)
		var basis := Basis().scaled(Vector3(s, s, s))
		mm.set_instance_transform(i, Transform3D(basis, Vector3(x, y, z)))
		
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	inst.material_override = pine_mat
	inst.name = "MultiMesh_AlpinePines"
	add_child(inst)

func _populate_desert_rocks_and_cacti(count: int) -> void:
	var rock_mesh := BoxMesh.new()
	rock_mesh.size = Vector3(4.5, 3.5, 5.0)
	
	var rock_mat := StandardMaterial3D.new()
	rock_mat.albedo_color = Color(0.65, 0.45, 0.28)
	rock_mat.roughness = 0.9
	
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = rock_mesh
	mm.instance_count = count
	
	var rng := RandomNumberGenerator.new()
	rng.seed = 3030
	
	for i in range(count):
		# Dust Bowl quadrant (South-West: x in -1800 to -250, z in 250 to 1800)
		var x := rng.randf_range(-1800.0, -250.0)
		var z := rng.randf_range(250.0, 1800.0)
		var y := terrain_gen.get_height(x, z) + 1.2
		var rot_y := rng.randf_range(0, TAU)
		var s := rng.randf_range(0.6, 2.2)
		var basis := Basis(Vector3.UP, rot_y).scaled(Vector3(s, s * 0.8, s))
		mm.set_instance_transform(i, Transform3D(basis, Vector3(x, y, z)))
		
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	inst.material_override = rock_mat
	inst.name = "MultiMesh_DesertRocks"
	add_child(inst)

func _populate_volcanic_spires(count: int) -> void:
	var spire_mesh := PrismMesh.new()
	spire_mesh.size = Vector3(5.0, 14.0, 5.0)
	
	var spire_mat := StandardMaterial3D.new()
	spire_mat.albedo_color = Color(0.12, 0.08, 0.08)
	spire_mat.roughness = 0.95
	
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = spire_mesh
	mm.instance_count = count
	
	var rng := RandomNumberGenerator.new()
	rng.seed = 4040
	
	for i in range(count):
		# Volcano Ridge quadrant (North-East: x in 250 to 1800, z in -1800 to -250)
		var x := rng.randf_range(250.0, 1800.0)
		var z := rng.randf_range(-1800.0, -250.0)
		var y := terrain_gen.get_height(x, z) + 6.0
		var rot_y := rng.randf_range(0, TAU)
		var s := rng.randf_range(0.8, 2.5)
		var basis := Basis(Vector3.UP, rot_y).scaled(Vector3(s, s, s))
		mm.set_instance_transform(i, Transform3D(basis, Vector3(x, y, z)))
		
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	inst.material_override = spire_mat
	inst.name = "MultiMesh_VolcanicSpires"
	add_child(inst)

func _populate_shipping_containers(count: int) -> void:
	var cont_mesh := BoxMesh.new()
	cont_mesh.size = Vector3(2.4, 2.6, 6.0)
	
	var colors := [Color(0.8, 0.2, 0.1), Color(0.1, 0.4, 0.8), Color(0.1, 0.7, 0.3), Color(0.9, 0.6, 0.1)]
	var cont_mat := StandardMaterial3D.new()
	cont_mat.albedo_color = Color(0.25, 0.45, 0.75)
	cont_mat.roughness = 0.4
	cont_mat.metallic = 0.7
	
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = cont_mesh
	mm.instance_count = count
	
	var rng := RandomNumberGenerator.new()
	rng.seed = 5050
	
	for i in range(count):
		# Neon Docks quadrant (South-East: x in 250 to 1800, z in 250 to 1800)
		var x := rng.randf_range(300.0, 1750.0)
		var z := rng.randf_range(300.0, 1750.0)
		var y := terrain_gen.get_height(x, z) + 1.3
		var rot_y := float(rng.randi_range(0, 3)) * (PI * 0.5)
		var basis := Basis(Vector3.UP, rot_y)
		mm.set_instance_transform(i, Transform3D(basis, Vector3(x, y, z)))
		
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	inst.material_override = cont_mat
	inst.name = "MultiMesh_ShippingContainers"
	add_child(inst)

func _populate_festival_banners() -> void:
	# Festival Arch at Central Hub (x=0, z=0)
	var arch := Node3D.new()
	arch.name = "Festival_Arch_Center"
	var y := terrain_gen.get_height(0, 0)
	arch.position = Vector3(0, y, 0)
	
	var beam := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(24.0, 1.8, 1.2)
	beam.mesh = box
	beam.position = Vector3(0, 9.0, 0)
	
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.35, 0.0) # Radiant Horizon Orange
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.35, 0.0)
	mat.emission_energy_multiplier = 2.5
	beam.material_override = mat
	arch.add_child(beam)
	add_child(arch)
