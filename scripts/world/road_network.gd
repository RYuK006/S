# scripts/world/road_network.gd
class_name RoadNetwork
extends Node3D

const TerrainGenerator = preload("res://scripts/world/terrain_generator.gd")

var terrain_gen: TerrainGenerator
var road_nodes: Array[Node3D] = []
var highway_waypoints: Array[Vector3] = []

func _init(tg: TerrainGenerator = null) -> void:
	if tg:
		terrain_gen = tg
	else:
		terrain_gen = TerrainGenerator.new()

func build_open_world_roads() -> void:
	# 1. Build Grand Perimeter Highway (Sweeping 4-lane loop around the 50 km² map)
	_build_perimeter_highway()
	
	# 2. Build Trans-Continental Cross Expressway (Connecting West to East through Central Festival Hub)
	_build_trans_expressway()
	
	# 3. Build Mountain Pass Hillclimb (Winding switchbacks to Frozen Pass peaks)
	_build_mountain_hillclimb()
	
	# 4. Build Festival Starting Grid Runway (Straight staging road through arch)
	_build_festival_starting_grid()
	
	# 5. Build Armco Steel Guardrails along Outer Highway Cliffs
	_build_highway_guardrails()

func _build_festival_starting_grid() -> void:
	var pts: Array[Vector3] = []
	for i in range(25):
		var z_val := -80.0 + (i * 6.5) # from -80m to +76m across starting hub
		var y_val := terrain_gen.get_height(0.0, z_val) + 0.38
		pts.append(Vector3(0.0, y_val, z_val))
	var road_mesh := _generate_ribbon_mesh(pts, 14.0, false, "Festival Starting Grid")
	add_child(road_mesh)
	road_nodes.append(road_mesh)

func _build_highway_guardrails() -> void:
	if highway_waypoints.size() == 0:
		return
		
	var wps := highway_waypoints
	var count := wps.size()
	
	# Galvanized Corrugated Steel W-Beam Material
	var steel_mat := StandardMaterial3D.new()
	steel_mat.albedo_color = Color(0.72, 0.74, 0.78)
	steel_mat.metallic = 0.92
	steel_mat.roughness = 0.28
	
	# Guardrail W-Beam Box
	var rail_mesh := BoxMesh.new()
	rail_mesh.size = Vector3(0.14, 0.45, 14.0)
	
	var mm_rails := MultiMesh.new()
	mm_rails.transform_format = MultiMesh.TRANSFORM_3D
	mm_rails.mesh = rail_mesh
	mm_rails.instance_count = count
	
	for i in range(count):
		var p := wps[i]
		var next_p := wps[(i + 1) % count]
		var fwd := (next_p - p).normalized()
		var right := fwd.cross(Vector3.UP).normalized()
		
		# Outer guardrail positioned 7.8m to the right of highway center
		var rail_pos := ((p + next_p) * 0.5) + (right * 7.8)
		rail_pos.y = terrain_gen.get_height(rail_pos.x, rail_pos.z) + 0.75
		
		var rot_y := atan2(fwd.x, fwd.z)
		var basis := Basis(Vector3.UP, rot_y)
		mm_rails.set_instance_transform(i, Transform3D(basis, rail_pos))
		
	var inst_rails := MultiMeshInstance3D.new()
	inst_rails.multimesh = mm_rails
	inst_rails.material_override = steel_mat
	inst_rails.name = "MultiMesh_HighwayGuardrails"
	add_child(inst_rails)

func _build_perimeter_highway() -> void:
	var R: float = 2800.0 # 5.6km loop diameter across 50 km² map
	var num_pts := 96
	var raw_points: Array[Vector3] = []
	
	for i in range(num_pts):
		var angle := (float(i) / float(num_pts)) * TAU
		var x := cos(angle) * R
		var z := sin(angle) * R
		# Add organic undulation so highway isn't a sterile circle
		var r_mod := 1.0 + (sin(angle * 3.0) * 0.12) + (cos(angle * 5.0) * 0.06)
		x *= r_mod
		z *= r_mod
		var y := terrain_gen.get_height(x, z) + 0.18
		raw_points.append(Vector3(x, y, z))
		
	# Store waypoints for AI & GPS
	highway_waypoints = raw_points.duplicate()
	
	var road_mesh := _generate_ribbon_mesh(raw_points, 14.0, true, "Grand Perimeter Highway")
	add_child(road_mesh)
	road_nodes.append(road_mesh)

func _build_trans_expressway() -> void:
	var raw_points: Array[Vector3] = []
	var start_x := -3200.0
	var end_x := 3200.0
	var num_pts := 48
	
	for i in range(num_pts):
		var t := float(i) / float(num_pts - 1)
		var x: float = lerp(start_x, end_x, t)
		var z: float = sin(t * PI * 2.0) * 350.0 # Gentle S-curve through festival center
		var y := terrain_gen.get_height(x, z) + 0.18
		raw_points.append(Vector3(x, y, z))
		
	var road_mesh := _generate_ribbon_mesh(raw_points, 12.0, false, "Trans-Continental Expressway")
	add_child(road_mesh)
	road_nodes.append(road_mesh)

func _build_mountain_hillclimb() -> void:
	var raw_points: Array[Vector3] = []
	# Starts near festival center and climbs north-west into Frozen Pass
	var base_pts: Array[Vector2] = [
		Vector2(0, 0),
		Vector2(-350, -300),
		Vector2(-700, -550),
		Vector2(-600, -900),
		Vector2(-1100, -1200),
		Vector2(-1000, -1600),
		Vector2(-1500, -1900),
		Vector2(-1400, -2300),
		Vector2(-2000, -2600)
	]
	
	for pt: Vector2 in base_pts:
		var x: float = pt.x
		var z: float = pt.y
		var y := terrain_gen.get_height(x, z) + 0.22
		raw_points.append(Vector3(x, y, z))
		
	# Subdivide with Catmull-Rom interpolation for smooth hairpins
	var smooth_points := _subdivide_spline(raw_points, 4)
	var road_mesh := _generate_ribbon_mesh(smooth_points, 9.5, false, "Frozen Pass Hillclimb")
	add_child(road_mesh)
	road_nodes.append(road_mesh)

func _generate_ribbon_mesh(points: Array[Vector3], road_width: float, is_closed: bool, road_name: String) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n_pts := points.size()
	var half_w := road_width * 0.5
	var u_distance: float = 0.0
	
	# Authentic Highway Color Palette
	var col_shoulder := Color(0.92, 0.92, 0.95)   # Crisp white highway shoulder stripe
	var col_asphalt := Color(0.16, 0.16, 0.18)    # Deep cured asphalt with aggregate
	var col_centerline := Color(1.0, 0.82, 0.10)  # Highway yellow double centerline
	
	var max_idx := n_pts if is_closed else (n_pts - 1)
	for i in range(max_idx):
		var curr_p := points[i % n_pts]
		var next_p := points[(i + 1) % n_pts]
		var seg_len: float = curr_p.distance_to(next_p)
		var fwd := (next_p - curr_p).normalized()
		var right := fwd.cross(Vector3.UP).normalized()
		
		var next_next_p: Vector3
		if is_closed:
			next_next_p = points[(i + 2) % n_pts]
		else:
			if i + 2 < n_pts:
				next_next_p = points[i + 2]
			else:
				next_next_p = next_p + fwd * seg_len
		var next_fwd := (next_next_p - next_p).normalized()
		var next_right := next_fwd.cross(Vector3.UP).normalized()
		
		# Current cross-section vertices (5 points across road width)
		var p_L0 := curr_p - (right * half_w)
		var p_L1 := curr_p - (right * (half_w * 0.88))
		var p_C0 := curr_p
		var p_R1 := curr_p + (right * (half_w * 0.88))
		var p_R0 := curr_p + (right * half_w)
		
		# Next cross-section vertices
		var np_L0 := next_p - (next_right * half_w)
		var np_L1 := next_p - (next_right * (half_w * 0.88))
		var np_C0 := next_p
		var np_R1 := next_p + (next_right * (half_w * 0.88))
		var np_R0 := next_p + (next_right * half_w)
		
		var u0 := u_distance * 0.1
		var u1 := (u_distance + seg_len) * 0.1
		u_distance += seg_len
		
		# Quad 1: Left shoulder stripe (Counter-Clockwise winding upward)
		st.set_color(col_shoulder); st.set_normal(Vector3.UP); st.set_uv(Vector2(0.0, u0)); st.add_vertex(p_L0)
		st.set_color(col_shoulder); st.set_normal(Vector3.UP); st.set_uv(Vector2(0.0, u1)); st.add_vertex(np_L0)
		st.set_color(col_asphalt);  st.set_normal(Vector3.UP); st.set_uv(Vector2(0.1, u0)); st.add_vertex(p_L1)
		
		st.set_color(col_asphalt);  st.set_normal(Vector3.UP); st.set_uv(Vector2(0.1, u0)); st.add_vertex(p_L1)
		st.set_color(col_shoulder); st.set_normal(Vector3.UP); st.set_uv(Vector2(0.0, u1)); st.add_vertex(np_L0)
		st.set_color(col_asphalt);  st.set_normal(Vector3.UP); st.set_uv(Vector2(0.1, u1)); st.add_vertex(np_L1)
		
		# Quad 2: Left travel lane to centerline
		st.set_color(col_asphalt);    st.set_normal(Vector3.UP); st.set_uv(Vector2(0.1, u0)); st.add_vertex(p_L1)
		st.set_color(col_asphalt);    st.set_normal(Vector3.UP); st.set_uv(Vector2(0.1, u1)); st.add_vertex(np_L1)
		st.set_color(col_centerline); st.set_normal(Vector3.UP); st.set_uv(Vector2(0.5, u0)); st.add_vertex(p_C0)
		
		st.set_color(col_centerline); st.set_normal(Vector3.UP); st.set_uv(Vector2(0.5, u0)); st.add_vertex(p_C0)
		st.set_color(col_asphalt);    st.set_normal(Vector3.UP); st.set_uv(Vector2(0.1, u1)); st.add_vertex(np_L1)
		st.set_color(col_centerline); st.set_normal(Vector3.UP); st.set_uv(Vector2(0.5, u1)); st.add_vertex(np_C0)
		
		# Quad 3: Centerline to Right travel lane
		st.set_color(col_centerline); st.set_normal(Vector3.UP); st.set_uv(Vector2(0.5, u0)); st.add_vertex(p_C0)
		st.set_color(col_centerline); st.set_normal(Vector3.UP); st.set_uv(Vector2(0.5, u1)); st.add_vertex(np_C0)
		st.set_color(col_asphalt);    st.set_normal(Vector3.UP); st.set_uv(Vector2(0.9, u0)); st.add_vertex(p_R1)
		
		st.set_color(col_asphalt);    st.set_normal(Vector3.UP); st.set_uv(Vector2(0.9, u0)); st.add_vertex(p_R1)
		st.set_color(col_centerline); st.set_normal(Vector3.UP); st.set_uv(Vector2(0.5, u1)); st.add_vertex(np_C0)
		st.set_color(col_asphalt);    st.set_normal(Vector3.UP); st.set_uv(Vector2(0.9, u1)); st.add_vertex(np_R1)
		
		# Quad 4: Right travel lane to right shoulder stripe
		st.set_color(col_asphalt);  st.set_normal(Vector3.UP); st.set_uv(Vector2(0.9, u0)); st.add_vertex(p_R1)
		st.set_color(col_asphalt);  st.set_normal(Vector3.UP); st.set_uv(Vector2(0.9, u1)); st.add_vertex(np_R1)
		st.set_color(col_shoulder); st.set_normal(Vector3.UP); st.set_uv(Vector2(1.0, u0)); st.add_vertex(p_R0)
		
		st.set_color(col_shoulder); st.set_normal(Vector3.UP); st.set_uv(Vector2(1.0, u0)); st.add_vertex(p_R0)
		st.set_color(col_asphalt);  st.set_normal(Vector3.UP); st.set_uv(Vector2(0.9, u1)); st.add_vertex(np_R1)
		st.set_color(col_shoulder); st.set_normal(Vector3.UP); st.set_uv(Vector2(1.0, u1)); st.add_vertex(np_R0)
		
	st.generate_normals()
	st.generate_tangents()
	
	var mesh := st.commit()
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.name = road_name
	
	# PBR Road Material with Authentic 1K Asphalt Textures & Painted Markings
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.55
	mat.metallic = 0.05
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	
	var tex_asphalt_d := load("res://assets/textures/asphalt_diff.jpg") as Texture2D
	var tex_asphalt_n := load("res://assets/textures/asphalt_nor.jpg") as Texture2D
	var tex_asphalt_r := load("res://assets/textures/asphalt_rough.jpg") as Texture2D
	
	if tex_asphalt_d:
		mat.albedo_texture = tex_asphalt_d
	if tex_asphalt_n:
		mat.normal_enabled = true
		mat.normal_texture = tex_asphalt_n
	if tex_asphalt_r:
		mat.roughness_texture = tex_asphalt_r
		
	mat.uv1_scale = Vector3(1.0, 8.0, 1.0)
	inst.material_override = mat
	
	# StaticBody3D collision with Asphalt Surface Metadata
	var body := StaticBody3D.new()
	body.set_meta("surface", "asphalt_dry")
	var col := CollisionShape3D.new()
	col.shape = mesh.create_trimesh_shape()
	body.add_child(col)
	inst.add_child(body)
	
	return inst

func _subdivide_spline(pts: Array[Vector3], subdivisions: int) -> Array[Vector3]:
	var result: Array[Vector3] = []
	for i in range(pts.size() - 1):
		var p0 := pts[max(0, i - 1)]
		var p1 := pts[i]
		var p2 := pts[i + 1]
		var p3 := pts[min(pts.size() - 1, i + 2)]
		
		for s in range(subdivisions):
			var t := float(s) / float(subdivisions)
			var interp := _catmull_rom(p0, p1, p2, p3, t)
			interp.y = terrain_gen.get_height(interp.x, interp.z) + 0.2
			result.append(interp)
	result.append(pts[-1])
	return result

func _catmull_rom(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * (
		(2.0 * p1) +
		(-p0 + p2) * t +
		(2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 +
		(-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3
	)
