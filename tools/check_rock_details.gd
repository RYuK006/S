# tools/check_rock_details.gd
extends SceneTree

func _init() -> void:
	var gltf := GLTFDocument.new()
	var state := GLTFState.new()
	var err := gltf.append_from_file("res://assets/models/props/cliff_rock/scene.gltf", state)
	if err == OK:
		var scene := gltf.generate_scene(state)
		_gather(scene)
		scene.free()
	quit(0)

func _gather(n: Node) -> void:
	if n is MeshInstance3D and n.mesh:
		var m: Mesh = n.mesh
		var faces := m.get_faces()
		print("Mesh: ", n.name, " faces: ", faces.size() / 3, " aabb: ", m.get_aabb())
		var mat = n.get_active_material(0)
		if mat is StandardMaterial3D:
			print("  albedo_texture: ", mat.albedo_texture)
			print("  normal_texture: ", mat.normal_texture)
			print("  roughness_texture: ", mat.roughness_texture)
	for c in n.get_children():
		_gather(c)
