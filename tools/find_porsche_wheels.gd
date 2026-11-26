# tools/find_porsche_wheels.gd
extends SceneTree

func _init() -> void:
	var gltf := GLTFDocument.new()
	var state := GLTFState.new()
	var err := gltf.append_from_file("res://assets/models/cars/porsche_911_turbo.glb", state)
	if err == OK:
		var scene := gltf.generate_scene(state)
		_search_wheel(scene)
	quit(0)

func _search_wheel(n: Node) -> void:
	var nl := n.name.to_lower()
	if "wheel" in nl or "tire" in nl or "rim" in nl:
		print("Potential Porsche wheel node: ", n.name, " class: ", n.get_class(), " children: ", n.get_child_count())
	for c in n.get_children():
		_search_wheel(c)
