# tools/check_gtr_visibility.gd
@tool
extends SceneTree

func _init() -> void:
	print("--- Checking GTR and McLaren Mesh / Material Details ---")
	for path in ["res://assets/models/cars/nissan_gtr_r35.glb", "res://assets/models/cars/mclaren_p1.glb"]:
		print("\nChecking: ", path)
		var gltf := GLTFDocument.new()
		var state := GLTFState.new()
		gltf.append_from_file(path, state)
		var scene := gltf.generate_scene(state) as Node3D
		
		var meshes := scene.find_children("*", "MeshInstance3D")
		print("Total MeshInstance3Ds: ", meshes.size())
		var count_vis := 0
		for m in meshes:
			var mi := m as MeshInstance3D
			if mi.visible:
				count_vis += 1
				if count_vis <= 5:
					print("  Mesh: ", mi.name, " parent: ", mi.get_parent().name, " aabb: ", (mi.mesh.get_aabb() if mi.mesh else "no mesh"))
					if mi.mesh:
						for s in range(mi.mesh.get_surface_count()):
							var mat = mi.mesh.surface_get_material(s)
							print("    surface ", s, " mat: ", (mat.resource_name if mat else "null"), " class: ", (mat.get_class() if mat else "none"))
		print("Visible meshes: ", count_vis, " / ", meshes.size())
		scene.free()
	quit(0)
