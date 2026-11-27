# scripts/world/terrain_generator.gd
class_name TerrainGenerator
extends RefCounted

const OpenWorldConfig = preload("res://scripts/world/open_world_config.gd")

const DEM_MIN_H: float = -20.0
const DEM_MAX_H: float = 380.0
const ROAD_GRID_CELL: float = 128.0

var macro_noise: FastNoiseLite
var mountain_noise: FastNoiseLite
var detail_noise: FastNoiseLite
var terrain_material: Material
var road_segments: Array[Dictionary] = []
var road_spatial_grid: Dictionary = {}

var dem_size: int = 0
var dem_heights: PackedFloat32Array = PackedFloat32Array()
var dem_flow: PackedFloat32Array = PackedFloat32Array()
var dem_curv: PackedFloat32Array = PackedFloat32Array()

func _init(seed_val: int = 1337) -> void:
	macro_noise = FastNoiseLite.new()
	macro_noise.seed = seed_val
	macro_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	macro_noise.frequency = 0.0006
	macro_noise.fractal_octaves = 3

	mountain_noise = FastNoiseLite.new()
	mountain_noise.seed = seed_val + 42
	mountain_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	mountain_noise.frequency = 0.0018
	mountain_noise.fractal_octaves = 4

	detail_noise = FastNoiseLite.new()
	detail_noise.seed = seed_val + 99
	detail_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	detail_noise.frequency = 0.008
	detail_noise.fractal_octaves = 2

	_load_dem_heightmap()
	_setup_terrain_material()

func _load_dem_heightmap() -> void:
	var img: Image = null
	var dem_path: String = "res://assets/textures/world_dem_height.png"
	if FileAccess.file_exists(dem_path):
		var tex: Texture2D = ResourceLoader.load(dem_path) as Texture2D
		if tex:
			img = tex.get_image()
		if not img:
			img = Image.load_from_file(ProjectSettings.globalize_path(dem_path))
	if not img or img.is_empty():
		return
	if img.is_compressed():
		img.decompress()
	dem_size = img.get_width()
	if dem_size < 16 or img.get_height() != dem_size:
		dem_size = 0
		return
	var total: int = dem_size * dem_size
	dem_heights.resize(total)
	dem_flow.resize(total)
	dem_curv.resize(total)
	var span: float = DEM_MAX_H - DEM_MIN_H
	for py: int in range(dem_size):
		for px: int in range(dem_size):
			var c: Color = img.get_pixel(px, py)
			var h16: float = float(c.r8 * 256 + c.g8) / 65535.0
			var idx: int = py * dem_size + px
			dem_heights[idx] = DEM_MIN_H + h16 * span
			dem_flow[idx] = c.b
			dem_curv[idx] = c.a

func set_road_segments(segs: Array[Dictionary]) -> void:
	road_segments = segs
	road_spatial_grid.clear()
	for idx: int in range(segs.size()):
		var seg: Dictionary = segs[idx]
		var p0: Vector3 = seg["p0"]
		var p1: Vector3 = seg["p1"]
		var min_cx: int = int(floorf((minf(p0.x, p1.x) - 48.0) / ROAD_GRID_CELL))
		var max_cx: int = int(floorf((maxf(p0.x, p1.x) + 48.0) / ROAD_GRID_CELL))
		var min_cz: int = int(floorf((minf(p0.z, p1.z) - 48.0) / ROAD_GRID_CELL))
		var max_cz: int = int(floorf((maxf(p0.z, p1.z) + 48.0) / ROAD_GRID_CELL))
		for cz: int in range(min_cz, max_cz + 1):
			for cx: int in range(min_cx, max_cx + 1):
				var k := Vector2i(cx, cz)
				if not road_spatial_grid.has(k):
					var bucket: Array[int] = []
					road_spatial_grid[k] = bucket
				(road_spatial_grid[k] as Array[int]).append(idx)

func _setup_terrain_material() -> void:
	var t_shader := load("res://shaders/terrain.gdshader") as Shader
	if t_shader:
		var s_mat := ShaderMaterial.new()
		s_mat.shader = t_shader
		var maps: Array[String] = ["grass", "sand", "snow", "volcano", "cliff", "gravel"]
		for mname: String in maps:
			var td := load("res://assets/textures/%s_diff.jpg" % mname) as Texture2D
			var tn := load("res://assets/textures/%s_nor.jpg" % mname) as Texture2D
			var tr := load("res://assets/textures/%s_rough.jpg" % mname) as Texture2D
			if td: s_mat.set_shader_parameter("tex_%s_diff" % mname, td)
			if tn: s_mat.set_shader_parameter("tex_%s_nor" % mname, tn)
			if tr: s_mat.set_shader_parameter("tex_%s_rough" % mname, tr)
		terrain_material = s_mat
	else:
		var std_mat := StandardMaterial3D.new()
		std_mat.vertex_color_use_as_albedo = true
		std_mat.roughness = 0.88
		std_mat.metallic = 0.04
		terrain_material = std_mat

func _sample_dem_height(x: float, z: float) -> float:
	var half: float = OpenWorldConfig.HALF_SIZE
	var u: float = clampf((x + half) / (half * 2.0), 0.0, 1.0) * float(dem_size - 1)
	var v: float = clampf((z + half) / (half * 2.0), 0.0, 1.0) * float(dem_size - 1)
	var x0: int = clampi(int(floorf(u)), 0, dem_size - 2)
	var y0: int = clampi(int(floorf(v)), 0, dem_size - 2)
	var fx: float = u - float(x0)
	var fy: float = v - float(y0)
	var i00: int = y0 * dem_size + x0
	var i10: int = i00 + 1
	var i01: int = i00 + dem_size
	var i11: int = i01 + 1
	var h0: float = lerpf(dem_heights[i00], dem_heights[i10], fx)
	var h1: float = lerpf(dem_heights[i01], dem_heights[i11], fx)
	return lerpf(h0, h1, fy)

func _sample_dem_flow(x: float, z: float) -> float:
	if dem_size <= 0:
		return 0.0
	var half: float = OpenWorldConfig.HALF_SIZE
	var px: int = clampi(int(roundf(clampf((x + half) / (half * 2.0), 0.0, 1.0) * float(dem_size - 1))), 0, dem_size - 1)
	var py: int = clampi(int(roundf(clampf((z + half) / (half * 2.0), 0.0, 1.0) * float(dem_size - 1))), 0, dem_size - 1)
	return dem_flow[py * dem_size + px]

func get_height(x: float, z: float) -> float:
	if dem_size > 0:
		var dem_h: float = _sample_dem_height(x, z)
		var dist: float = Vector2(x, z).length()
		if dist > 160.0:
			var micro: float = detail_noise.get_noise_2d(x * 1.4, z * 1.4) * 0.45
			var hub_fade: float = clampf((dist - 160.0) / 220.0, 0.0, 1.0)
			dem_h += micro * hub_fade
		return dem_h

	var dist_fb: float = Vector2(x, z).length()
	var blend_w: float = 200.0
	var weight_east: float = clampf((x + blend_w) / (2.0 * blend_w), 0.0, 1.0)
	var weight_south: float = clampf((z + blend_w) / (2.0 * blend_w), 0.0, 1.0)
	var n_macro: float = macro_noise.get_noise_2d(x, z)
	var n_mount: float = mountain_noise.get_noise_2d(x, z)
	var ridge: float = pow(1.0 - absf(n_mount), 2.0)
	var h_nw: float = 70.0 + (n_macro * 50.0) + (ridge * 65.0)
	var dist_volcano: float = Vector2(x - 1000.0, z + 1000.0).length()
	var volcano_cone: float = clampf(1.0 - (dist_volcano / 700.0), 0.0, 1.0)
	var volcano_crater: float = clampf(1.0 - (dist_volcano / 160.0), 0.0, 1.0)
	var h_ne: float = 55.0 + (n_macro * 40.0) + (volcano_cone * 75.0) - (volcano_crater * 38.0) + (ridge * 35.0)
	var mesa: float = clampf((absf(n_macro) - 0.15) * 2.8, 0.0, 1.0)
	var h_sw: float = 18.0 + (n_macro * 22.0) + (n_mount * 12.0) + (mesa * 16.0)
	var coast_curve_x: float = 2160.0 - 0.00014 * (z - 200.0) * (z - 200.0)
	var shore_x: float = coast_curve_x + 48.0 + sin(z * 0.004) * 18.0
	var bay_drop: float = clampf((x - shore_x) / 145.0, 0.0, 1.0)
	var h_se: float = lerpf(6.8 + (n_macro * 4.5) + (n_mount * 2.0), -2.8, bay_drop)
	var regional_h: float = lerpf(lerpf(h_nw, h_ne, weight_east), lerpf(h_sw, h_se, weight_east), weight_south)
	if dist_fb < 450.0:
		var hf: float = clampf((dist_fb - 140.0) / 310.0, 0.0, 1.0)
		hf = hf * hf * (3.0 - 2.0 * hf)
		return maxf(-3.0, lerpf(22.0, regional_h, hf))
	return maxf(-3.0, regional_h)

func _eval_road_carve(x: float, z: float, base_h: float) -> Vector2:
	# Returns Vector2(carved_height, road_verge_weight)
	if road_spatial_grid.is_empty():
		return Vector2(base_h, 0.0)
	var k := Vector2i(int(floorf(x / ROAD_GRID_CELL)), int(floorf(z / ROAD_GRID_CELL)))
	if not road_spatial_grid.has(k):
		return Vector2(base_h, 0.0)
	var p2 := Vector2(x, z)
	var best_w: float = 0.0
	var best_verge: float = 0.0
	var best_inner_d: float = 1e9
	var best_inner_y: float = base_h
	var bed_w_sum: float = 0.0
	var bed_h_sum: float = 0.0
	var carved_y: float = base_h
	var indices: Array[int] = road_spatial_grid[k]
	for idx: int in indices:
		var seg: Dictionary = road_segments[idx]
		var a3: Vector3 = seg["p0"]
		var b3: Vector3 = seg["p1"]
		var a := Vector2(a3.x, a3.z)
		var b := Vector2(b3.x, b3.z)
		var ab: Vector2 = b - a
		var len_sq: float = ab.length_squared()
		var t: float = clampf((p2 - a).dot(ab) / len_sq, 0.0, 1.0) if len_sq > 0.0001 else 0.0
		var d: float = p2.distance_to(a + ab * t)
		var rw: float = float(seg["half_w"])
		var inner_r: float = rw + 5.0
		var outer_r: float = rw + 14.0
		var road_bed: float = lerpf(a3.y, b3.y, t) - 0.56
		if d <= inner_r:
			best_w = 1.0
			if d < best_inner_d:
				best_inner_d = d
				best_inner_y = road_bed
		elif d < outer_r:
			var w: float = 1.0 - clampf((d - inner_r) / (outer_r - inner_r), 0.0, 1.0)
			w = w * w * (3.0 - 2.0 * w)
			if w > 0.01:
				best_w = maxf(best_w, w)
				bed_w_sum += w
				bed_h_sum += road_bed * w
		var verge_outer: float = rw + 10.5
		if d < verge_outer:
			var vw: float = 1.0 - clampf((d - (rw + 0.5)) / (verge_outer - (rw + 0.5)), 0.0, 1.0)
			best_verge = maxf(best_verge, vw * vw * (3.0 - 2.0 * vw))
	if best_inner_d < 1e8:
		return Vector2(best_inner_y, best_verge)
	if bed_w_sum > 0.001:
		carved_y = bed_h_sum / bed_w_sum
		var blended_y: float = lerpf(base_h, carved_y, best_w)
		return Vector2(blended_y, best_verge)
	return Vector2(base_h, best_verge)

func get_mesh_height(x: float, z: float) -> float:
	var h: float = get_height(x, z)
	return _eval_road_carve(x, z, h).x

func get_normal(x: float, z: float, step: float = 1.0) -> Vector3:
	var hL: float = get_height(x - step, z)
	var hR: float = get_height(x + step, z)
	var hD: float = get_height(x, z - step)
	var hU: float = get_height(x, z + step)
	return Vector3(hL - hR, 2.0 * step, hD - hU).normalized()

func generate_chunk_mesh(chunk_x: int, chunk_z: int, resolution: int = 56, build_collider: bool = true) -> MeshInstance3D:
	var chunk_size: float = OpenWorldConfig.CHUNK_SIZE
	var origin_x: float = (float(chunk_x) * chunk_size) - OpenWorldConfig.HALF_SIZE
	var origin_z: float = (float(chunk_z) * chunk_size) - OpenWorldConfig.HALF_SIZE
	var step_size: float = chunk_size / float(resolution)

	var verts_count: int = resolution + 1
	var grid_pos := PackedVector3Array()
	var grid_col := PackedColorArray()
	var grid_norm := PackedVector3Array()
	var grid_uv2 := PackedVector2Array()
	grid_pos.resize(verts_count * verts_count)
	grid_col.resize(verts_count * verts_count)
	grid_norm.resize(verts_count * verts_count)
	grid_uv2.resize(verts_count * verts_count)

	for gz: int in range(verts_count):
		for gx: int in range(verts_count):
			var idx: int = gz * verts_count + gx
			var vx: float = origin_x + (float(gx) * step_size)
			var vz: float = origin_z + (float(gz) * step_size)
			var base_y: float = get_height(vx, vz)
			var carve: Vector2 = _eval_road_carve(vx, vz, base_y)
			var vy: float = carve.x
			grid_pos[idx] = Vector3(vx, vy, vz)
			grid_col[idx] = _get_vertex_color(vx, vy, vz)
			grid_uv2[idx] = Vector2(_sample_dem_flow(vx, vz), carve.y)

			var hl: float = get_mesh_height(vx - 3.5, vz)
			var hr: float = get_mesh_height(vx + 3.5, vz)
			var hd: float = get_mesh_height(vx, vz - 3.5)
			var hu: float = get_mesh_height(vx, vz + 3.5)
			grid_norm[idx] = Vector3(hl - hr, 7.0, hd - hu).normalized()

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for gz: int in range(resolution):
		for gx: int in range(resolution):
			var i00: int = gz * verts_count + gx
			var i10: int = i00 + 1
			var i01: int = (gz + 1) * verts_count + gx
			var i11: int = i01 + 1

			var p00: Vector3 = grid_pos[i00]
			var p10: Vector3 = grid_pos[i10]
			var p01: Vector3 = grid_pos[i01]
			var p11: Vector3 = grid_pos[i11]

			var uv00 := Vector2(p00.x * 0.05, p00.z * 0.05)
			var uv10 := Vector2(p10.x * 0.05, p10.z * 0.05)
			var uv01 := Vector2(p01.x * 0.05, p01.z * 0.05)
			var uv11 := Vector2(p11.x * 0.05, p11.z * 0.05)

			st.set_normal(grid_norm[i00]); st.set_color(grid_col[i00]); st.set_uv(uv00); st.set_uv2(grid_uv2[i00]); st.add_vertex(p00)
			st.set_normal(grid_norm[i10]); st.set_color(grid_col[i10]); st.set_uv(uv10); st.set_uv2(grid_uv2[i10]); st.add_vertex(p10)
			st.set_normal(grid_norm[i01]); st.set_color(grid_col[i01]); st.set_uv(uv01); st.set_uv2(grid_uv2[i01]); st.add_vertex(p01)

			st.set_normal(grid_norm[i10]); st.set_color(grid_col[i10]); st.set_uv(uv10); st.set_uv2(grid_uv2[i10]); st.add_vertex(p10)
			st.set_normal(grid_norm[i11]); st.set_color(grid_col[i11]); st.set_uv(uv11); st.set_uv2(grid_uv2[i11]); st.add_vertex(p11)
			st.set_normal(grid_norm[i01]); st.set_color(grid_col[i01]); st.set_uv(uv01); st.set_uv2(grid_uv2[i01]); st.add_vertex(p01)

	st.index()
	st.generate_tangents()

	var mesh := st.commit()
	var mesh_inst := MeshInstance3D.new()
	mesh_inst.mesh = mesh
	mesh_inst.name = "Chunk_%d_%d" % [chunk_x, chunk_z]
	mesh_inst.material_override = terrain_material
	mesh_inst.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	if not build_collider:
		mesh_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	if build_collider:
		var static_body := StaticBody3D.new()
		var col_shape := CollisionShape3D.new()
		col_shape.shape = mesh.create_trimesh_shape()
		static_body.add_child(col_shape)
		mesh_inst.add_child(static_body)

	return mesh_inst

func _get_vertex_color(x: float, _y: float, z: float) -> Color:
	# Smoothly encode caldera magma weight ONLY inside the active volcanic crater basin (fragment shader carves crisp obsidian crust & cracks!)
	if x > 220.0 and z < -220.0:
		var dist_caldera: float = Vector2(x - 980.0, z + 1140.0).length()
		if dist_caldera < 225.0:
			var w: float = clampf(1.0 - (dist_caldera - 90.0) / 135.0, 0.0, 1.0)
			w = w * w * (3.0 - 2.0 * w)
			return Color(0.5 + 0.5 * w, 0.5 - 0.35 * w, 0.5 - 0.48 * w, 1.0)
	return Color(0.5, 0.5, 0.5, 1.0)
