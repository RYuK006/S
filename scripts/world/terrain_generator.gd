# scripts/world/terrain_generator.gd
class_name TerrainGenerator
extends RefCounted

const OpenWorldConfig = preload("res://scripts/world/open_world_config.gd")

var macro_noise: FastNoiseLite
var mountain_noise: FastNoiseLite
var detail_noise: FastNoiseLite
var terrain_material: Material

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
	
	_setup_terrain_material()

func _setup_terrain_material() -> void:
	var t_shader := load("res://shaders/terrain.gdshader") as Shader
	if t_shader:
		var s_mat := ShaderMaterial.new()
		s_mat.shader = t_shader
		
		# Load and assign 1K PBR Texture sets
		var tex_grass_d := load("res://assets/textures/grass_diff.jpg") as Texture2D
		var tex_grass_n := load("res://assets/textures/grass_nor.jpg") as Texture2D
		var tex_grass_r := load("res://assets/textures/grass_rough.jpg") as Texture2D
		if tex_grass_d: s_mat.set_shader_parameter("tex_grass_diff", tex_grass_d)
		if tex_grass_n: s_mat.set_shader_parameter("tex_grass_nor", tex_grass_n)
		if tex_grass_r: s_mat.set_shader_parameter("tex_grass_rough", tex_grass_r)
		
		var tex_sand_d := load("res://assets/textures/sand_diff.jpg") as Texture2D
		var tex_sand_n := load("res://assets/textures/sand_nor.jpg") as Texture2D
		var tex_sand_r := load("res://assets/textures/sand_rough.jpg") as Texture2D
		if tex_sand_d: s_mat.set_shader_parameter("tex_sand_diff", tex_sand_d)
		if tex_sand_n: s_mat.set_shader_parameter("tex_sand_nor", tex_sand_n)
		if tex_sand_r: s_mat.set_shader_parameter("tex_sand_rough", tex_sand_r)
		
		var tex_snow_d := load("res://assets/textures/snow_diff.jpg") as Texture2D
		var tex_snow_n := load("res://assets/textures/snow_nor.jpg") as Texture2D
		var tex_snow_r := load("res://assets/textures/snow_rough.jpg") as Texture2D
		if tex_snow_d: s_mat.set_shader_parameter("tex_snow_diff", tex_snow_d)
		if tex_snow_n: s_mat.set_shader_parameter("tex_snow_nor", tex_snow_n)
		if tex_snow_r: s_mat.set_shader_parameter("tex_snow_rough", tex_snow_r)
		
		var tex_volcano_d := load("res://assets/textures/volcano_diff.jpg") as Texture2D
		var tex_volcano_n := load("res://assets/textures/volcano_nor.jpg") as Texture2D
		var tex_volcano_r := load("res://assets/textures/volcano_rough.jpg") as Texture2D
		if tex_volcano_d: s_mat.set_shader_parameter("tex_volcano_diff", tex_volcano_d)
		if tex_volcano_n: s_mat.set_shader_parameter("tex_volcano_nor", tex_volcano_n)
		if tex_volcano_r: s_mat.set_shader_parameter("tex_volcano_rough", tex_volcano_r)
		
		var tex_cliff_d := load("res://assets/textures/cliff_diff.jpg") as Texture2D
		var tex_cliff_n := load("res://assets/textures/cliff_nor.jpg") as Texture2D
		var tex_cliff_r := load("res://assets/textures/cliff_rough.jpg") as Texture2D
		if tex_cliff_d: s_mat.set_shader_parameter("tex_cliff_diff", tex_cliff_d)
		if tex_cliff_n: s_mat.set_shader_parameter("tex_cliff_nor", tex_cliff_n)
		if tex_cliff_r: s_mat.set_shader_parameter("tex_cliff_rough", tex_cliff_r)
		
		terrain_material = s_mat
	else:
		var std_mat := StandardMaterial3D.new()
		std_mat.vertex_color_use_as_albedo = true
		std_mat.roughness = 0.88
		std_mat.metallic = 0.04
		terrain_material = std_mat

func get_height(x: float, z: float) -> float:
	var dist: float = Vector2(x, z).length()
	
	# Smooth quadrant weights using linear blend around x=0 and z=0
	var blend_w: float = 200.0 # blend zone width
	var weight_east: float = clamp((x + blend_w) / (2.0 * blend_w), 0.0, 1.0)
	var weight_south: float = clamp((z + blend_w) / (2.0 * blend_w), 0.0, 1.0)
	
	# Multi-octave noises
	var n_macro: float = macro_noise.get_noise_2d(x, z)
	var n_mount: float = mountain_noise.get_noise_2d(x, z)
	var ridge: float = pow(1.0 - abs(n_mount), 2.0)
	
	# Biome regional heights:
	# NW: Frozen Pass (Alpine peaks & jagged mountain summits)
	var h_nw: float = 70.0 + (n_macro * 50.0) + (ridge * 65.0)
	
	# NE: Volcano Ridge (Volcanic caldera cone & crater)
	# Center of volcano caldera cone around (1000, -1000)
	var dist_volcano: float = Vector2(x - 1000.0, z + 1000.0).length()
	var volcano_cone: float = clamp(1.0 - (dist_volcano / 700.0), 0.0, 1.0)
	var volcano_crater: float = clamp(1.0 - (dist_volcano / 160.0), 0.0, 1.0)
	var h_ne: float = 55.0 + (n_macro * 40.0) + (volcano_cone * 75.0) - (volcano_crater * 38.0) + (ridge * 35.0)
	
	# SW: Dust Bowl (Rolling desert dunes & canyon washes)
	var h_sw: float = 18.0 + (n_macro * 20.0) + (n_mount * 10.0)
	
	# SE: Neon Coast (Low coastal basin & docklands, sloping to ocean shore)
	var h_se: float = 3.5 + (n_macro * 8.0) + (n_mount * 4.0)
	
	# Bilinear blend across all four quadrants
	var north_h: float = lerp(h_nw, h_ne, weight_east)
	var south_h: float = lerp(h_sw, h_se, weight_east)
	var regional_h: float = lerp(north_h, south_h, weight_south)
	
	# Festival Hub blend (smooth flat plateau at center for events and staging)
	var hub_h: float = 22.0 + (detail_noise.get_noise_2d(x, z) * 1.0)
	if dist < 450.0:
		var hub_factor: float = clamp((dist - 200.0) / 250.0, 0.0, 1.0)
		hub_factor = hub_factor * hub_factor * (3.0 - 2.0 * hub_factor)
		return max(1.5, lerp(hub_h, regional_h, hub_factor))
		
	return max(1.5, regional_h)

func get_normal(x: float, z: float, step: float = 1.0) -> Vector3:
	var hL := get_height(x - step, z)
	var hR := get_height(x + step, z)
	var hD := get_height(x, z - step)
	var hU := get_height(x, z + step)
	var normal := Vector3(hL - hR, 2.0 * step, hD - hU).normalized()
	return normal

func generate_chunk_mesh(chunk_x: int, chunk_z: int, resolution: int = 32) -> MeshInstance3D:
	var chunk_size := OpenWorldConfig.CHUNK_SIZE
	var origin_x := (chunk_x * chunk_size) - OpenWorldConfig.HALF_SIZE
	var origin_z := (chunk_z * chunk_size) - OpenWorldConfig.HALF_SIZE
	var step_size := chunk_size / float(resolution)
	
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	for gz in range(resolution):
		for gx in range(resolution):
			var x0 := origin_x + (gx * step_size)
			var z0 := origin_z + (gz * step_size)
			var x1 := x0 + step_size
			var z1 := z0 + step_size
			
			var y00 := get_height(x0, z0)
			var y10 := get_height(x1, z0)
			var y01 := get_height(x0, z1)
			var y11 := get_height(x1, z1)
			
			var p00 := Vector3(x0, y00, z0)
			var p10 := Vector3(x1, y10, z0)
			var p01 := Vector3(x0, y01, z1)
			var p11 := Vector3(x1, y11, z1)
			
			var c00 := _get_vertex_color(x0, y00, z0)
			var c10 := _get_vertex_color(x1, y10, z0)
			var c01 := _get_vertex_color(x0, y01, z1)
			var c11 := _get_vertex_color(x1, y11, z1)
			
			var uv00 := Vector2(x0 * 0.05, z0 * 0.05)
			var uv10 := Vector2(x1 * 0.05, z0 * 0.05)
			var uv01 := Vector2(x0 * 0.05, z1 * 0.05)
			var uv11 := Vector2(x1 * 0.05, z1 * 0.05)
			
			# Triangle 1
			st.set_color(c00); st.set_uv(uv00); st.add_vertex(p00)
			st.set_color(c10); st.set_uv(uv10); st.add_vertex(p10)
			st.set_color(c01); st.set_uv(uv01); st.add_vertex(p01)
			
			# Triangle 2
			st.set_color(c10); st.set_uv(uv10); st.add_vertex(p10)
			st.set_color(c11); st.set_uv(uv11); st.add_vertex(p11)
			st.set_color(c01); st.set_uv(uv01); st.add_vertex(p01)
			
	st.generate_normals()
	st.generate_tangents()
	
	var mesh := st.commit()
	var mesh_inst := MeshInstance3D.new()
	mesh_inst.mesh = mesh
	mesh_inst.name = "Chunk_%d_%d" % [chunk_x, chunk_z]
	mesh_inst.material_override = terrain_material
	
	# Add StaticBody3D collision shape for driving
	var static_body := StaticBody3D.new()
	var col_shape := CollisionShape3D.new()
	col_shape.shape = mesh.create_trimesh_shape()
	static_body.add_child(col_shape)
	mesh_inst.add_child(static_body)
	
	return mesh_inst

func _get_vertex_color(x: float, y: float, z: float) -> Color:
	var dist: float = Vector2(x, z).length()
	var blend_w: float = 200.0
	var weight_east: float = clamp((x + blend_w) / (2.0 * blend_w), 0.0, 1.0)
	var weight_south: float = clamp((z + blend_w) / (2.0 * blend_w), 0.0, 1.0)
	
	# 1. Base regional palette
	var c_nw := Color(0.92, 0.95, 1.0)   # Frozen Pass alpine snow
	var c_ne := Color(0.08, 0.08, 0.09)  # Volcano Ridge deep charred obsidian & ash
	var c_sw := Color(0.72, 0.44, 0.20)  # Dust Bowl warm terracotta / golden dunes
	var c_se := Color(0.14, 0.16, 0.18)  # Neon Coast dark harbor tarmac
	
	var c_north := c_nw.lerp(c_ne, weight_east)
	var c_south := c_sw.lerp(c_se, weight_east)
	var base_color := c_north.lerp(c_south, weight_south)
	
	# 2. Subtle procedural ground grain variation
	var micro_noise: float = detail_noise.get_noise_2d(x * 1.5, z * 1.5) * 0.05
	base_color = Color(
		clamp(base_color.r + micro_noise, 0.0, 1.0),
		clamp(base_color.g + (micro_noise * 0.8), 0.0, 1.0),
		clamp(base_color.b + (micro_noise * 0.6), 0.0, 1.0)
	)
	
	# 3. Slope-based rock cliffs
	var norm := get_normal(x, z)
	var slope: float = 1.0 - norm.y # 0 = flat ground, 1 = vertical cliff
	
	# Regional cliff rock colors
	var rock_nw := Color(0.32, 0.34, 0.38) # Dark granite cliff
	var rock_ne := Color(0.05, 0.05, 0.06) # Dark chiseled basalt
	var rock_sw := Color(0.52, 0.28, 0.14) # Red canyon sandstone
	var rock_se := Color(0.10, 0.12, 0.14) # Breakwater stone
	var reg_rock := rock_nw.lerp(rock_ne, weight_east).lerp(rock_sw.lerp(rock_se, weight_east), weight_south)
	
	var color: Color = base_color.lerp(reg_rock, clamp(slope * 2.2, 0.0, 1.0))
	
	# 4. Volcano Ridge: Magma veins & Caldera glow (ONLY in NE quadrant, x > 0 and z < 0)
	if x > 150.0 and z < -150.0:
		var dist_caldera: float = Vector2(x - 1000.0, z + 1000.0).length()
		# Caldera floor has glowing molten magma lake at the volcano crater
		if dist_caldera < 180.0:
			var lake_intensity: float = clamp(1.0 - (dist_caldera / 180.0), 0.0, 1.0)
			color = color.lerp(Color(1.5, 0.45, 0.05), lake_intensity * 0.98)
		else:
			# Fine glowing lava fissures running through the dark obsidian rock
			var fissure_noise: float = abs(detail_noise.get_noise_2d(x * 3.5, z * 3.5))
			if y > 60.0 and fissure_noise < 0.022:
				var fissure_t: float = 1.0 - (fissure_noise / 0.022)
				color = color.lerp(Color(1.4, 0.38, 0.04), fissure_t * 0.92)
	
	# 5. Frozen Pass: Alpine Snow Caps (ONLY in NW quadrant, x < 0 and z < 0)
	if x < -100.0 and z < -100.0:
		if y > 75.0 and slope < 0.45:
			var snow_factor: float = clamp((y - 75.0) / 30.0, 0.0, 1.0)
			color = color.lerp(Color(0.96, 0.98, 1.0), snow_factor)
			
	# 6. Festival Hub blending (Central arena)
	if dist < 450.0:
		var hub_c := Color(0.22, 0.23, 0.26)
		var hub_factor: float = clamp((dist - 200.0) / 250.0, 0.0, 1.0)
		hub_factor = hub_factor * hub_factor * (3.0 - 2.0 * hub_factor)
		color = hub_c.lerp(color, hub_factor)
		
	return color

