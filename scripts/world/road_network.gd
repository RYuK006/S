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

func _init(tg: TerrainGenerator = null) -> void:
	if tg:
		terrain_gen = tg
	else:
		terrain_gen = TerrainGenerator.new()

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

func build_open_world_roads() -> void:
	_build_perimeter_highway()
	_build_trans_expressway()
	_build_meridian_boulevard()
	_build_volcano_highway()
	_build_desert_canyon_highway()
	_build_coastal_promenade()
	_build_desert_alpine_pass()
	_build_mountain_hillclimb()
	_build_festival_starting_grid()

	if terrain_gen:
		terrain_gen.set_road_segments(all_road_segments)

	_build_highway_guardrails()

func _build_festival_starting_grid() -> void:
	var pts: Array[Vector3] = []
	for i: int in range(25):
		var z_val: float = -80.0 + (float(i) * 6.5)
		var y_val: float = terrain_gen.get_height(0.0, z_val) + 0.34
		pts.append(Vector3(0.0, y_val, z_val))
	var road_mesh: MeshInstance3D = _generate_ribbon_mesh(pts, 14.0, false, "Festival Starting Grid", 0.34)
	add_child(road_mesh)
	road_nodes.append(road_mesh)

func _build_highway_guardrails() -> void:
	if scenic_rail_paths.is_empty():
		return

	var steel_mat := StandardMaterial3D.new()
	steel_mat.albedo_color = Color(0.56, 0.59, 0.64)
	steel_mat.metallic = 0.88
	steel_mat.roughness = 0.28
	steel_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	var post_mat := StandardMaterial3D.new()
	post_mat.albedo_color = Color(0.30, 0.32, 0.36)
	post_mat.metallic = 0.80
	post_mat.roughness = 0.42

	var refl_mat := StandardMaterial3D.new()
	refl_mat.albedo_color = Color(1.0, 0.58, 0.06)
	refl_mat.emission_enabled = true
	refl_mat.emission = Color(1.0, 0.52, 0.05)
	refl_mat.emission_energy_multiplier = 1.6

	# 3D Corrugated Armco W-Beam profile: (roadward offset, height above road bed)
	var prof_out: PackedFloat32Array = PackedFloat32Array([0.04, -0.07, 0.03, -0.07, 0.04, 0.07, 0.07])
	var prof_y: PackedFloat32Array = PackedFloat32Array([0.42, 0.50, 0.59, 0.68, 0.77, 0.77, 0.42])

	var rail_st := SurfaceTool.new()
	rail_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var post_transforms: Array[Transform3D] = []
	var refl_transforms: Array[Transform3D] = []

	for path_arr: Array in scenic_rail_paths:
		var pts: Array[Vector3] = path_arr[0]
		var half_w: float = float(path_arr[1])
		if pts.size() < 2:
			continue
		for side: float in [-1.0, 1.0]:
			var rail_offset: float = (half_w + 0.55) * side
			var post_accum: float = 0.0
			for i: int in range(pts.size() - 1):
				var p0: Vector3 = pts[i]
				var p1: Vector3 = pts[i + 1]
				var seg_len: float = Vector2(p1.x - p0.x, p1.z - p0.z).length()
				if seg_len < 0.25:
					continue
				var fwd0: Vector3 = (p1 - p0).normalized()
				var right0: Vector3 = fwd0.cross(Vector3.UP).normalized()
				var fwd1: Vector3 = fwd0
				if i + 2 < pts.size():
					fwd1 = (pts[i + 2] - p1).normalized()
				var right1: Vector3 = fwd1.cross(Vector3.UP).normalized()

				var r0: Vector3 = p0 + right0 * rail_offset
				var r1: Vector3 = p1 + right1 * rail_offset
				var inward0: Vector3 = right0 * (-side)
				var inward1: Vector3 = right1 * (-side)

				for k: int in range(prof_y.size() - 1):
					var a0: Vector3 = r0 - inward0 * prof_out[k] + Vector3(0.0, prof_y[k], 0.0)
					var a1: Vector3 = r0 - inward0 * prof_out[k + 1] + Vector3(0.0, prof_y[k + 1], 0.0)
					var b0: Vector3 = r1 - inward1 * prof_out[k] + Vector3(0.0, prof_y[k], 0.0)
					var b1: Vector3 = r1 - inward1 * prof_out[k + 1] + Vector3(0.0, prof_y[k + 1], 0.0)
					rail_st.add_vertex(a0); rail_st.add_vertex(b0); rail_st.add_vertex(a1)
					rail_st.add_vertex(a1); rail_st.add_vertex(b0); rail_st.add_vertex(b1)

				post_accum += seg_len
				var num_posts: int = int(floorf(post_accum / 8.0))
				for k: int in range(num_posts):
					var f: float = float(k + 1) / float(num_posts + 1)
					var rp: Vector3 = r0.lerp(r1, f)
					var pp: Vector3 = rp - inward0 * 0.14 + Vector3(0.0, 0.39, 0.0)
					var rpos: Vector3 = rp + inward0 * 0.05 + Vector3(0.0, 0.60, 0.0)
					var yaw: float = atan2(fwd0.x, fwd0.z)
					post_transforms.append(Transform3D(Basis(Vector3.UP, yaw), pp))
					refl_transforms.append(Transform3D(Basis(Vector3.UP, yaw), rpos))
				post_accum = fmod(post_accum, 8.0)

	rail_st.index()
	rail_st.generate_normals()
	var rail_inst := MeshInstance3D.new()
	rail_inst.mesh = rail_st.commit()
	rail_inst.material_override = steel_mat
	rail_inst.name = "Mesh_ScenicGuardrails"
	add_child(rail_inst)

	_spawn_rail_multimesh("MultiMesh_HighwayGuardrails", Vector3(0.14, 0.86, 0.16), post_mat, post_transforms)
	_spawn_rail_multimesh("MultiMesh_GuardrailReflectors", Vector3(0.06, 0.09, 0.14), refl_mat, refl_transforms)

func _spawn_rail_multimesh(mm_name: String, box_sz: Vector3, mat: Material, xforms: Array[Transform3D]) -> void:
	if xforms.is_empty():
		return
	var box := BoxMesh.new()
	box.size = box_sz
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = box
	mm.instance_count = xforms.size()
	for i: int in range(xforms.size()):
		mm.set_instance_transform(i, xforms[i])
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	inst.material_override = mat
	inst.name = mm_name
	inst.visibility_range_end = 520.0
	add_child(inst)

func _build_perimeter_highway() -> void:
	var rad_base: float = 2800.0
	var num_pts: int = 288
	var raw_points: Array[Vector3] = []
	for i: int in range(num_pts):
		var angle: float = (float(i) / float(num_pts)) * TAU
		var r_mod: float = 1.0 + (sin(angle * 3.0) * 0.12) + (cos(angle * 5.0) * 0.06)
		var x: float = cos(angle) * rad_base * r_mod
		var z: float = sin(angle) * rad_base * r_mod
		raw_points.append(Vector3(x, terrain_gen.get_height(x, z) + 0.18, z))
	highway_waypoints = _smooth_road_heights(raw_points, true, 0.18)
	var road_mesh: MeshInstance3D = _generate_ribbon_mesh(highway_waypoints, 14.0, true, "Grand Perimeter Highway", 0.18)
	add_child(road_mesh)
	road_nodes.append(road_mesh)

func _build_trans_expressway() -> void:
	var raw_points: Array[Vector3] = []
	var num_pts: int = 220
	for i: int in range(num_pts):
		var t: float = float(i) / float(num_pts - 1)
		var x: float = lerpf(-3200.0, 3200.0, t)
		var z: float = sin(t * PI * 2.0) * 350.0
		raw_points.append(Vector3(x, terrain_gen.get_height(x, z) + 0.21, z))
	var road_mesh: MeshInstance3D = _generate_ribbon_mesh(_smooth_road_heights(raw_points, false, 0.21), 12.0, false, "Trans-Continental Expressway", 0.21)
	add_child(road_mesh)
	road_nodes.append(road_mesh)

func _build_mountain_hillclimb() -> void:
	var base_pts: Array[Vector2] = [
		Vector2(0, 0), Vector2(-350, -320), Vector2(-680, -640),
		Vector2(-880, -960), Vector2(-1100, -1200), Vector2(-1200, -1580),
		Vector2(-1480, -1900), Vector2(-1620, -2280), Vector2(-2000, -2600)
	]
	var raw_points: Array[Vector3] = _pts2_to_3(base_pts, 0.25)
	var smooth_points: Array[Vector3] = _smooth_road_heights(_subdivide_spline(raw_points, 24, 0.25), false, 0.25)
	road_centerlines["Frozen Pass Hillclimb"] = smooth_points
	scenic_rail_paths.append([smooth_points.slice(24, smooth_points.size()), 4.75])
	var road_mesh: MeshInstance3D = _generate_ribbon_mesh(smooth_points, 9.5, false, "Frozen Pass Hillclimb", 0.25)
	add_child(road_mesh)
	road_nodes.append(road_mesh)

func _build_meridian_boulevard() -> void:
	var raw_points: Array[Vector3] = []
	var num_pts: int = 220
	for i: int in range(num_pts):
		var t: float = float(i) / float(num_pts - 1)
		var z: float = lerpf(-3200.0, 3200.0, t)
		var x: float = cos(t * PI * 2.0) * 160.0
		raw_points.append(Vector3(x, terrain_gen.get_height(x, z) + 0.23, z))
	var road_mesh: MeshInstance3D = _generate_ribbon_mesh(_smooth_road_heights(raw_points, false, 0.23), 12.0, false, "Meridian Central Boulevard", 0.23)
	add_child(road_mesh)
	road_nodes.append(road_mesh)

func _build_volcano_highway() -> void:
	# Sweeping mountain climb skirting cleanly around the SE flank of La Gran Caldera (980, -1140)
	var base_pts: Array[Vector2] = [
		Vector2(0, 0), Vector2(280, -240), Vector2(620, -520),
		Vector2(980, -760), Vector2(1340, -960), Vector2(1580, -1240),
		Vector2(1820, -1620), Vector2(2100, -2000)
	]
	var smooth_pts: Array[Vector3] = _smooth_road_heights(_subdivide_spline(_pts2_to_3(base_pts, 0.27), 24, 0.27), false, 0.27)
	road_centerlines["Volcano Ridge Scenic Highway"] = smooth_pts
	scenic_rail_paths.append([smooth_pts.slice(24, smooth_pts.size()), 5.5])
	var road_mesh: MeshInstance3D = _generate_ribbon_mesh(smooth_pts, 11.0, false, "Volcano Ridge Scenic Highway", 0.27)
	add_child(road_mesh)
	road_nodes.append(road_mesh)

func _build_desert_canyon_highway() -> void:
	var base_pts: Array[Vector2] = [
		Vector2(0, 0), Vector2(-220, 240), Vector2(-480, 520),
		Vector2(-800, 820), Vector2(-1150, 1150), Vector2(-1480, 1420),
		Vector2(-1850, 1750), Vector2(-2200, 2100)
	]
	var smooth_pts: Array[Vector3] = _smooth_road_heights(_subdivide_spline(_pts2_to_3(base_pts, 0.29), 24, 0.29), false, 0.29)
	road_centerlines["Dust Bowl Canyon Highway"] = smooth_pts
	var road_mesh: MeshInstance3D = _generate_ribbon_mesh(smooth_pts, 11.0, false, "Dust Bowl Canyon Highway", 0.29)
	add_child(road_mesh)
	road_nodes.append(road_mesh)

func _build_coastal_promenade() -> void:
	var base_pts: Array[Vector2] = [
		Vector2(1600, 2200), Vector2(1850, 1600), Vector2(2040, 1000),
		Vector2(2130, 350), Vector2(2170, -300), Vector2(2020, -950),
		Vector2(1750, -1550)
	]
	var smooth_pts: Array[Vector3] = _smooth_road_heights(_subdivide_spline(_pts2_to_3(base_pts, 0.31), 24, 0.31), false, 0.31)
	road_centerlines["Neon Coastline Promenade"] = smooth_pts
	scenic_rail_paths.append([smooth_pts.slice(8, smooth_pts.size() - 8), 5.75])
	var road_mesh: MeshInstance3D = _generate_ribbon_mesh(smooth_pts, 11.5, false, "Neon Coastline Promenade", 0.31)
	add_child(road_mesh)
	road_nodes.append(road_mesh)

func _build_desert_alpine_pass() -> void:
	var base_pts: Array[Vector2] = [
		Vector2(-2200, 1600), Vector2(-2350, 950), Vector2(-2400, 300),
		Vector2(-2300, -350), Vector2(-2150, -1000), Vector2(-1950, -1650),
		Vector2(-1650, -2200)
	]
	var smooth_pts: Array[Vector3] = _smooth_road_heights(_subdivide_spline(_pts2_to_3(base_pts, 0.32), 24, 0.32), false, 0.32)
	var road_mesh: MeshInstance3D = _generate_ribbon_mesh(smooth_pts, 10.0, false, "Desert-Alpine Ridge Connector", 0.32)
	add_child(road_mesh)
	road_nodes.append(road_mesh)

func _pts2_to_3(arr: Array[Vector2], off: float) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for pt: Vector2 in arr:
		out.append(Vector3(pt.x, terrain_gen.get_height(pt.x, pt.y) + off, pt.y))
	return out

func _smooth_road_heights(pts: Array[Vector3], is_closed: bool, elev_offset: float) -> Array[Vector3]:
	var n: int = pts.size()
	if n < 3:
		return pts
	var ys: PackedFloat32Array = PackedFloat32Array()
	ys.resize(n)
	for i: int in range(n):
		ys[i] = maxf(terrain_gen.get_height(pts[i].x, pts[i].z), 4.0) + elev_offset
	for _pass: int in range(10):
		var next_ys: PackedFloat32Array = ys.duplicate()
		for i: int in range(n):
			if not is_closed and (i == 0 or i == n - 1):
				continue
			var i_prev: int = (i - 1 + n) % n
			var i_next: int = (i + 1) % n
			next_ys[i] = maxf(ys[i] - 0.12, 0.25 * ys[i_prev] + 0.5 * ys[i] + 0.25 * ys[i_next])
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
	var n_pts: int = points.size()
	var half_w: float = road_width * 0.5
	var u_distance: float = 0.0

	var max_idx: int = n_pts if is_closed else (n_pts - 1)
	for i: int in range(max_idx):
		var curr_p: Vector3 = points[i % n_pts]
		var next_p: Vector3 = points[(i + 1) % n_pts]
		var seg_len: float = curr_p.distance_to(next_p)
		if seg_len < 0.01:
			continue
		all_road_segments.append({"p0": curr_p, "p1": next_p, "half_w": half_w, "offset": elev_offset})
		var fwd: Vector3 = (next_p - curr_p).normalized()
		var right: Vector3 = fwd.cross(Vector3.UP).normalized()

		var next_next_p: Vector3
		if is_closed:
			next_next_p = points[(i + 2) % n_pts]
		elif i + 2 < n_pts:
			next_next_p = points[i + 2]
		else:
			next_next_p = next_p + fwd * seg_len
		var next_fwd: Vector3 = (next_next_p - next_p).normalized()
		var next_right: Vector3 = next_fwd.cross(Vector3.UP).normalized()

		# Wide sloped gravel shoulder embankments that weld directly into carved terrain
		var p_LS: Vector3 = curr_p - (right * (half_w + 4.4)) - Vector3(0.0, 1.5, 0.0)
		var p_L0: Vector3 = curr_p - (right * half_w)
		var p_C0: Vector3 = curr_p
		var p_R0: Vector3 = curr_p + (right * half_w)
		var p_RS: Vector3 = curr_p + (right * (half_w + 4.4)) - Vector3(0.0, 1.5, 0.0)

		var np_LS: Vector3 = next_p - (next_right * (half_w + 4.4)) - Vector3(0.0, 1.5, 0.0)
		var np_L0: Vector3 = next_p - (next_right * half_w)
		var np_C0: Vector3 = next_p
		var np_R0: Vector3 = next_p + (next_right * half_w)
		var np_RS: Vector3 = next_p + (next_right * (half_w + 4.4)) - Vector3(0.0, 1.5, 0.0)

		var u0: float = u_distance * 0.1
		var u1: float = (u_distance + seg_len) * 0.1
		u_distance += seg_len

		# Left gravel embankment skirt (UV.x: 0.0 .. 0.09)
		st.set_normal(Vector3(-right.x * 0.35, 0.94, -right.z * 0.35).normalized())
		st.set_uv(Vector2(0.0, u0)); st.add_vertex(p_LS)
		st.set_uv(Vector2(0.0, u1)); st.add_vertex(np_LS)
		st.set_uv(Vector2(0.09, u0)); st.add_vertex(p_L0)
		st.set_uv(Vector2(0.09, u0)); st.add_vertex(p_L0)
		st.set_uv(Vector2(0.0, u1)); st.add_vertex(np_LS)
		st.set_uv(Vector2(0.09, u1)); st.add_vertex(np_L0)

		# Left asphalt carriageway (UV.x: 0.09 .. 0.50)
		st.set_normal(Vector3.UP); st.set_uv(Vector2(0.09, u0)); st.add_vertex(p_L0)
		st.set_normal(Vector3.UP); st.set_uv(Vector2(0.09, u1)); st.add_vertex(np_L0)
		st.set_normal(Vector3.UP); st.set_uv(Vector2(0.50, u0)); st.add_vertex(p_C0)
		st.set_normal(Vector3.UP); st.set_uv(Vector2(0.50, u0)); st.add_vertex(p_C0)
		st.set_normal(Vector3.UP); st.set_uv(Vector2(0.09, u1)); st.add_vertex(np_L0)
		st.set_normal(Vector3.UP); st.set_uv(Vector2(0.50, u1)); st.add_vertex(np_C0)

		# Right asphalt carriageway (UV.x: 0.50 .. 0.91)
		st.set_normal(Vector3.UP); st.set_uv(Vector2(0.50, u0)); st.add_vertex(p_C0)
		st.set_normal(Vector3.UP); st.set_uv(Vector2(0.50, u1)); st.add_vertex(np_C0)
		st.set_normal(Vector3.UP); st.set_uv(Vector2(0.91, u0)); st.add_vertex(p_R0)
		st.set_normal(Vector3.UP); st.set_uv(Vector2(0.91, u0)); st.add_vertex(p_R0)
		st.set_normal(Vector3.UP); st.set_uv(Vector2(0.50, u1)); st.add_vertex(np_C0)
		st.set_normal(Vector3.UP); st.set_uv(Vector2(0.91, u1)); st.add_vertex(np_R0)

		# Right gravel embankment skirt (UV.x: 0.91 .. 1.00)
		st.set_normal(Vector3(right.x * 0.35, 0.94, right.z * 0.35).normalized())
		st.set_uv(Vector2(0.91, u0)); st.add_vertex(p_R0)
		st.set_uv(Vector2(0.91, u1)); st.add_vertex(np_R0)
		st.set_uv(Vector2(1.00, u0)); st.add_vertex(p_RS)
		st.set_uv(Vector2(1.00, u0)); st.add_vertex(p_RS)
		st.set_uv(Vector2(0.91, u1)); st.add_vertex(np_R0)
		st.set_uv(Vector2(1.00, u1)); st.add_vertex(np_RS)

	st.index()
	st.generate_normals()
	st.generate_tangents()

	var mesh: ArrayMesh = st.commit()
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.name = road_name
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var road_shader := load("res://shaders/road.gdshader") as Shader
	if road_shader:
		var s_mat := ShaderMaterial.new()
		s_mat.shader = road_shader
		var td := load("res://assets/textures/asphalt_diff.jpg") as Texture2D
		var tn := load("res://assets/textures/asphalt_nor.jpg") as Texture2D
		var tr := load("res://assets/textures/asphalt_rough.jpg") as Texture2D
		var gd := load("res://assets/textures/gravel_diff.jpg") as Texture2D
		var gn := load("res://assets/textures/gravel_nor.jpg") as Texture2D
		var gr := load("res://assets/textures/gravel_rough.jpg") as Texture2D
		if td: s_mat.set_shader_parameter("texture_albedo", td)
		if tn: s_mat.set_shader_parameter("texture_normal", tn)
		if tr: s_mat.set_shader_parameter("texture_roughness", tr)
		if gd: s_mat.set_shader_parameter("texture_gravel_diff", gd)
		if gn: s_mat.set_shader_parameter("texture_gravel_nor", gn)
		if gr: s_mat.set_shader_parameter("texture_gravel_rough", gr)
		inst.material_override = s_mat
	else:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.18, 0.18, 0.20)
		mat.roughness = 0.55
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		inst.material_override = mat

	var body := StaticBody3D.new()
	body.set_meta("surface", "asphalt_dry")
	var col := CollisionShape3D.new()
	col.shape = mesh.create_trimesh_shape()
	body.add_child(col)
	inst.add_child(body)
	return inst

func _subdivide_spline(pts: Array[Vector3], subdivisions: int, elev_offset: float = 0.22) -> Array[Vector3]:
	var result: Array[Vector3] = []
	for i: int in range(pts.size() - 1):
		var p0: Vector3 = pts[maxi(0, i - 1)]
		var p1: Vector3 = pts[i]
		var p2: Vector3 = pts[i + 1]
		var p3: Vector3 = pts[mini(pts.size() - 1, i + 2)]
		for s: int in range(subdivisions):
			var t: float = float(s) / float(subdivisions)
			var interp: Vector3 = _catmull_rom(p0, p1, p2, p3, t)
			interp.y = terrain_gen.get_height(interp.x, interp.z) + elev_offset
			result.append(interp)
	result.append(pts[-1])
	return result

func _catmull_rom(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	var t2: float = t * t
	var t3: float = t2 * t
	return 0.5 * (
		(2.0 * p1) +
		(-p0 + p2) * t +
		(2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 +
		(-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3
	)
