# tools/inspect_porsche_nodes.gd
extends SceneTree

func _init() -> void:
	var gltf := GLTFDocument.new()
	var state := GLTFState.new()
	var err := gltf.append_from_file("res://assets/models/cars/porsche_911_turbo.glb", state)
	if err == OK:
		var scene := gltf.generate_scene(state)
		_print_nodes(scene, 0)
	quit(0)

func _print_nodes(n: Node, depth: int) -> void:
	var indent = ""
	for i in range(depth): indent += "  "
	print(indent, n.name, " (", n.get_class(), ")")
	if depth < 3:
		for c in n.get_children():
			_print_nodes(c, depth + 1)
