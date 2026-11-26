# tools/measure_mustang_wheels.gd
extends SceneTree

func _init() -> void:
	var gltf := GLTFDocument.new()
	var state := GLTFState.new()
	var err := gltf.append_from_file("res://assets/models/cars/mustang_gt.glb", state)
	if err == OK:
		var scene := gltf.generate_scene(state)
		for w_name in ["wheel0", "wheel1", "wheel2", "wheel3"]:
			var w = _find(scene, w_name)
			if w:
				print(w_name, " class: ", w.get_class(), " children: ", w.get_child_count())
				for c in w.get_children():
					if c is MeshInstance3D:
						print("   ", c.name, " mesh aabb: ", c.mesh.get_aabb(), " pos: ", c.position)
	quit(0)

func _find(n: Node, name: String) -> Node:
	if n.name.nocasecmp_to(name) == 0: return n
	for c in n.get_children():
		var r = _find(c, name)
		if r: return r
	return null
