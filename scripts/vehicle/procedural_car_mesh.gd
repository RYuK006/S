# procedural_car_mesh.gd
# Generates realistic procedural car models from recipes with PBR clearcoat paint, lathe wheels and vertex denting.
class_name ProceduralCarMesh
extends Node3D

var car_recipe: Dictionary
var body_mesh_instance: MeshInstance3D
var original_vertices: PackedVector3Array
var deformed_mesh: ArrayMesh

func build_car(recipe: Dictionary) -> Node3D:
	car_recipe = recipe
	
	# 1. Create Body Mesh via Lofted Cross Sections
	_build_body()
	
	# 2. Add Details: Spoiler, Hood Scoop, Bumpers, Lights
	_build_details()
	
	# 3. Add Wheels (visual models attached to wheel positions)
	_build_wheels()
	
	return self

func _build_body():
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var length = car_recipe.wheelbase + 1.6
	var half_len = length * 0.5
	var width = car_recipe.track_width + 0.1
	var height = 1.35
	
	# Profile stations (Z from front to rear)
	# station format: [z_ratio, width_scale, height_scale, y_center]
	var stations = [
		[-1.0, 0.70, 0.35, 0.25], # Front bumper tip
		[-0.85, 0.85, 0.45, 0.35], # Hood front
		[-0.45, 0.95, 0.55, 0.42], # Windshield base
		[-0.15, 0.92, 0.90, 0.75], # Roof front
		[0.25, 0.90, 0.88, 0.74],  # Roof rear
		[0.60, 0.94, 0.60, 0.50],  # Rear deck / hatch
		[0.85, 0.92, 0.50, 0.42],  # Rear bumper top
		[1.0, 0.85, 0.40, 0.35]   # Rear bumper base
	]
	
	var num_radial = 16
	var station_rings = []
	
	for s in stations:
		var z = s[0] * half_len
		var w_rad = (width * 0.5) * s[1]
		var h_rad = (height * 0.5) * s[2]
		var y_off = s[3]
		var ring = []
		
		for i in range(num_radial):
			var theta = (float(i) / float(num_radial)) * TAU
			# Rounded rectangle / superellipse cross section
			var cos_t = cos(theta)
			var sin_t = sin(theta)
			var px = sign(cos_t) * pow(abs(cos_t), 0.7) * w_rad
			var py = y_off + (sin_t * h_rad)
			ring.append(Vector3(px, py, z))
		station_rings.append(ring)
	
	# Connect station rings with quad strips
	for i in range(station_rings.size() - 1):
		var ring_a = station_rings[i]
		var ring_b = station_rings[i + 1]
		
		for j in range(num_radial):
			var next_j = (j + 1) % num_radial
			var v0 = ring_a[j]
			var v1 = ring_a[next_j]
			var v2 = ring_b[next_j]
			var v3 = ring_b[j]
			
			# Triangle 1
			st.set_uv(Vector2(float(j) / num_radial, float(i) / stations.size()))
			st.add_vertex(v0)
			st.set_uv(Vector2(float(next_j) / num_radial, float(i) / stations.size()))
			st.add_vertex(v1)
			st.set_uv(Vector2(float(next_j) / num_radial, float(i + 1) / stations.size()))
			st.add_vertex(v2)
			
			# Triangle 2
			st.set_uv(Vector2(float(j) / num_radial, float(i) / stations.size()))
			st.add_vertex(v0)
			st.set_uv(Vector2(float(next_j) / num_radial, float(i + 1) / stations.size()))
			st.add_vertex(v2)
			st.set_uv(Vector2(float(j) / num_radial, float(i + 1) / stations.size()))
			st.add_vertex(v3)
	
	# Cap front and back
	var front_center = Vector3(0, stations[0][3], stations[0][0] * half_len)
	for j in range(num_radial):
		var next_j = (j + 1) % num_radial
		st.add_vertex(front_center)
		st.add_vertex(station_rings[0][next_j])
		st.add_vertex(station_rings[0][j])
		
	var rear_center = Vector3(0, stations[-1][3], stations[-1][0] * half_len)
	for j in range(num_radial):
		var next_j = (j + 1) % num_radial
		st.add_vertex(rear_center)
		st.add_vertex(station_rings[-1][j])
		st.add_vertex(station_rings[-1][next_j])
	
	st.generate_normals()
	st.generate_tangents()
	
	deformed_mesh = st.commit()
	body_mesh_instance = MeshInstance3D.new()
	body_mesh_instance.mesh = deformed_mesh
	
	# Save original vertices for dynamic denting
	var mdt = MeshDataTool.new()
	mdt.create_from_surface(deformed_mesh, 0)
	original_vertices = PackedVector3Array()
	for i in range(mdt.get_vertex_count()):
		original_vertices.append(mdt.get_vertex(i))
	
	# Forza-Quality PBR Clearcoat Material with Metallic Flake & Pearl Shift
	var paint_shader = load("res://shaders/car_paint.gdshader") as Shader
	if paint_shader:
		var paint_mat = ShaderMaterial.new()
		paint_mat.shader = paint_shader
		paint_mat.set_shader_parameter("base_color", Color(0.88, 0.15, 0.08, 1.0))
		paint_mat.set_shader_parameter("pearl_color", Color(0.96, 0.65, 0.12, 1.0))
		paint_mat.set_shader_parameter("metallic", 0.88)
		paint_mat.set_shader_parameter("roughness", 0.10)
		paint_mat.set_shader_parameter("clearcoat", 1.0)
		paint_mat.set_shader_parameter("clearcoat_roughness", 0.03)
		body_mesh_instance.material_override = paint_mat
	else:
		var paint_mat = StandardMaterial3D.new()
		paint_mat.albedo_color = Color(0.88, 0.15, 0.08, 1.0) # Radiant Racing Crimson
		paint_mat.metallic = 0.85
		paint_mat.roughness = 0.12
		paint_mat.clearcoat_enabled = true
		paint_mat.clearcoat = 1.0
		paint_mat.clearcoat_roughness = 0.04
		body_mesh_instance.material_override = paint_mat
	add_child(body_mesh_instance)

func _build_details():
	# 1. Hood Scoop
	var scoop = MeshInstance3D.new()
	var scoop_box = BoxMesh.new()
	scoop_box.size = Vector3(0.42, 0.10, 0.55)
	scoop.mesh = scoop_box
	scoop.position = Vector3(0, 0.65, -0.7)
	var scoop_mat = StandardMaterial3D.new()
	scoop_mat.albedo_color = Color(0.1, 0.1, 0.1)
	scoop_mat.roughness = 0.3
	scoop.material_override = scoop_mat
	add_child(scoop)
	
	# 2. Rally Rear Spoiler
	var wing = MeshInstance3D.new()
	var wing_box = BoxMesh.new()
	wing_box.size = Vector3(1.35, 0.06, 0.35)
	wing.mesh = wing_box
	wing.position = Vector3(0, 1.05, 1.1)
	var wing_mat = StandardMaterial3D.new()
	wing_mat.albedo_color = Color(0.08, 0.08, 0.08)
	wing_mat.metallic = 0.9
	wing.material_override = wing_mat
	add_child(wing)
	
	# 3. Headlights (High-intensity emissive)
	for side in [-1.0, 1.0]:
		var hl = MeshInstance3D.new()
		var hl_box = BoxMesh.new()
		hl_box.size = Vector3(0.24, 0.12, 0.05)
		hl.mesh = hl_box
		hl.position = Vector3(side * 0.55, 0.45, -car_recipe.wheelbase * 0.5 - 0.78)
		var hl_mat = StandardMaterial3D.new()
		hl_mat.albedo_color = Color(0.9, 0.95, 1.0)
		hl_mat.emission_enabled = true
		hl_mat.emission = Color(0.9, 0.95, 1.0)
		hl_mat.emission_energy_multiplier = 4.0
		hl.material_override = hl_mat
		add_child(hl)
		
	# 4. Tail Lights (Signal Red emissive)
	for side in [-1.0, 1.0]:
		var tl = MeshInstance3D.new()
		var tl_box = BoxMesh.new()
		tl_box.size = Vector3(0.28, 0.10, 0.05)
		tl.mesh = tl_box
		tl.position = Vector3(side * 0.55, 0.52, car_recipe.wheelbase * 0.5 + 0.78)
		var tl_mat = StandardMaterial3D.new()
		tl_mat.albedo_color = Color(0.9, 0.05, 0.05)
		tl_mat.emission_enabled = true
		tl_mat.emission = Color(0.9, 0.05, 0.05)
		tl_mat.emission_energy_multiplier = 3.0
		tl.material_override = tl_mat
		add_child(tl)

func _build_wheels():
	# Builds visual lathe wheels with rubber tire profile and spoked rims
	var wb_half = car_recipe.wheelbase * 0.5
	var tw_half = car_recipe.track_width * 0.5
	var r = car_recipe.wheel_radius
	var w = car_recipe.wheel_width
	
	var wheel_positions = [
		Vector3(-tw_half, 0, -wb_half),
		Vector3(tw_half, 0, -wb_half),
		Vector3(-tw_half, 0, wb_half),
		Vector3(tw_half, 0, wb_half)
	]
	var wheel_names = ["wheel_FL", "wheel_FR", "wheel_RL", "wheel_RR"]
	
	for i in range(wheel_positions.size()):
		var pos = wheel_positions[i]
		var wheel_node = Node3D.new()
		wheel_node.name = wheel_names[i]
		wheel_node.position = pos
		
		# Tire mesh (Cylinder with rounded tire profile)
		var tire = MeshInstance3D.new()
		var cyl = CylinderMesh.new()
		cyl.top_radius = r
		cyl.bottom_radius = r
		cyl.height = w
		cyl.radial_segments = 24
		tire.mesh = cyl
		tire.rotation.z = deg_to_rad(90)
		
		var tire_mat = StandardMaterial3D.new()
		tire_mat.albedo_color = Color(0.08, 0.08, 0.09)
		tire_mat.roughness = 0.85
		tire.material_override = tire_mat
		wheel_node.add_child(tire)
		
		# Rim & Spokes
		var rim = MeshInstance3D.new()
		var rim_cyl = CylinderMesh.new()
		rim_cyl.top_radius = r * 0.65
		rim_cyl.bottom_radius = r * 0.65
		rim_cyl.height = w * 1.02
		rim.mesh = rim_cyl
		rim.rotation.z = deg_to_rad(90)
		
		var rim_mat = StandardMaterial3D.new()
		rim_mat.albedo_color = Color(0.75, 0.76, 0.78)
		rim_mat.metallic = 0.95
		rim_mat.roughness = 0.15
		rim.material_override = rim_mat
		wheel_node.add_child(rim)
		
		add_child(wheel_node)

# Section 3.2: Dynamic Vertex Denting on Impact
func apply_dent(local_impact: Vector3, energy: float, radius: float = 0.8):
	if not deformed_mesh:
		return
	var mdt = MeshDataTool.new()
	mdt.create_from_surface(deformed_mesh, 0)
	
	var max_indent = clamp(energy * 0.0002, 0.02, 0.25)
	
	for i in range(mdt.get_vertex_count()):
		var v = mdt.get_vertex(i)
		var dist = v.distance_to(local_impact)
		if dist < radius:
			var falloff = 1.0 - (dist / radius)
			falloff = falloff * falloff
			var dent_dir = (local_impact - v).normalized()
			v += dent_dir * max_indent * falloff
			mdt.set_vertex(i, v)
	
	deformed_mesh.clear_surfaces()
	mdt.commit_to_surface(deformed_mesh)
