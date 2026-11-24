# spline_track.gd
# Procedural 3D track builder: Catmull-Rom spline, swept road geometry, kerbs, barriers and checkpoint gates.
class_name SplineTrack
extends Node3D

const GameConstants = preload("res://src/core/constants.gd")

var control_points: PackedVector3Array = PackedVector3Array()
var track_points: Array[Dictionary] = [] # [{ pos, forward, right, up, width, banking, surface, dist }]
var total_length: float = 0.0
var checkpoints: Array[Area3D] = []

# Road mesh parameters
var road_width: float = 14.0
var shoulder_width: float = 2.0
var barrier_height: float = 1.0

func setup_circuit():
	# Define closed circuit control points for Dust Bowl 'Rust Gate Circuit'
	control_points = PackedVector3Array([
		Vector3(0, 0, 0),         # Start / Finish line
		Vector3(0, 0, -140),      # Main straight
		Vector3(40, 2.5, -240),   # Turn 1 fast right sweep
		Vector3(120, 4.0, -280),  # Hill crest
		Vector3(220, 2.0, -240),  # Turn 2 sweeping right
		Vector3(260, 0, -140),    # Back straight entry
		Vector3(250, 0, 40),      # Back straight
		Vector3(210, 1.5, 140),   # Turn 3 technical chicane entry
		Vector3(160, 1.0, 180),   # Chicane apex
		Vector3(90, 0, 160),      # Turn 4 hairpin exit
		Vector3(30, 0, 100),      # Approach to straight
		Vector3(0, 0, 30)         # Final corner onto straight
	])
	
	_sample_spline(180)
	_generate_road_mesh()
	_generate_checkpoints(18)

func _sample_spline(samples: int):
	track_points.clear()
	var n = control_points.size()
	total_length = 0.0
	
	var raw_points: PackedVector3Array = PackedVector3Array()
	for i in range(samples):
		var t_global = (float(i) / float(samples)) * float(n)
		var p_idx = int(t_global) % n
		var t_local = t_global - floor(t_global)
		
		var p0 = control_points[(p_idx - 1 + n) % n]
		var p1 = control_points[p_idx]
		var p2 = control_points[(p_idx + 1) % n]
		var p3 = control_points[(p_idx + 2) % n]
		
		var pos = _catmull_rom(p0, p1, p2, p3, t_local)
		raw_points.append(pos)
		
	# Compute orientations & distances
	for i in range(samples):
		var pos = raw_points[i]
		var next_pos = raw_points[(i + 1) % samples]
		var prev_pos = raw_points[(i - 1 + samples) % samples]
		
		var forward = (next_pos - prev_pos).normalized()
		var up = Vector3.UP
		var right = forward.cross(up).normalized()
		up = right.cross(forward).normalized()
		
		var step_dist = pos.distance_to(next_pos)
		total_length += step_dist
		
		track_points.append({
			"index": i,
			"pos": pos,
			"forward": forward,
			"right": right,
			"up": up,
			"width": road_width,
			"dist": total_length,
			"surface": "asphalt_dry"
		})

func _catmull_rom(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	var t2 = t * t
	var t3 = t2 * t
	return 0.5 * (
		(2.0 * p1) +
		(-p0 + p2) * t +
		(2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 +
		(-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3
	)

func _generate_road_mesh():
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var static_body = StaticBody3D.new()
	static_body.set_meta("surface", "asphalt_dry")
	add_child(static_body)
	
	var num_pts = track_points.size()
	for i in range(num_pts):
		var next_i = (i + 1) % num_pts
		var pt0 = track_points[i]
		var pt1 = track_points[next_i]
		
		var half_w = pt0.width * 0.5
		var l0 = pt0.pos - (pt0.right * half_w)
		var r0 = pt0.pos + (pt0.right * half_w)
		var l1 = pt1.pos - (pt1.right * half_w)
		var r1 = pt1.pos + (pt1.right * half_w)
		
		# Quad 1: Road Surface
		st.set_uv(Vector2(0, float(i) * 0.2))
		st.add_vertex(l0)
		st.set_uv(Vector2(1, float(i) * 0.2))
		st.add_vertex(r0)
		st.set_uv(Vector2(1, float(i + 1) * 0.2))
		st.add_vertex(r1)
		
		st.set_uv(Vector2(0, float(i) * 0.2))
		st.add_vertex(l0)
		st.set_uv(Vector2(1, float(i + 1) * 0.2))
		st.add_vertex(r1)
		st.set_uv(Vector2(0, float(i + 1) * 0.2))
		st.add_vertex(l1)
		
		# Curbs & Kerbs on track edges
		var curb_l0 = l0 - (pt0.right * shoulder_width) + Vector3(0, 0.12, 0)
		var curb_r0 = r0 + (pt0.right * shoulder_width) + Vector3(0, 0.12, 0)
		var curb_l1 = l1 - (pt1.right * shoulder_width) + Vector3(0, 0.12, 0)
		var curb_r1 = r1 + (pt1.right * shoulder_width) + Vector3(0, 0.12, 0)
		
		# Left Kerb
		st.set_uv(Vector2(0, float(i)))
		st.add_vertex(curb_l0); st.add_vertex(l0); st.add_vertex(l1)
		st.add_vertex(curb_l0); st.add_vertex(l1); st.add_vertex(curb_l1)
		
		# Right Kerb
		st.set_uv(Vector2(0, float(i)))
		st.add_vertex(r0); st.add_vertex(curb_r0); st.add_vertex(curb_r1)
		st.add_vertex(r0); st.add_vertex(curb_r1); st.add_vertex(r1)
		
	st.generate_normals()
	st.generate_tangents()
	
	var road_mesh = st.commit()
	var mesh_inst = MeshInstance3D.new()
	mesh_inst.mesh = road_mesh
	
	# PBR Asphalt & Kerb Material
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.20, 0.20, 0.22) # Dark worn asphalt
	mat.roughness = 0.65
	mat.metallic = 0.05
	mesh_inst.material_override = mat
	static_body.add_child(mesh_inst)
	
	# Trimesh collision
	var col = CollisionShape3D.new()
	col.shape = road_mesh.create_trimesh_shape()
	static_body.add_child(col)

func _generate_checkpoints(num_gates: int):
	checkpoints.clear()
	var step = track_points.size() / num_gates
	
	for g in range(num_gates):
		var pt = track_points[g * step]
		var gate = Area3D.new()
		gate.name = "Checkpoint_%d" % g
		gate.position = pt.pos + Vector3(0, 2.0, 0)
		
		var col = CollisionShape3D.new()
		var box = BoxShape3D.new()
		box.size = Vector3(road_width + 4.0, 6.0, 4.0)
		col.shape = box
		gate.add_child(col)
		
		# Set gate transform safely without requiring scene tree
		var gate_basis = Basis().looking_at(pt.forward, Vector3.UP)
		gate.transform = Transform3D(gate_basis, pt.pos + Vector3(0, 2.0, 0))
		gate.set_meta("gate_index", g)
		add_child(gate)
		checkpoints.append(gate)

func get_closest_track_point(pos: Vector3) -> Dictionary:
	var best_dist_sq = 1e9
	var best_pt = track_points[0]
	for pt in track_points:
		var d_sq = pt.pos.distance_squared_to(pos)
		if d_sq < best_dist_sq:
			best_dist_sq = d_sq
			best_pt = pt
	return best_pt
