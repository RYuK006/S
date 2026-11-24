# test_track.gd
# Procedural test track: high-speed circuit, skidpad circle, slalom cones, jump ramp and mixed-grip surfaces.
class_name TestTrack
extends Node3D

func _ready():
	_build_ground()
	_build_circuit()
	_build_skidpad()
	_build_jump_ramp()
	_build_slalom()

func _build_ground():
	# Large terrain plane
	var ground_body = StaticBody3D.new()
	ground_body.set_meta("surface", "dirt")
	
	var col = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(1000, 2, 1000)
	col.shape = box
	col.position = Vector3(0, -1, 0)
	ground_body.add_child(col)
	
	var ground_mesh = MeshInstance3D.new()
	var plane_mesh = PlaneMesh.new()
	plane_mesh.size = Vector2(1000, 1000)
	ground_mesh.mesh = plane_mesh
	
	var ground_mat = StandardMaterial3D.new()
	ground_mat.albedo_color = Color(0.42, 0.36, 0.28) # Warm desert dirt
	ground_mat.roughness = 0.95
	ground_mesh.material_override = ground_mat
	ground_body.add_child(ground_mesh)
	
	add_child(ground_body)

func _build_circuit():
	# Oval asphalt circuit track
	var road_body = StaticBody3D.new()
	road_body.set_meta("surface", "asphalt_dry")
	
	var road_mesh = MeshInstance3D.new()
	var plane = PlaneMesh.new()
	plane.size = Vector2(300, 16) # Main straight
	road_mesh.mesh = plane
	road_mesh.position = Vector3(0, 0.05, 0)
	
	var road_mat = StandardMaterial3D.new()
	road_mat.albedo_color = Color(0.18, 0.18, 0.20) # Forza dark asphalt
	road_mat.roughness = 0.68
	road_mesh.material_override = road_mat
	road_body.add_child(road_mesh)
	
	var col = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(300, 0.2, 16)
	col.shape = box
	col.position = Vector3(0, 0, 0)
	road_body.add_child(col)
	
	add_child(road_body)

func _build_skidpad():
	# Flat circle skidpad (radius 50m) for steady-state cornering and drift tests
	var skidpad_body = StaticBody3D.new()
	skidpad_body.set_meta("surface", "asphalt_dry")
	skidpad_body.position = Vector3(120, 0.06, 80)
	
	var cyl_mesh = CylinderMesh.new()
	cyl_mesh.top_radius = 50.0
	cyl_mesh.bottom_radius = 50.0
	cyl_mesh.height = 0.08
	
	var mesh_inst = MeshInstance3D.new()
	mesh_inst.mesh = cyl_mesh
	var pad_mat = StandardMaterial3D.new()
	pad_mat.albedo_color = Color(0.16, 0.16, 0.18)
	pad_mat.roughness = 0.70
	mesh_inst.material_override = pad_mat
	skidpad_body.add_child(mesh_inst)
	
	var col = CollisionShape3D.new()
	var cyl_shape = CylinderShape3D.new()
	cyl_shape.radius = 50.0
	cyl_shape.height = 0.1
	col.shape = cyl_shape
	skidpad_body.add_child(col)
	
	add_child(skidpad_body)

func _build_jump_ramp():
	# Stunt jump ramp for ballistic suspension tests
	var ramp_body = StaticBody3D.new()
	ramp_body.set_meta("surface", "concrete")
	ramp_body.position = Vector3(60, 0, 0)
	ramp_body.rotation.z = deg_to_rad(-8.5) # Incline ramp
	
	var col = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(18, 0.4, 12)
	col.shape = box
	col.position = Vector3(9, 0.2, 0)
	ramp_body.add_child(col)
	
	var ramp_mesh = MeshInstance3D.new()
	var box_m = BoxMesh.new()
	box_m.size = Vector3(18, 0.4, 12)
	ramp_mesh.mesh = box_m
	ramp_mesh.position = Vector3(9, 0.2, 0)
	
	var ramp_mat = StandardMaterial3D.new()
	ramp_mat.albedo_color = Color(0.85, 0.65, 0.12) # Yellow hazard warning ramp
	ramp_mat.roughness = 0.45
	ramp_mesh.material_override = ramp_mat
	ramp_body.add_child(ramp_mesh)
	
	add_child(ramp_body)

func _build_slalom():
	# Pylons / obstacles for slalom agility testing
	for i in range(8):
		var pylon = StaticBody3D.new()
		pylon.position = Vector3(-80 + (i * 22), 0.5, 0)
		
		var col = CollisionShape3D.new()
		var cyl_col = CylinderShape3D.new()
		cyl_col.radius = 0.35
		cyl_col.height = 1.0
		col.shape = cyl_col
		pylon.add_child(col)
		
		var mesh_inst = MeshInstance3D.new()
		var cyl_mesh = CylinderMesh.new()
		cyl_mesh.top_radius = 0.1
		cyl_mesh.bottom_radius = 0.35
		cyl_mesh.height = 1.0
		mesh_inst.mesh = cyl_mesh
		
		var pylon_mat = StandardMaterial3D.new()
		pylon_mat.albedo_color = Color(0.95, 0.35, 0.05) # Traffic orange
		mesh_inst.material_override = pylon_mat
		pylon.add_child(mesh_inst)
		
		add_child(pylon)
