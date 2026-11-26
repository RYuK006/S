# tools/test_rock_load.gd
extends SceneTree

func _init() -> void:
	var rock_scene := load("res://assets/models/props/cliff_rock/scene.gltf") as PackedScene
	if rock_scene:
		print("Loaded rock_scene successfully!")
		var inst := rock_scene.instantiate()
		var mesh_inst: MeshInstance3D = null
		for c in inst.get_children():
			_find_mesh(c)
		inst.free()
	else:
		print("Failed to load rock_scene")
	quit(0)

func _find_mesh(n: Node) -> void:
	if n is MeshInstance3D and n.mesh:
		print("Found mesh node: ", n.name, " mesh: ", n.mesh.get_class(), " mat: ", n.get_active_material(0))
	for c in n.get_children():
		_find_mesh(c)
