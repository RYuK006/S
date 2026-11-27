# scripts/world/road_network.gd
class_name RoadNetwork
extends Node3D

const TerrainGenerator = preload("res://scripts/world/terrain_generator.gd")

var terrain_gen: TerrainGenerator
var road_nodes: Array[Node3D] = []
var highway_waypoints: Array[Vector3] = []
var all_road_segments: Array[Dictionary] = []
var road_seg_grid: Dictionary = {} # Vector2i -> Array[int] into all_road_segments
const CLEAR_GRID_CELL: float = 128.0
var scenic_rail_paths: Array[Array] = []
var road_centerlines: Dictionary = {}

func _init(tg: TerrainGenerator = null) -> void:
	if tg:
		terrain_gen = tg
	else:
		terrain_gen = TerrainGenerator.new()

func is_point_clear_of_roads(x: float, z: float, obj_radius: float = 11.5, ignore_road_name: String = "") -> bool:
	if road_seg_grid.is_empty():
		return true
	var p2 := Vector2(x, z)
	var cx: int = int(floorf(x / CLEAR_GRID_CELL))
	var cz: int = int(floorf(z / CLEAR_GRID_CELL))
	var cell_r: int = int(ceilf((obj_radius + 20.0) / CLEAR_GRID_CELL))
	for gz: int in range(cz - cell_r, cz + cell_r + 1):
		for gx: int in range(cx - cell_r, cx + cell_r + 1):
			var k := Vector2i(gx, gz)
			if not road_seg_grid.has(k):
				continue
			var idxs: Array[int] = road_seg_grid[k]
			for idx: int in idxs:
				var seg: Dictionary = all_road_segments[idx]
				if not ignore_road_name.is_empty() and str(seg.get("road", "")) == ignore_road_name:
					continue
				var a3: Vector3 = seg["p0"]
				var b3: Vector3 = seg["p1"]
				var a := Vector2(a3.x, a3.z)
				var b := Vector2(b3.x, b3.z)
				var ab: Vector2 = b - a
				var lsq: float = ab.length_squared()
				var t: float = clampf((p2 - a).dot(ab) / lsq, 0.0, 1.0) if lsq > 0.0001 else 0.0
				var d: float = p2.distance_to(a + ab * t)
				if d < float(seg["half_w"]) + obj_radius:
					return false
	return true

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
	if not _build_roads_from_json("res://data/real_world_roads.json"):
		_build_perimeter_highway()
		_build_trans_expressway()
		_build_meridian_boulevard()
		_build_volcano_highway()
		_build_desert_canyon_highway()
		_build_coastal_promenade()
		_build_desert_alpine_pass()
		_build_mountain_hillclimb()
		_build_festival_starting_grid()

	_rebuild_road_spatial_grid()
	if terrain_gen:
		terrain_gen.set_road_segments(all_road_segments)

	_build_highway_guardrails()

func _build_roads_from_json(json_path: String) -> bool:
	if not FileAccess.file_exists(json_path):
		return false
	var f := FileAccess.open(json_path, FileAccess.READ)
	if not f:
		return false
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if not (parsed is Dictionary):
		return false
	var d: Dictionary = parsed
	var roads_arr: Array = d.get("roads", [])
	if roads_arr.is_empty():
		return false

	for r_item: Variant in roads_arr:
		if not (r_item is Dictionary):
			continue
		var r_dict: Dictionary = r_item
		var raw_pts: Array = r_dict.get("points", [])
		if raw_pts.size() < 2:
			continue
		var r_name: String = str(r_dict.get("name", "Road"))
		var kind_str: String = str(r_dict.get("kind", "arterial"))
		var surf_str: String = str(r_dict.get("surface", "asphalt_dry"))
		var road_w: float = float(r_dict.get("width", 11.0))
		var closed: bool = bool(r_dict.get("closed", false))
		var has_rails: bool = bool(r_dict.get("guardrails", false))
		var elev_off: float = float(r_dict.get("elev_offset", 0.22))

		var pts3: Array[Vector3] = _subdivide_polyline_max_len(raw_pts, closed, elev_off, 10.5)
		var smooth_pts: Array[Vector3] = _smooth_road_heights(pts3, closed, elev_off)
		road_centerlines[r_name] = smooth_pts
		if r_name == "Grand Perimeter Highway":
			highway_waypoints = smooth_pts
		if has_rails and smooth_pts.size() > 16:
			scenic_rail_paths.append([smooth_pts.slice(4, smooth_pts.size() - 4), road_w * 0.5, r_name])

		var s_mode: int = 2 if surf_str == "gravel" else (1 if kind_str == "town_street" else 0)
		var road_mesh: MeshInstance3D = _generate_ribbon_mesh(smooth_pts, road_w, closed, r_name, elev_off, s_mode, surf_str)
		add_child(road_mesh)
		road_nodes.append(road_mesh)

	if highway_waypoints.is_empty() and not road_centerlines.is_empty():
		var first_key: String = str(road_centerlines.keys()[0])
		highway_waypoints = road_centerlines[first_key]
	return road_nodes.size() >= 6

func _rebuild_road_spatial_grid() -> void:
	road_seg_grid.clear()
	for idx: int in range(all_road_segments.size()):
		var seg: Dictionary = all_road_segments[idx]
		var p0: Vector3 = seg["p0"]
		var p1: Vector3 = seg["p1"]
		var pad: float = float(seg.get("half_w", 6.0)) + 28.0
		var min_cx: int = int(floorf((minf(p0.x, p1.x) - pad) / CLEAR_GRID_CELL))
		var max_cx: int = int(floorf((maxf(p0.x, p1.x) + pad) / CLEAR_GRID_CELL))
		var min_cz: int = int(floorf((minf(p0.z, p1.z) - pad) / CLEAR_GRID_CELL))
		var max_cz: int = int(floorf((maxf(p0.z, p1.z) + pad) / CLEAR_GRID_CELL))
		for cz: int in range(min_cz, max_cz + 1):
			for cx: int in range(min_cx, max_cx + 1):
				var k := Vector2i(cx, cz)
				if not road_seg_grid.has(k):
					var b: Array[int] = []
					road_seg_grid[k] = b
				(road_seg_grid[k] as Array[int]).append(idx)

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
	steel_mat.albedo_color = Color(0.32, 0.34, 0.37)
	steel_mat.metallic = 0.58
	steel_mat.roughness = 0.46
	steel_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	var post_mat := StandardMaterial3D.new()
	post_mat.albedo_color = Color(0.24, 0.25, 0.28)
	post_mat.metallic = 0.55
	post_mat.roughness = 0.55

	var refl_mat := StandardMaterial3D.new()
	refl_mat.albedo_color = Color(1.0, 0.58, 0.06)
	refl_mat.emission_enabled = true
	refl_mat.emission = Color(1.0, 0.52, 0.05)
	refl_mat.emission_energy_multiplier = 1.4

	# 3D Corrugated Armco W-Beam profile: (roadward offset, height above road bed)
	var prof_out: PackedFloat32Array = PackedFloat32Array([0.04, -0.06, 0.03, -0.06, 0.04, 0.06, 0.06])
	var prof_y: PackedFloat32Array = PackedFloat32Array([0.32, 0.40, 0.48, 0.56, 0.64, 0.64, 0.32])

	var rail_st := SurfaceTool.new()
	rail_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var post_transforms: Array[Transform3D] = []
	var refl_transforms: Array[Transform3D] = []

	for path_arr: Array in scenic_rail_paths:
		var pts: Array[Vector3] = path_arr[0]
		var half_w: float = float(path_arr[1])
		var r_name: String = str(path_arr[2]) if path_arr.size() > 2 else ""
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
				if fwd0.dot(fwd1) < 0.80:
					continue

				var r0: Vector3 = p0 + right0 * rail_offset
				var r1: Vector3 = p1 + right1 * rail_offset
				var mid_r: Vector3 = r0.lerp(r1, 0.5)
				if not is_point_clear_of_roads(mid_r.x, mid_r.z, 2.5, r_name):
					continue
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

func _generate_ribbon_mesh(points: Array[Vector3], road_width: float, is_closed: bool, road_name: String, elev_offset: float = 0.20, surface_mode: int = 0, surface_meta: String = "asphalt_dry") -> MeshInstance3D:
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
		all_road_segments.append({"p0": curr_p, "p1": next_p, "half_w": half_w, "offset": elev_offset, "road": road_name, "surface": surface_meta})
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
		s_mat.set_shader_parameter("road_surface_mode", surface_mode)
		inst.material_override = s_mat
	else:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.18, 0.18, 0.20)
		mat.roughness = 0.55
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		inst.material_override = mat

	var body := StaticBody3D.new()
	body.set_meta("surface", surface_meta)
	var col := CollisionShape3D.new()
	col.shape = mesh.create_trimesh_shape()
	body.add_child(col)
	inst.add_child(body)
	return inst

func _subdivide_polyline_max_len(raw_pts: Array, is_closed: bool, elev_offset: float, max_seg_m: float) -> Array[Vector3]:
	var n: int = raw_pts.size()
	var out: Array[Vector3] = []
	var seg_count: int = n if is_closed else n - 1
	for i: int in range(seg_count):
		var p1a: Array = raw_pts[i]
		var p2a: Array = raw_pts[(i + 1) % n]
		var p0a: Array = raw_pts[(i - 1 + n) % n] if is_closed else raw_pts[maxi(0, i - 1)]
		var p3a: Array = raw_pts[(i + 2) % n] if is_closed else raw_pts[mini(n - 1, i + 2)]
		var v1 := Vector3(float(p1a[0]), 0.0, float(p1a[1]))
		var v2 := Vector3(float(p2a[0]), 0.0, float(p2a[1]))
		var v0 := Vector3(float(p0a[0]), 0.0, float(p0a[1]))
		var v3 := Vector3(float(p3a[0]), 0.0, float(p3a[1]))
		var d: float = v1.distance_to(v2)
		var subs: int = clampi(int(ceilf(d / maxf(max_seg_m, 4.0))), 1, 16)
		for s: int in range(subs):
			var t: float = float(s) / float(subs)
			var ip: Vector3 = _catmull_rom(v0, v1, v2, v3, t)
			ip.y = terrain_gen.get_height(ip.x, ip.z) + elev_offset
			out.append(ip)
	if not is_closed and n > 0:
		var pn: Array = raw_pts[n - 1]
		var px: float = float(pn[0])
		var pz: float = float(pn[1])
		out.append(Vector3(px, terrain_gen.get_height(px, pz) + elev_offset, pz))
	return out

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
