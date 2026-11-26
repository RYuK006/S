# tools/inspect_rock_model.gd
extends SceneTree

func _init() -> void:
	var gltf := GLTFDocument.new()
	var state := GLTFState.new()
	var err := gltf.append_from_file("res://assets/models/props/cliff_rock/scene.gltf", state)
	if err == OK:
		var scene := gltf.generate_scene(state)
		print("Rock scene: ", scene.name)
		var meshes: Array[MeshInstance3D] = []
		_gather(scene, meshes)
		print("Rock meshes found: ", meshes.size())
		for m in meshes:
			print("  Mesh: ", m.name, " aabb: ", m.get_aabb(), " mat: ", m.get_active_material(0))
	else:
		print("Failed to load rock gltf, err: ", err)
	quit(0)

func _gather(n: Node, list: Array[MeshInstance3D]) -> void:
	if n is MeshInstance3D: list.append(n)
	for c in n.get_children(): _gather(c, list)
