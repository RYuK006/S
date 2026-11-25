# scripts/world/scenery_populator.gd
class_name SceneryPopulator
extends Node3D

const TerrainGenerator = preload("res://scripts/world/terrain_generator.gd")
const RoadNetwork = preload("res://scripts/world/road_network.gd")
const OpenWorldConfig = preload("res://scripts/world/open_world_config.gd")

var terrain_gen: TerrainGenerator
var road_network: RoadNetwork
var shared_palette_mat: StandardMaterial3D

func _get_palette_mat() -> StandardMaterial3D:
	if not shared_palette_mat:
		shared_palette_mat = StandardMaterial3D.new()
		var tex := load("res://assets/models/props/Textures/colormap.png") as Texture2D
		if tex:
			shared_palette_mat.albedo_texture = tex
		shared_palette_mat.roughness = 0.65
		shared_palette_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	return shared_palette_mat

func _assign_palette_recursive(node: Node, mat: Material) -> void:
	if node is MeshInstance3D:
		node.material_override = mat
	for child in node.get_children():
		_assign_palette_recursive(child, mat)

func _init(tg: TerrainGenerator = null, rn: RoadNetwork = null) -> void:
	terrain_gen = tg if tg else TerrainGenerator.new()
	road_network = rn

func populate_world_scenery() -> void:
	# 1. Highway Light Poles & Guardrails along Perimeter Highway
	if road_network and road_network.highway_waypoints.size() > 0:
		_populate_highway_props()
		
	# 2. Regional Biome Foliage & Rock MultiMeshes
	_populate_alpine_pines(550)
	_populate_festival_trees(300)
	_populate_desert_rocks_and_cacti(450)
	_populate_volcanic_spires(450)
	_populate_shipping_containers(250)
	_populate_festival_staging()

func _get_glb_mesh(path: String) -> Mesh:
	var scene := load(path) as PackedScene
	if scene:
		var root := scene.instantiate()
		for child in root.get_children():
			if child is MeshInstance3D and child.mesh:
				var m: Mesh = child.mesh
				root.queue_free()
				return m
		root.queue_free()
	return null

func _create_conifer_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var segs := 8
	
	# Sturdy tree trunk extending down to anchor deeply in mountain slopes
	var trunk_col := Color(0.22, 0.14, 0.08)
	var trunk_bot_r := 0.45
	var trunk_top_r := 0.35
	var trunk_bot_y := -2.0
	var trunk_top_y := 3.2
	for i in range(segs):
		var a0 := (float(i) / float(segs)) * TAU
		var a1 := (float(i + 1) / float(segs)) * TAU
		var p_b0 := Vector3(cos(a0) * trunk_bot_r, trunk_bot_y, sin(a0) * trunk_bot_r)
		var p_b1 := Vector3(cos(a1) * trunk_bot_r, trunk_bot_y, sin(a1) * trunk_bot_r)
		var p_t0 := Vector3(cos(a0) * trunk_top_r, trunk_top_y, sin(a0) * trunk_top_r)
		var p_t1 := Vector3(cos(a1) * trunk_top_r, trunk_top_y, sin(a1) * trunk_top_r)
		st.set_color(trunk_col); st.add_vertex(p_b0)
		st.set_color(trunk_col); st.add_vertex(p_t0)
		st.set_color(trunk_col); st.add_vertex(p_b1)
		st.set_color(trunk_col); st.add_vertex(p_t0)
		st.set_color(trunk_col); st.add_vertex(p_t1)
		st.set_color(trunk_col); st.add_vertex(p_b1)
	
	# Tiered bough skirts (4 stacked cone frustums sweeping close to ground)
	var tiers := [
		{"bot_r": 3.2, "top_r": 0.6, "h": 2.6, "y": 0.4, "col": Color(0.04, 0.16, 0.08)},
		{"bot_r": 2.5, "top_r": 0.5, "h": 2.4, "y": 2.4, "col": Color(0.06, 0.20, 0.10)},
		{"bot_r": 1.8, "top_r": 0.35, "h": 2.2, "y": 4.4, "col": Color(0.08, 0.24, 0.12)},
		{"bot_r": 1.0, "top_r": 0.05, "h": 2.0, "y": 6.2, "col": Color(0.12, 0.28, 0.15)}
	]
	
	for tier in tiers:
		var bot_r: float = tier.bot_r
		var top_r: float = tier.top_r
		var h: float = tier.h
		var base_y: float = tier.y
		var col: Color = tier.col
		
		for i in range(segs):
			var a0 := (float(i) / float(segs)) * TAU
			var a1 := (float(i + 1) / float(segs)) * TAU
			
			var p_b0 := Vector3(cos(a0) * bot_r, base_y, sin(a0) * bot_r)
			var p_b1 := Vector3(cos(a1) * bot_r, base_y, sin(a1) * bot_r)
			var p_t0 := Vector3(cos(a0) * top_r, base_y + h, sin(a0) * top_r)
			var p_t1 := Vector3(cos(a1) * top_r, base_y + h, sin(a1) * top_r)
			
			st.set_color(col); st.add_vertex(p_b0)
			st.set_color(col); st.add_vertex(p_t0)
			st.set_color(col); st.add_vertex(p_b1)
			
			st.set_color(col); st.add_vertex(p_t0)
			st.set_color(col); st.add_vertex(p_t1)
			st.set_color(col); st.add_vertex(p_b1)
			
	st.generate_normals()
	return st.commit()

func _create_saguaro_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var col := Color(0.18, 0.38, 0.16)
	var segs := 8
	
	# Helper lambda to add cylinder tube
	var add_cylinder = func(bot_r: float, top_r: float, base_y: float, h: float, offset_x: float, offset_z: float):
		for i in range(segs):
			var a0 := (float(i) / float(segs)) * TAU
			var a1 := (float(i + 1) / float(segs)) * TAU
			var p_b0 := Vector3(offset_x + cos(a0) * bot_r, base_y, offset_z + sin(a0) * bot_r)
			var p_b1 := Vector3(offset_x + cos(a1) * bot_r, base_y, offset_z + sin(a1) * bot_r)
			var p_t0 := Vector3(offset_x + cos(a0) * top_r, base_y + h, offset_z + sin(a0) * top_r)
			var p_t1 := Vector3(offset_x + cos(a1) * top_r, base_y + h, offset_z + sin(a1) * top_r)
			
			st.set_color(col); st.add_vertex(p_b0)
			st.set_color(col); st.add_vertex(p_t0)
			st.set_color(col); st.add_vertex(p_b1)
			
			st.set_color(col); st.add_vertex(p_t0)
			st.set_color(col); st.add_vertex(p_t1)
			st.set_color(col); st.add_vertex(p_b1)
			
	# Main central trunk (6m tall, starts at -1.0m to bury securely in dunes)
	add_cylinder.call(0.32, 0.28, -1.0, 7.0, 0.0, 0.0)
	# Left arm: branch horizontal + vertical
	add_cylinder.call(0.18, 0.18, 2.4, 0.4, -0.4, 0.0)
	add_cylinder.call(0.18, 0.16, 2.6, 2.2, -0.65, 0.0)
	# Right arm: branch horizontal + vertical
	add_cylinder.call(0.18, 0.18, 3.4, 0.4, 0.4, 0.0)
	add_cylinder.call(0.18, 0.16, 3.6, 2.0, 0.65, 0.0)
	
	st.generate_normals()
	return st.commit()

func _populate_highway_props() -> void:
	var wps := road_network.highway_waypoints
	var count := wps.size()
	
	# Light Poles MultiMesh (use 3D Kenney lightpost model if available)
	var pole_mesh: Mesh = _get_glb_mesh("res://assets/models/props/highway_lightpost.glb")
	if not pole_mesh:
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.12
		cyl.bottom_radius = 0.18
		cyl.height = 7.5
		pole_mesh = cyl
	
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
		left_pos.y = terrain_gen.get_height(left_pos.x, left_pos.z)
		right_pos.y = terrain_gen.get_height(right_pos.x, right_pos.z)
		
		var rot_y := atan2(fwd.x, fwd.z)
		var basis := Basis(Vector3.UP, rot_y)
		mm_poles.set_instance_transform(i * 2, Transform3D(basis, left_pos))
		mm_poles.set_instance_transform(i * 2 + 1, Transform3D(basis, right_pos))
		
	var inst_poles := MultiMeshInstance3D.new()
	inst_poles.multimesh = mm_poles
	inst_poles.material_override = _get_palette_mat()
	inst_poles.visibility_range_end = 650.0
	inst_poles.visibility_range_end_margin = 50.0
	inst_poles.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	inst_poles.name = "MultiMesh_HighwayPoles"
	add_child(inst_poles)

func _populate_alpine_pines(count: int) -> void:
	# Layered Conifer Pine Foliage (Multi-tiered evergreen trees for Frozen Pass)
	var pine_mesh := _get_glb_mesh("res://assets/models/foliage/pine_cluster.glb")
	if not pine_mesh:
		pine_mesh = _create_conifer_mesh()
	
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = pine_mesh
	mm.instance_count = count
	
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	
	for i in range(count):
		# Frozen Pass quadrant (North-West: x in -3200 to -400, z in -3200 to -400)
		var x := rng.randf_range(-3200.0, -400.0)
		var z := rng.randf_range(-3200.0, -400.0)
		var s := rng.randf_range(1.4, 3.2)
		var y := terrain_gen.get_height(x, z) - 0.2
		var rot_y := rng.randf_range(0, TAU)
		var basis := Basis(Vector3.UP, rot_y).scaled(Vector3(s, s, s))
		mm.set_instance_transform(i, Transform3D(basis, Vector3(x, y, z)))
		
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	inst.material_override = _get_palette_mat()
	inst.visibility_range_end = 850.0
	inst.visibility_range_end_margin = 50.0
	inst.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	inst.name = "MultiMesh_AlpinePines"
	add_child(inst)

func _populate_festival_trees(count: int) -> void:
	var tree_mesh := _get_glb_mesh("res://assets/models/foliage/trees_tall.glb")
	if not tree_mesh:
		return
		
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = tree_mesh
	mm.instance_count = count
	
	var rng := RandomNumberGenerator.new()
	rng.seed = 1010
	
	for i in range(count):
		# Central Hub meadow (radius 80m to 500m)
		var angle := rng.randf_range(0, TAU)
		var r := rng.randf_range(80.0, 480.0)
		var x := cos(angle) * r
		var z := sin(angle) * r
		var s := rng.randf_range(1.5, 3.2)
		var y := terrain_gen.get_height(x, z) - 0.2
		var rot_y := rng.randf_range(0, TAU)
		var basis := Basis(Vector3.UP, rot_y).scaled(Vector3(s, s, s))
		mm.set_instance_transform(i, Transform3D(basis, Vector3(x, y, z)))
		
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	inst.material_override = _get_palette_mat()
	inst.visibility_range_end = 750.0
	inst.visibility_range_end_margin = 50.0
	inst.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	inst.name = "MultiMesh_FestivalTrees"
	add_child(inst)

func _populate_desert_rocks_and_cacti(count: int) -> void:
	# 1. Weathered Desert Sandstone Boulders (Organic low-poly faceted boulders sunk into dunes)
	var boulder_mesh := SphereMesh.new()
	boulder_mesh.radial_segments = 7
	boulder_mesh.rings = 4
	boulder_mesh.radius = 2.4
	boulder_mesh.height = 3.2
	
	var boulder_mat := StandardMaterial3D.new()
	boulder_mat.albedo_color = Color(0.56, 0.36, 0.22) # Desert Sandstone Red/Tan
	boulder_mat.roughness = 0.95
	
	var mm_boulders := MultiMesh.new()
	mm_boulders.transform_format = MultiMesh.TRANSFORM_3D
	mm_boulders.mesh = boulder_mesh
	mm_boulders.instance_count = count
	
	var rng := RandomNumberGenerator.new()
	rng.seed = 3030
	
	for i in range(count):
		# Dust Bowl quadrant (South-West: x in -1800 to -250, z in 250 to 1800)
		var x := rng.randf_range(-1800.0, -250.0)
		var z := rng.randf_range(250.0, 1800.0)
		var rot_y := rng.randf_range(0, TAU)
		var rot_x := rng.randf_range(-0.25, 0.25)
		var rot_z := rng.randf_range(-0.25, 0.25)
		var s := rng.randf_range(0.8, 2.8)
		# Boulders are partially sunk into the sand for a natural embedded look
		var y := terrain_gen.get_height(x, z) - (s * 0.45)
		var basis := Basis.from_euler(Vector3(rot_x, rot_y, rot_z)).scaled(Vector3(s * 1.5, s * 0.75, s * 1.25))
		mm_boulders.set_instance_transform(i, Transform3D(basis, Vector3(x, y, z)))
		
	var inst_boulders := MultiMeshInstance3D.new()
	inst_boulders.multimesh = mm_boulders
	inst_boulders.material_override = boulder_mat
	inst_boulders.name = "MultiMesh_DesertRocks"
	add_child(inst_boulders)
	
	# 2. Multi-Branched Saguaro Cacti (Iconic Sonora / Baja desert landscape feature)
	var cactus_mesh := _create_saguaro_mesh()
	
	var cactus_mat := StandardMaterial3D.new()
	cactus_mat.vertex_color_use_as_albedo = true
	cactus_mat.roughness = 0.82
	cactus_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	
	var mm_cacti := MultiMesh.new()
	mm_cacti.transform_format = MultiMesh.TRANSFORM_3D
	mm_cacti.mesh = cactus_mesh
	mm_cacti.instance_count = int(count * 0.75)
	
	for i in range(mm_cacti.instance_count):
		var x := rng.randf_range(-1750.0, -280.0)
		var z := rng.randf_range(280.0, 1750.0)
		var s := rng.randf_range(0.7, 1.4)
		var y := terrain_gen.get_height(x, z) - 0.25
		var rot_y := rng.randf_range(0, TAU)
		var basis := Basis(Vector3.UP, rot_y).scaled(Vector3(s, s, s))
		mm_cacti.set_instance_transform(i, Transform3D(basis, Vector3(x, y, z)))
		
	var inst_cacti := MultiMeshInstance3D.new()
	inst_cacti.multimesh = mm_cacti
	inst_cacti.material_override = cactus_mat
	inst_cacti.name = "MultiMesh_SaguaroCacti"
	add_child(inst_cacti)

func _populate_volcanic_spires(count: int) -> void:
	# Jagged Volcanic Obsidian Crags & Basalt Outcrops (Natural low-profile jagged rock clusters)
	var crag_mesh := SphereMesh.new()
	crag_mesh.radial_segments = 6
	crag_mesh.rings = 3
	crag_mesh.radius = 2.2
	crag_mesh.height = 3.6
	
	var crag_mat := StandardMaterial3D.new()
	crag_mat.albedo_color = Color(0.12, 0.10, 0.11) # Charred Volcanic Basalt
	crag_mat.roughness = 0.88
	crag_mat.metallic = 0.25
	
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = crag_mesh
	mm.instance_count = count
	
	var rng := RandomNumberGenerator.new()
	rng.seed = 4040
	
	for i in range(count):
		# Volcano Ridge quadrant (North-East: x in 250 to 1800, z in -1800 to -250)
		var x := rng.randf_range(280.0, 1750.0)
		var z := rng.randf_range(-1750.0, -280.0)
		var rot_y := rng.randf_range(0, TAU)
		var rot_x := rng.randf_range(-0.4, 0.4)
		var rot_z := rng.randf_range(-0.4, 0.4)
		var s := rng.randf_range(0.8, 3.2)
		# Embed rocks naturally into volcanic slopes
		var y := terrain_gen.get_height(x, z) - (s * 0.3)
		var basis := Basis.from_euler(Vector3(rot_x, rot_y, rot_z)).scaled(Vector3(s * 1.4, s * 0.9, s * 1.2))
		mm.set_instance_transform(i, Transform3D(basis, Vector3(x, y, z)))
		
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	inst.material_override = crag_mat
	inst.name = "MultiMesh_VolcanicSpires"
	add_child(inst)

func _populate_shipping_containers(count: int) -> void:
	# Standard 40ft ISO Shipping Containers in organized harbor stacks
	var cont_mesh := BoxMesh.new()
	cont_mesh.size = Vector3(2.44, 2.59, 12.19)
	
	var cont_mat := StandardMaterial3D.new()
	cont_mat.vertex_color_use_as_albedo = true
	cont_mat.roughness = 0.45
	cont_mat.metallic = 0.65
	
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = cont_mesh
	mm.instance_count = count
	
	var rng := RandomNumberGenerator.new()
	rng.seed = 5050
	
	var colors := [
		Color(0.20, 0.45, 0.75), # Marine Blue
		Color(0.12, 0.48, 0.25), # Evergreen Green
		Color(0.92, 0.45, 0.08), # Freight Orange
		Color(0.72, 0.16, 0.14), # Cargo Red
		Color(0.88, 0.72, 0.15)  # Industrial Yellow
	]
	
	# Organized harbor container terminal layout in Neon Coast (SE)
	for i in range(count):
		# Grid-aligned stacks in harbor depot
		var row := (i / 5) % 10
		var col := i % 5
		var tier := (i / 50) % 2 # 2-high stacks
		
		var base_x := 650.0 + (col * 3.6)
		var base_z := 650.0 + (row * 14.5)
		var y := terrain_gen.get_height(base_x, base_z) + 1.3 + (tier * 2.6)
		
		var basis := Basis(Vector3.UP, 0.0)
		mm.set_instance_transform(i, Transform3D(basis, Vector3(base_x, y, base_z)))
		mm.set_instance_color(i, colors[(row + col + tier) % colors.size()])
		
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	inst.material_override = cont_mat
	inst.name = "MultiMesh_ShippingContainers"
	add_child(inst)

func _populate_festival_staging() -> void:
	var staging := Node3D.new()
	staging.name = "FestivalStagingComplex"
	add_child(staging)
	
	# 1. Authentic 3D Finish / Gantry Arch
	var arch_scene := load("res://assets/models/props/track_finish_arch.glb") as PackedScene
	if arch_scene:
		var arch := arch_scene.instantiate()
		var y := terrain_gen.get_height(0, -20.0)
		arch.position = Vector3(0, y, -20.0)
		arch.scale = Vector3(1.5, 1.5, 1.5)
		_assign_palette_recursive(arch, _get_palette_mat())
		staging.add_child(arch)
		
	# 2. Paddock Event Tents (Left of track)
	var tent_scene := load("res://assets/models/props/festival_tents.glb") as PackedScene
	if tent_scene:
		var tent := tent_scene.instantiate()
		var y := terrain_gen.get_height(-18.0, 0.0)
		tent.position = Vector3(-18.0, y, 0.0)
		tent.scale = Vector3(1.6, 1.6, 1.6)
		_assign_palette_recursive(tent, _get_palette_mat())
		staging.add_child(tent)
		
	# 3. Pit Garages Workshop (Right of track)
	var garage_scene := load("res://assets/models/props/pit_garage.glb") as PackedScene
	if garage_scene:
		var garage := garage_scene.instantiate()
		var y := terrain_gen.get_height(20.0, 0.0)
		garage.position = Vector3(20.0, y, 0.0)
		garage.rotation.y = PI
		garage.scale = Vector3(1.8, 1.8, 1.8)
		_assign_palette_recursive(garage, _get_palette_mat())
		staging.add_child(garage)
		
	# 4. Track Edge Safety Tire Barriers
	var tire_mat_w := StandardMaterial3D.new()
	tire_mat_w.albedo_color = Color(0.92, 0.92, 0.92)
	tire_mat_w.roughness = 0.75
	
	var tire_mat_r := StandardMaterial3D.new()
	tire_mat_r.albedo_color = Color(0.85, 0.08, 0.06)
	tire_mat_r.roughness = 0.75
	
	var tire_box := BoxMesh.new()
	tire_box.size = Vector3(1.2, 1.1, 2.0)
	
	for i in range(16):
		var z_pos := -25.0 + (i * 3.2)
		var is_white := (i % 2 == 0)
		var mat := tire_mat_w if is_white else tire_mat_r
		
		# Left barrier wall
		var b_left := MeshInstance3D.new()
		b_left.mesh = tire_box
		var y_l := terrain_gen.get_height(-8.5, z_pos) + 0.55
		b_left.position = Vector3(-8.5, y_l, z_pos)
		b_left.material_override = mat
		staging.add_child(b_left)
		
		# Right barrier wall
		var b_right := MeshInstance3D.new()
		b_right.mesh = tire_box
		var y_r := terrain_gen.get_height(8.5, z_pos) + 0.55
		b_right.position = Vector3(8.5, y_r, z_pos)
		b_right.material_override = mat
		staging.add_child(b_right)
