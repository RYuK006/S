# tools/check_car_body.gd
extends SceneTree

func _init() -> void:
	var gltf := GLTFDocument.new()
	var state := GLTFState.new()
	var err := gltf.append_from_file("res://assets/models/cars/nissan_gtr_r35.glb", state)
	if err == OK:
		var scene := gltf.generate_scene(state)
		var w_parent := _find(scene, "Wheel1A_3D_59")
		if w_parent and w_parent.get_parent():
			var car_root := w_parent.get_parent()
			print("Car root name: ", car_root.name, " children count: ", car_root.get_child_count())
			for c in car_root.get_children():
				print("  Child: ", c.name, " (", c.get_class(), ", children: ", c.get_child_count(), ")")
	quit(0)

func _find(n: Node, name: String) -> Node:
	if n.name == name:
		return n
	for c in n.get_children():
		var r := _find(c, name)
		if r:
			return r
	return null
