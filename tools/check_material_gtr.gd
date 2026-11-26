# tools/check_material_gtr.gd
extends SceneTree

const VehicleController = preload("res://scripts/vehicle/vehicle_controller.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var root := Node3D.new()
	get_root().add_child(root)
	
	var car := VehicleController.new()
	car.car_id = "skyline_vspec"
	root.add_child(car)
	
	await process_frame
	await process_frame
	
	var meshes: Array[MeshInstance3D] = []
	_gather(car, meshes)
	
	print("Checking materials on %d meshes:" % meshes.size())
	for m in meshes:
		if "paint" in m.name.to_lower() or "paint" in m.get_parent().name.to_lower():
			print("Mesh: ", m.name, " parent: ", m.get_parent().name)
			print("  material_override: ", m.material_override)
			print("  surface_count: ", m.mesh.get_surface_count() if m.mesh else 0)
			for s in range(m.mesh.get_surface_count() if m.mesh else 0):
				var mat = m.get_active_material(s)
				print("    surf ", s, " mat: ", mat, " class: ", mat.get_class() if mat else "null")
				if mat is StandardMaterial3D:
					print("       albedo_color: ", mat.albedo_color, " transparency: ", mat.transparency, " cull: ", mat.cull_mode)
				elif mat is ShaderMaterial:
					print("       shader: ", mat.shader.resource_path if mat.shader else "null")
	quit(0)

func _gather(n: Node, list: Array[MeshInstance3D]) -> void:
	if n is MeshInstance3D:
		list.append(n)
	for c in n.get_children():
		_gather(c, list)
