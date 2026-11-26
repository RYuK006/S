# tools/inspect_gtr_model.gd
extends SceneTree

func _init() -> void:
	var gltf := GLTFDocument.new()
	var state := GLTFState.new()
	var err := gltf.append_from_file("res://assets/models/cars/nissan_gtr_r35.glb", state)
	if err == OK:
		var scene := gltf.generate_scene(state)
		var fl := _find(scene, "3DWheel Front L_60")
		var rl := _find(scene, "3DWheel Rear L_286")
		if fl:
			print("Original FL wheel transform origin: ", fl.position, " global: ", fl.global_position)
		if rl:
			print("Original RL wheel transform origin: ", rl.position, " global: ", rl.global_position)
			
		# Check the paint mesh
		var paint := _find(scene, "n_Kit4_Paint_Geo_lodA_Kit4_Paint_Geo_lodA_Nissan_GTRTNR4_2017PaintTNR_Material_33")
		if paint:
			print("Paint node class: ", paint.get_class(), " children: ", paint.get_child_count())
			for c in paint.get_children():
				if c is MeshInstance3D:
					print("   Paint mesh: ", c.name, " aabb: ", c.get_aabb())
					print("   Surface count: ", c.mesh.get_surface_count())
					for s in range(c.mesh.get_surface_count()):
						print("     Mat: ", c.get_active_material(s))
	quit(0)

func _find(n: Node, name: String) -> Node:
	if n.name == name:
		return n
	for c in n.get_children():
		var r := _find(c, name)
		if r:
			return r
	return null
