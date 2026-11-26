# tools/measure_car_sizes.gd
extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var root_node := Node3D.new()
	get_root().add_child(root_node)
	
	var models = {
		"nissan_gtr": "res://assets/models/cars/nissan_gtr_r35.glb",
		"mclaren_p1": "res://assets/models/cars/mclaren_p1.glb",
		"porsche_911": "res://assets/models/cars/porsche_911_turbo.glb",
		"countach": "res://assets/models/cars/lamborghini_countach_lpi.glb",
		"mustang": "res://assets/models/cars/mustang_gt.glb",
		"aventador": "res://assets/models/cars/aventador.glb"
	}
	
	for key in models:
		var glb_path: String = models[key]
		var gltf := GLTFDocument.new()
		var state := GLTFState.new()
		var err := gltf.append_from_file(glb_path, state)
		if err == OK:
			var scene := gltf.generate_scene(state)
			root_node.add_child(scene)
			await process_frame
			
			var aabb: AABB = _calc_total_aabb(scene)
			print("Model: ", key)
			print("   Raw Scene AABB: Pos=", aabb.position, " Size=", aabb.size)
			print("   Length(Z): %.3fm, Width(X): %.3fm, Height(Y): %.3fm" % [aabb.size.z, aabb.size.x, aabb.size.y])
			scene.queue_free()
			await process_frame
	quit(0)

func _calc_total_aabb(root: Node3D) -> AABB:
	var total_aabb := AABB()
	var first := true
	var meshes: Array[MeshInstance3D] = []
	_gather_meshes(root, meshes)
	for m in meshes:
		var m_aabb = m.get_aabb()
		var t = root.global_transform.affine_inverse() * m.global_transform
		var trans_aabb = t * m_aabb
		if first:
			total_aabb = trans_aabb
			first = false
		else:
			total_aabb = total_aabb.merge(trans_aabb)
	return total_aabb

func _gather_meshes(n: Node, list: Array[MeshInstance3D]) -> void:
	if n is MeshInstance3D:
		list.append(n)
	for c in n.get_children():
		_gather_meshes(c, list)
