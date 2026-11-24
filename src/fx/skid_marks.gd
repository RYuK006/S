# skid_marks.gd
# Dynamic ring-buffered skid marks following slipping wheels.
class_name SkidMarks
extends Node3D

const MAX_MARKS = 256
var mesh_instance: MeshInstance3D
var immediate_mesh: ImmediateMesh
var active_points: Array[Dictionary] = [] # [{ l_pos, r_pos, alpha }]

func _ready():
	immediate_mesh = ImmediateMesh.new()
	mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = immediate_mesh
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.04, 0.04, 0.04, 0.85)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh_instance.material_override = mat
	add_child(mesh_instance)

func add_mark(pos: Vector3, normal: Vector3, right: Vector3, width: float, intensity: float):
	var half_w = right * (width * 0.5)
	var ground_offset = normal * 0.03 # Float slightly above road to prevent z-fighting
	var p_left = pos - half_w + ground_offset
	var p_right = pos + half_w + ground_offset
	
	active_points.append({
		"left": p_left,
		"right": p_right,
		"alpha": clamp(intensity, 0.0, 0.85)
	})
	
	if active_points.size() > MAX_MARKS:
		active_points.pop_front()
		
	_rebuild_mesh()

func _rebuild_mesh():
	immediate_mesh.clear_surfaces()
	if active_points.size() < 2:
		return
		
	immediate_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(active_points.size() - 1):
		var pt0 = active_points[i]
		var pt1 = active_points[i + 1]
		
		# Quad 1
		immediate_mesh.surface_set_color(Color(1, 1, 1, pt0.alpha))
		immediate_mesh.surface_add_vertex(pt0.left)
		immediate_mesh.surface_set_color(Color(1, 1, 1, pt0.alpha))
		immediate_mesh.surface_add_vertex(pt0.right)
		immediate_mesh.surface_set_color(Color(1, 1, 1, pt1.alpha))
		immediate_mesh.surface_add_vertex(pt1.right)
		
		immediate_mesh.surface_set_color(Color(1, 1, 1, pt0.alpha))
		immediate_mesh.surface_add_vertex(pt0.left)
		immediate_mesh.surface_set_color(Color(1, 1, 1, pt1.alpha))
		immediate_mesh.surface_add_vertex(pt1.right)
		immediate_mesh.surface_set_color(Color(1, 1, 1, pt1.alpha))
		immediate_mesh.surface_add_vertex(pt1.left)
		
	immediate_mesh.surface_end()
