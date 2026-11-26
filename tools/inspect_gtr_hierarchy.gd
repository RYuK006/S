# tools/inspect_gtr_hierarchy.gd
extends SceneTree

func _init() -> void:
	var gltf := GLTFDocument.new()
	var state := GLTFState.new()
	var err := gltf.append_from_file("res://assets/models/cars/nissan_gtr_r35.glb", state)
	if err == OK:
		var scene := gltf.generate_scene(state)
		print("Scene root name: ", scene.name)
		print("Scene root children count: ", scene.get_child_count())
		for child in scene.get_children():
			_print_node(child, 1)
	quit(0)

func _print_node(n: Node, depth: int) -> void:
	var indent := ""
	for i in range(depth): indent += "  "
	print(indent, n.name, " (", n.get_class(), ", children: ", n.get_child_count(), ")")
	if depth < 3:
		for c in n.get_children():
			_print_node(c, depth + 1)
