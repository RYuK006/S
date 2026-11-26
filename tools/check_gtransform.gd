# tools/check_gtransform.gd
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
	
	var paint_mesh = _find_mesh(car, "Object_53")
	if paint_mesh:
		print("Object_53 global transform:")
		print("  origin: ", paint_mesh.global_transform.origin)
		print("  basis.x: ", paint_mesh.global_transform.basis.x)
		print("  basis.y: ", paint_mesh.global_transform.basis.y)
		print("  basis.z: ", paint_mesh.global_transform.basis.z)
		print("  mesh AABB: ", paint_mesh.mesh.get_aabb())
		print("  custom AABB: ", paint_mesh.custom_aabb)
	else:
		print("Object_53 not found!")
	quit(0)

func _find_mesh(n: Node, name: String) -> MeshInstance3D:
	if n.name == name and n is MeshInstance3D:
		return n
	for c in n.get_children():
		var r = _find_mesh(c, name)
		if r: return r
	return null
