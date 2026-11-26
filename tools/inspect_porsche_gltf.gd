# tools/inspect_porsche_gltf.gd
extends SceneTree

func _init() -> void:
	var gltf := GLTFDocument.new()
	var state := GLTFState.new()
	var err := gltf.append_from_file("res://assets/models/cars/porsche_911_turbo.glb", state)
	if err == OK:
		var scene := gltf.generate_scene(state)
		var gltf_root = _find(scene, "GLTF_SceneRootNode")
		if gltf_root:
			print("GLTF_SceneRootNode children: ", gltf_root.get_child_count())
			for c in gltf_root.get_children():
				print("  Child: ", c.name, " class: ", c.get_class(), " count: ", c.get_child_count())
				for cc in c.get_children():
					print("    SubChild: ", cc.name, " class: ", cc.get_class())
	quit(0)

func _find(n: Node, name: String) -> Node:
	if n.name == name: return n
	for c in n.get_children():
		var r = _find(c, name)
		if r: return r
	return null
