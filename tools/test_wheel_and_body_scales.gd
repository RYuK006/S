# tools/test_wheel_and_body_scales.gd
extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var root := Node3D.new()
	get_root().add_child(root)
	
	print("=== Testing GTR ===")
	_test_car("res://assets/models/cars/nissan_gtr_r35.glb", 100.0, ["3DWheel Front L_60"])
	
	print("=== Testing McLaren P1 ===")
	_test_car("res://assets/models/cars/mclaren_p1.glb", 0.82, ["WHEEL_LF"])
	
	print("=== Testing Porsche 911 ===")
	_test_car("res://assets/models/cars/porsche_911_turbo.glb", 0.688, ["wheel_fl", "Wheel_FL", "WheelFrontL"])
	
	quit(0)

func _test_car(glb_path: String, model_scale: float, wheel_names: Array[String]) -> void:
	var gltf := GLTFDocument.new()
	var state := GLTFState.new()
	var err := gltf.append_from_file(glb_path, state)
	if err != OK: return
	var scene := gltf.generate_scene(state)
	get_root().get_child(0).add_child(scene)
	scene.scale = Vector3(model_scale, model_scale, model_scale)
	await process_frame
	
	# Find wheel
	var w: Node3D = null
	for n in wheel_names:
		w = _find(scene, n)
		if w: break
	if w:
		var w_aabb := _calc_node_aabb(w)
		print("  Wheel: ", w.name, " Global AABB Size: ", w_aabb.size)
		print("  Wheel global scale: ", w.global_basis.get_scale())
	else:
		print("  Wheel not found among ", wheel_names)
		
	# Find body mesh
	var b_aabb := _calc_node_aabb(scene)
	print("  Total Car Model Global AABB Size: ", b_aabb.size)
	scene.queue_free()
	await process_frame

func _calc_node_aabb(root: Node3D) -> AABB:
	var total := AABB()
	var first := true
	var meshes: Array[MeshInstance3D] = []
	_gather(root, meshes)
	for m in meshes:
		var a = m.global_transform * m.get_aabb()
		if first:
			total = a
			first = false
		else:
			total = total.merge(a)
	return total

func _gather(n: Node, list: Array[MeshInstance3D]) -> void:
	if n is MeshInstance3D: list.append(n)
	for c in n.get_children(): _gather(c, list)

func _find(n: Node, name: String) -> Node3D:
	if n.name.nocasecmp_to(name) == 0 and n is Node3D: return n
	for c in n.get_children():
		var r = _find(c, name)
		if r: return r
	return null
