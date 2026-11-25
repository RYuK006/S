# scripts/world/terrain_generator.gd
class_name TerrainGenerator
extends RefCounted

const OpenWorldConfig = preload("res://scripts/world/open_world_config.gd")

var macro_noise: FastNoiseLite
var mountain_noise: FastNoiseLite
var detail_noise: FastNoiseLite

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
	# NW: Frozen Pass (Alpine peaks)
	var h_nw: float = 70.0 + (n_macro * 50.0) + (ridge * 65.0)
	# NE: Volcano Ridge (Volcanic caldera & jagged obsidian ridges)
	var h_ne: float = 65.0 + (n_macro * 60.0) + (ridge * 70.0)
	# SW: Dust Bowl (Rolling desert dunes & canyon washes)
	var h_sw: float = 18.0 + (n_macro * 20.0) + (n_mount * 10.0)
	# SE: Neon Coast (Low coastal basin & docklands)
	var h_se: float = 4.0 + (n_macro * 10.0) + (n_mount * 5.0)
	
	# Bilinear blend across all four quadrants
	var north_h: float = lerp(h_nw, h_ne, weight_east)
	var south_h: float = lerp(h_sw, h_se, weight_east)
	var regional_h: float = lerp(north_h, south_h, weight_south)
	
	# Festival Hub blend (smooth flat plateau at center for events and staging)
	var hub_h: float = 22.0 + (detail_noise.get_noise_2d(x, z) * 1.0)
	if dist < 450.0:
		var hub_factor: float = clamp((dist - 200.0) / 250.0, 0.0, 1.0)
		# Smoothstep S-curve
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
	
	# PBR Terrain Material with vertex colors
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.85
	mat.metallic = 0.05
	mesh_inst.material_override = mat
	
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
	
	var c_nw := Color(0.85, 0.90, 0.96) # Snow
	var c_ne := Color(0.22, 0.12, 0.10) # Volcanic basalt
	var c_sw := Color(0.78, 0.58, 0.35) # Sand dunes
	var c_se := Color(0.18, 0.22, 0.26) # Coastal tarmac/docks
	
	var c_north := c_nw.lerp(c_ne, weight_east)
	var c_south := c_sw.lerp(c_se, weight_east)
	var base_color := c_north.lerp(c_south, weight_south)
	
	# Festival hub color blending
	if dist < 450.0:
		var hub_c := Color(0.30, 0.32, 0.36)
		var hub_factor: float = clamp((dist - 200.0) / 250.0, 0.0, 1.0)
		hub_factor = hub_factor * hub_factor * (3.0 - 2.0 * hub_factor)
		base_color = hub_c.lerp(base_color, hub_factor)
		
	var norm := get_normal(x, z)
	var slope: float = 1.0 - norm.y # 0 on flat, 1 on vertical
	var rock_color := Color(0.35, 0.32, 0.30)
	var color: Color = base_color.lerp(rock_color, clamp(slope * 2.2, 0.0, 1.0))
	
	if y > 105.0:
		var snow_factor: float = clamp((y - 105.0) / 25.0, 0.0, 1.0)
		color = color.lerp(Color(0.96, 0.98, 1.0), snow_factor)
		
	return color
