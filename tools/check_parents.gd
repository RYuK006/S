# tools/check_parents.gd
extends SceneTree

func _init() -> void:
	var gltf := GLTFDocument.new()
	var state := GLTFState.new()
	var err := gltf.append_from_file("res://assets/models/cars/nissan_gtr_r35.glb", state)
	if err == OK:
		var scene := gltf.generate_scene(state)
		# Find where "3DWheel Front L_60" is and what its parent and siblings are
		var wheel := _find(scene, "3DWheel Front L_60")
		if wheel:
			print("wheel parent: ", wheel.get_parent().name)
			print("wheel siblings: ")
			for sib in wheel.get_parent().get_children():
				print("   sib: ", sib.name, " children: ", sib.get_child_count())
			print("wheel children: ", wheel.get_child_count())
			for c in wheel.get_children():
				print("   wheel child: ", c.name, " children: ", c.get_child_count())
	quit(0)

func _find(n: Node, name: String) -> Node:
	if n.name == name:
		return n
	for c in n.get_children():
		var r := _find(c, name)
		if r:
			return r
	return null
