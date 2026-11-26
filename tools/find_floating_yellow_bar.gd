# tools/find_floating_yellow_bar.gd
extends SceneTree

func _init() -> void:
	var scene_res := load("res://scenes/open_world.tscn") as PackedScene
	var ow = scene_res.instantiate()
	root.add_child(ow)
	_scan(ow)
	ow.free()
	quit(0)

func _scan(n: Node) -> void:
	if n is MeshInstance3D:
		var aabb: AABB = n.get_aabb() if n.mesh else AABB()
		var gpos: Vector3 = n.global_position
		# Check if it has a large yellow or emissive bar or is high up in the air
		if gpos.y > 10.0 or aabb.size.x > 10.0 or aabb.size.z > 10.0:
			print("Found large/high MeshInstance3D: ", n.name, " path: ", n.get_path(), " pos: ", gpos, " aabb: ", aabb)
			var mat = n.material_override
			if not mat and n.mesh:
				mat = n.mesh.surface_get_material(0)
			if mat is StandardMaterial3D:
				print("  mat albedo: ", mat.albedo_color, " emission: ", mat.emission_enabled, " ", mat.emission)
	for c in n.get_children():
		_scan(c)
