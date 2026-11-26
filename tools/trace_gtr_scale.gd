# tools/trace_gtr_scale.gd
extends SceneTree

func _init() -> void:
	var gltf := GLTFDocument.new()
	var state := GLTFState.new()
	var err := gltf.append_from_file("res://assets/models/cars/nissan_gtr_r35.glb", state)
	if err == OK:
		var scene := gltf.generate_scene(state)
		var obj = _find(scene, "Object_53")
		var curr = obj
		while curr:
			print("Node: ", curr.name, " scale: ", curr.scale, " rot: ", curr.rotation, " pos: ", curr.position)
			curr = curr.get_parent()
	quit(0)

func _find(n: Node, name: String) -> Node:
	if n.name == name: return n
	for c in n.get_children():
		var r = _find(c, name)
		if r: return r
	return null
