# scripts/world/road_network.gd
class_name RoadNetwork
extends Node3D

const TerrainGenerator = preload("res://scripts/world/terrain_generator.gd")

var terrain_gen: TerrainGenerator
var road_nodes: Array[Node3D] = []
var highway_waypoints: Array[Vector3] = []
var all_road_segments: Array[Dictionary] = []
var scenic_rail_paths: Array[Array] = []
var road_centerlines: Dictionary = {}

func get_road_pose(road_name_substr: String, t_norm: float) -> Dictionary:
	for k: String in road_centerlines.keys():
		if road_name_substr.to_lower() in k.to_lower():
			var pts: Array[Vector3] = road_centerlines[k]
			if pts.size() >= 2:
				var idx: int = clampi(int(roundf(clampf(t_norm, 0.02, 0.96) * float(pts.size() - 2))), 0, pts.size() - 2)
				var p0: Vector3 = pts[idx]
				var p1: Vector3 = pts[idx + 1]
				var fwd: Vector3 = (p1 - p0).normalized()
				var yaw: float = atan2(-fwd.x, -fwd.z)
				return {"pos": p0, "yaw": yaw}
	return {"pos": Vector3(0.0, terrain_gen.get_height(0.0, 15.0), 15.0), "yaw": 0.0}

func _init(tg: TerrainGenerator = null) -> void:
	if tg:
		terrain_gen = tg
	else:
		terrain_gen = TerrainGenerator.new()

func build_open_world_roads() -> void:
	# 1. Grand Perimeter Highway (Outer 5.6km 4-lane loop around the 50 km² map)
	_build_perimeter_highway()
	
	# 2. Trans-Continental Expressway (East-West corridor through Central Hub)
	_build_trans_expressway()
	
	# 3. Meridian Central Boulevard (North-South corridor through Central Hub)
	_build_meridian_boulevard()
	
	# 4. Volcano Ridge Scenic Highway (Diagonal arterial from Hub to Caldera Rim)
	_build_volcano_highway()
	
	# 5. Dust Bowl Canyon Highway (Diagonal arterial from Hub to Desert Badlands)
	_build_desert_canyon_highway()
	
	# 6. Coastal Shoreline Boulevard (Connecting Harbor to Eastern Volcano cliffs)
	_build_coastal_promenade()
	
	# 7. Desert-Alpine Ridge Connector (Western trail connecting Desert to Alpine Pass)
	_build_desert_alpine_pass()
	
	# 8. Mountain Pass Hillclimb (Winding switchbacks to Frozen Pass peaks)
	_build_mountain_hillclimb()
	
	# 9. Festival Starting Grid Runway (Straight staging road through arch)
	_build_festival_starting_grid()

	# Register carved road corridors directly with TerrainGenerator so terrain & shoulders weld cleanly
	if terrain_gen:
		terrain_gen.set_road_segments(all_road_segments)

	# 10. Continuous Galvanized Armco Steel Guardrails along scenic highways & hillclimbs
	_build_highway_guardrails()

func _build_festival_starting_grid() -> void:
	var pts: Array[Vector3] = []
	for i in range(25):
		var z_val := -80.0 + (i * 6.5) # from -80m to +76m across starting hub
		var y_val := terrain_gen.get_height(0.0, z_val) + 0.34
		pts.append(Vector3(0.0, y_val, z_val))
	var road_mesh := _generate_ribbon_mesh(pts, 14.0, false, "Festival Starting Grid", 0.34)
	add_child(road_mesh)
	road_nodes.append(road_mesh)

func _build_highway_guardrails() -> void:
	if highway_waypoints.size() == 0:
		return

	# Continuous extruded metallic Armco W-Beam steel rail along scenic mountain/coast highways
	var steel_mat := StandardMaterial3D.new()
	steel_mat.albedo_color = Color(0.62, 0.65, 0.70)
	steel_mat.metallic = 0.85
	steel_mat.roughness = 0.32
	steel_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	var post_mat := StandardMaterial3D.new()
	post_mat.albedo_color = Color(0.32, 0.34, 0.38)
	post_mat.metallic = 0.75
	post_mat.roughness = 0.45

	var rail_st := SurfaceTool.new()
	rail_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var post_transforms: Array[Transform3D] = []

	for path_arr: Array in scenic_rail_paths:
		var pts: Array[Vector3] = path_arr[0]
		var half_w: float = float(path_arr[1])
		if pts.size() < 2:
			continue
		for side: float in [-1.0, 1.0]:
			var rail_offset: float = (half_w + 0.65) * side
			var post_accum: float = 0.0
			for i: int in range(pts.size() - 1):
				var p0: Vector3 = pts[i]
				var p1: Vector3 = pts[i + 1]
				var seg_len: float = Vector2(p1.x - p0.x, p1.z - p0.z).length()
				if seg_len < 0.2:
					continue
				var fwd0: Vector3 = (p1 - p0).normalized()
				var right0: Vector3 = fwd0.cross(Vector3.UP).normalized()
				var fwd1: Vector3 = fwd0
				if i + 2 < pts.size():
					fwd1 = (pts[i + 2] - p1).normalized()
				var right1: Vector3 = fwd1.cross(Vector3.UP).normalized()

				var r0: Vector3 = p0 + right0 * rail_offset
				var r1: Vector3 = p1 + right1 * rail_offset
				var b0: Vector3 = r0 + Vector3(0.0, 0.44, 0.0)
				var t0: Vector3 = r0 + Vector3(0.0, 0.78, 0.0)
				var b1: Vector3 = r1 + Vector3(0.0, 0.44, 0.0)
				var t1: Vector3 = r1 + Vector3(0.0, 0.78, 0.0)

				rail_st.add_vertex(b0); rail_st.add_vertex(b1); rail_st.add_vertex(t0)
				rail_st.add_vertex(t0); rail_st.add_vertex(b1); rail_st.add_vertex(t1)

				# Add galvanized H-post every ~10m along the guardrail
				post_accum += seg_len
				var num_posts: int = int(floorf(post_accum / 10.0))
				for k: int in range(num_posts):
					var f: float = float(k + 1) / float(num_posts + 1)
					var pp: Vector3 = r0.lerp(r1, f) + Vector3(0.0, 0.38, 0.0)
					var yaw: float = atan2(fwd0.x, fwd0.z)
					post_transforms.append(Transform3D(Basis(Vector3.UP, yaw), pp))
				post_accum = fmod(post_accum, 10.0)

	rail_st.generate_normals()
	var rail_inst := MeshInstance3D.new()
	rail_inst.mesh = rail_st.commit()
	rail_inst.material_override = steel_mat
	rail_inst.name = "Mesh_ScenicGuardrails"
	add_child(rail_inst)

	if not post_transforms.is_empty():
		var post_box := BoxMesh.new()
		post_box.size = Vector3(0.14, 0.86, 0.14)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = post_box
		mm.instance_count = post_transforms.size()
		for i: int in range(post_transforms.size()):
			mm.set_instance_transform(i, post_transforms[i])
		var inst := MultiMeshInstance3D.new()
		inst.multimesh = mm
		inst.material_override = post_mat
		inst.name = "MultiMesh_HighwayGuardrails"
		add_child(inst)

func _build_perimeter_highway() -> void:
	var R: float = 2800.0 # 5.6km loop diameter across 50 km² map
	var num_pts := 288
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
		
	highway_waypoints = _smooth_road_heights(raw_points, true, 0.18)
	
	var road_mesh := _generate_ribbon_mesh(highway_waypoints, 14.0, true, "Grand Perimeter Highway", 0.18)
	add_child(road_mesh)
	road_nodes.append(road_mesh)

func _build_trans_expressway() -> void:
	var raw_points: Array[Vector3] = []
	var start_x := -3200.0
	var end_x := 3200.0
	var num_pts := 220
	
	for i in range(num_pts):
		var t := float(i) / float(num_pts - 1)
		var x: float = lerp(start_x, end_x, t)
		var z: float = sin(t * PI * 2.0) * 350.0 # Gentle S-curve through festival center
		var y := terrain_gen.get_height(x, z) + 0.21
		raw_points.append(Vector3(x, y, z))
		
	var road_mesh := _generate_ribbon_mesh(_smooth_road_heights(raw_points, false, 0.21), 12.0, false, "Trans-Continental Expressway", 0.21)
	add_child(road_mesh)
	road_nodes.append(road_mesh)

func _build_mountain_hillclimb() -> void:
	var raw_points: Array[Vector3] = []
	# Smooth sweeping Alpine switchbacks climbing into Frozen Pass peaks
	var base_pts: Array[Vector2] = [
		Vector2(0, 0),
		Vector2(-350, -320),
		Vector2(-680, -640),
		Vector2(-880, -960),
		Vector2(-1100, -1200),
		Vector2(-1200, -1580),
		Vector2(-1480, -1900),
		Vector2(-1620, -2280),
		Vector2(-2000, -2600)
	]
	
	for pt: Vector2 in base_pts:
		var x: float = pt.x
		var z: float = pt.y
		var y := terrain_gen.get_height(x, z) + 0.25
		raw_points.append(Vector3(x, y, z))
		
	var smooth_points := _smooth_road_heights(_subdivide_spline(raw_points, 22, 0.25), false, 0.25)
	road_centerlines["Frozen Pass Hillclimb"] = smooth_points
	scenic_rail_paths.append([smooth_points.slice(24, smooth_points.size()), 4.75])
	var road_mesh := _generate_ribbon_mesh(smooth_points, 9.5, false, "Frozen Pass Hillclimb", 0.25)
	add_child(road_mesh)
	road_nodes.append(road_mesh)

func _build_meridian_boulevard() -> void:
	var raw_points: Array[Vector3] = []
	var start_z := -3200.0
	var end_z := 3200.0
	var num_pts := 220
	for i in range(num_pts):
		var t := float(i) / float(num_pts - 1)
		var z: float = lerp(start_z, end_z, t)
		var x: float = cos(t * PI * 2.0) * 160.0
		var y := terrain_gen.get_height(x, z) + 0.23
		raw_points.append(Vector3(x, y, z))
	var road_mesh := _generate_ribbon_mesh(_smooth_road_heights(raw_points, false, 0.23), 12.0, false, "Meridian Central Boulevard", 0.23)
	add_child(road_mesh)
	road_nodes.append(road_mesh)

func _build_volcano_highway() -> void:
	var base_pts: Array[Vector2] = [
		Vector2(0, 0),
		Vector2(250, -220),
		Vector2(550, -480),
		Vector2(850, -780),
		Vector2(1150, -1100),
		Vector2(1400, -1450),
		Vector2(1750, -1750),
		Vector2(2100, -2000)
	]
	var raw_points: Array[Vector3] = []
	for pt: Vector2 in base_pts:
		var y := terrain_gen.get_height(pt.x, pt.y) + 0.27
		raw_points.append(Vector3(pt.x, y, pt.y))
	var smooth_pts := _smooth_road_heights(_subdivide_spline(raw_points, 22, 0.27), false, 0.27)
	road_centerlines["Volcano Ridge Scenic Highway"] = smooth_pts
	scenic_rail_paths.append([smooth_pts.slice(24, smooth_pts.size()), 5.5])
	var road_mesh := _generate_ribbon_mesh(smooth_pts, 11.0, false, "Volcano Ridge Scenic Highway", 0.27)
	add_child(road_mesh)
	road_nodes.append(road_mesh)

func _build_desert_canyon_highway() -> void:
	var base_pts: Array[Vector2] = [
		Vector2(0, 0),
		Vector2(-220, 240),
		Vector2(-480, 520),
		Vector2(-800, 820),
		Vector2(-1150, 1150),
		Vector2(-1480, 1420),
		Vector2(-1850, 1750),
		Vector2(-2200, 2100)
	]
	var raw_points: Array[Vector3] = []
	for pt: Vector2 in base_pts:
		var y := terrain_gen.get_height(pt.x, pt.y) + 0.29
		raw_points.append(Vector3(pt.x, y, pt.y))
	var smooth_pts := _smooth_road_heights(_subdivide_spline(raw_points, 22, 0.29), false, 0.29)
	road_centerlines["Dust Bowl Canyon Highway"] = smooth_pts
	var road_mesh := _generate_ribbon_mesh(smooth_pts, 11.0, false, "Dust Bowl Canyon Highway", 0.29)
	add_child(road_mesh)
	road_nodes.append(road_mesh)

func _build_coastal_promenade() -> void:
	var base_pts: Array[Vector2] = [
		Vector2(1600, 2200),
		Vector2(1850, 1600),
		Vector2(2050, 1000),
		Vector2(2150, 350),
		Vector2(2200, -300),
		Vector2(2050, -950),
		Vector2(1750, -1550)
	]
	var raw_points: Array[Vector3] = []
	for pt: Vector2 in base_pts:
		var y := terrain_gen.get_height(pt.x, pt.y) + 0.31
		raw_points.append(Vector3(pt.x, y, pt.y))
	var smooth_pts := _smooth_road_heights(_subdivide_spline(raw_points, 22, 0.31), false, 0.31)
	road_centerlines["Neon Coastline Promenade"] = smooth_pts
	var road_mesh := _generate_ribbon_mesh(smooth_pts, 11.5, false, "Neon Coastline Promenade", 0.31)
	add_child(road_mesh)
	road_nodes.append(road_mesh)

func _build_desert_alpine_pass() -> void:
	var base_pts: Array[Vector2] = [
		Vector2(-2200, 1600),
		Vector2(-2350, 950),
		Vector2(-2400, 300),
		Vector2(-2300, -350),
		Vector2(-2150, -1000),
		Vector2(-1950, -1650),
		Vector2(-1650, -2200)
	]
	var raw_points: Array[Vector3] = []
	for pt: Vector2 in base_pts:
		var y := terrain_gen.get_height(pt.x, pt.y) + 0.32
		raw_points.append(Vector3(pt.x, y, pt.y))
	var smooth_pts := _smooth_road_heights(_subdivide_spline(raw_points, 22, 0.32), false, 0.32)
	var road_mesh := _generate_ribbon_mesh(smooth_pts, 10.0, false, "Desert-Alpine Ridge Connector", 0.32)
	add_child(road_mesh)
	road_nodes.append(road_mesh)

func _smooth_road_heights(pts: Array[Vector3], is_closed: bool, elev_offset: float) -> Array[Vector3]:
	var n: int = pts.size()
	if n < 3:
		return pts
	var ys: PackedFloat32Array = PackedFloat32Array()
	ys.resize(n)
	for i: int in range(n):
		ys[i] = maxf(terrain_gen.get_height(pts[i].x, pts[i].z), 2.5) + elev_offset
	for _pass: int in range(4):
		var next_ys := ys.duplicate()
		for i: int in range(n):
			if not is_closed and (i == 0 or i == n - 1):
				continue
			var i_prev: int = (i - 1 + n) % n
			var i_next: int = (i + 1) % n
			next_ys[i] = maxf(ys[i], 0.25 * ys[i_prev] + 0.5 * ys[i] + 0.25 * ys[i_next])
		ys = next_ys
	var out: Array[Vector3] = []
	out.resize(n)
	for i: int in range(n):
		var p: Vector3 = pts[i]
		p.y = ys[i]
		out[i] = p
	return out

func _generate_ribbon_mesh(points: Array[Vector3], road_width: float, is_closed: bool, road_name: String, elev_offset: float = 0.20) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n_pts := points.size()
	var half_w := road_width * 0.5
	var u_distance: float = 0.0

	var max_idx := n_pts if is_closed else (n_pts - 1)
	for i in range(max_idx):
		var curr_p := points[i % n_pts]
		var next_p := points[(i + 1) % n_pts]
		var seg_len: float = curr_p.distance_to(next_p)
		if seg_len < 0.01:
			continue
		all_road_segments.append({"p0": curr_p, "p1": next_p, "half_w": half_w, "offset": elev_offset})
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

		# Main carriage surface + sloped side embankment skirts anchoring into terrain
		var p_LS := curr_p - (right * (half_w + 2.4)) - Vector3(0.0, 1.4, 0.0)
		var p_L0 := curr_p - (right * half_w)
		var p_C0 := curr_p
		var p_R0 := curr_p + (right * half_w)
		var p_RS := curr_p + (right * (half_w + 2.4)) - Vector3(0.0, 1.4, 0.0)

		var np_LS := next_p - (next_right * (half_w + 2.4)) - Vector3(0.0, 1.4, 0.0)
		var np_L0 := next_p - (next_right * half_w)
		var np_C0 := next_p
		var np_R0 := next_p + (next_right * half_w)
		var np_RS := next_p + (next_right * (half_w + 2.4)) - Vector3(0.0, 1.4, 0.0)

		var u0 := u_distance * 0.1
		var u1 := (u_distance + seg_len) * 0.1
		u_distance += seg_len

		# Left sloped curb skirt
		st.set_normal(Vector3(-right.x * 0.4, 0.9, -right.z * 0.4).normalized())
		st.set_uv(Vector2(0.0, u0)); st.add_vertex(p_LS)
		st.set_uv(Vector2(0.0, u1)); st.add_vertex(np_LS)
		st.set_uv(Vector2(0.01, u0)); st.add_vertex(p_L0)
		st.set_uv(Vector2(0.01, u0)); st.add_vertex(p_L0)
		st.set_uv(Vector2(0.0, u1)); st.add_vertex(np_LS)
		st.set_uv(Vector2(0.01, u1)); st.add_vertex(np_L0)

		# Quad 1: Left lane (UV.x: 0.0 to 0.5)
		st.set_normal(Vector3.UP); st.set_uv(Vector2(0.0, u0)); st.add_vertex(p_L0)
		st.set_normal(Vector3.UP); st.set_uv(Vector2(0.0, u1)); st.add_vertex(np_L0)
		st.set_normal(Vector3.UP); st.set_uv(Vector2(0.5, u0)); st.add_vertex(p_C0)

		st.set_normal(Vector3.UP); st.set_uv(Vector2(0.5, u0)); st.add_vertex(p_C0)
		st.set_normal(Vector3.UP); st.set_uv(Vector2(0.0, u1)); st.add_vertex(np_L0)
		st.set_normal(Vector3.UP); st.set_uv(Vector2(0.5, u1)); st.add_vertex(np_C0)

		# Quad 2: Right lane (UV.x: 0.5 to 1.0)
		st.set_normal(Vector3.UP); st.set_uv(Vector2(0.5, u0)); st.add_vertex(p_C0)
		st.set_normal(Vector3.UP); st.set_uv(Vector2(0.5, u1)); st.add_vertex(np_C0)
		st.set_normal(Vector3.UP); st.set_uv(Vector2(1.0, u0)); st.add_vertex(p_R0)

		st.set_normal(Vector3.UP); st.set_uv(Vector2(1.0, u0)); st.add_vertex(p_R0)
		st.set_normal(Vector3.UP); st.set_uv(Vector2(0.5, u1)); st.add_vertex(np_C0)
		st.set_normal(Vector3.UP); st.set_uv(Vector2(1.0, u1)); st.add_vertex(np_R0)

		# Right sloped curb skirt
		st.set_normal(Vector3(right.x * 0.4, 0.9, right.z * 0.4).normalized())
		st.set_uv(Vector2(0.99, u0)); st.add_vertex(p_R0)
		st.set_uv(Vector2(0.99, u1)); st.add_vertex(np_R0)
		st.set_uv(Vector2(1.0, u0)); st.add_vertex(p_RS)
		st.set_uv(Vector2(1.0, u0)); st.add_vertex(p_RS)
		st.set_uv(Vector2(0.99, u1)); st.add_vertex(np_R0)
		st.set_uv(Vector2(1.0, u1)); st.add_vertex(np_RS)

	st.index()
	st.generate_normals()
	st.generate_tangents()
	
	var mesh := st.commit()
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.name = road_name
	
	# PBR Road Material with Authentic Highway Markings Shader
	var road_shader := load("res://shaders/road.gdshader") as Shader
	if road_shader:
		var s_mat := ShaderMaterial.new()
		s_mat.shader = road_shader
		var tex_asphalt_d := load("res://assets/textures/asphalt_diff.jpg") as Texture2D
		var tex_asphalt_n := load("res://assets/textures/asphalt_nor.jpg") as Texture2D
		var tex_asphalt_r := load("res://assets/textures/asphalt_rough.jpg") as Texture2D
		if tex_asphalt_d: s_mat.set_shader_parameter("texture_albedo", tex_asphalt_d)
		if tex_asphalt_n: s_mat.set_shader_parameter("texture_normal", tex_asphalt_n)
		if tex_asphalt_r: s_mat.set_shader_parameter("texture_roughness", tex_asphalt_r)
		inst.material_override = s_mat
	else:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.18, 0.18, 0.20)
		mat.roughness = 0.55
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		inst.material_override = mat
	
	# StaticBody3D collision with Asphalt Surface Metadata
	var body := StaticBody3D.new()
	body.set_meta("surface", "asphalt_dry")
	var col := CollisionShape3D.new()
	col.shape = mesh.create_trimesh_shape()
	body.add_child(col)
	inst.add_child(body)
	
	return inst

func _subdivide_spline(pts: Array[Vector3], subdivisions: int, elev_offset: float = 0.22) -> Array[Vector3]:
	var result: Array[Vector3] = []
	for i in range(pts.size() - 1):
		var p0 := pts[max(0, i - 1)]
		var p1 := pts[i]
		var p2 := pts[i + 1]
		var p3 := pts[min(pts.size() - 1, i + 2)]
		
		for s in range(subdivisions):
			var t := float(s) / float(subdivisions)
			var interp := _catmull_rom(p0, p1, p2, p3, t)
			interp.y = terrain_gen.get_height(interp.x, interp.z) + elev_offset
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
