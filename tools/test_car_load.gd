# tools/test_car_load.gd
extends SceneTree

const VehicleController = preload("res://scripts/vehicle/vehicle_controller.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	var root := Node3D.new()
	get_root().add_child(root)
	
	var car := VehicleController.new()
	car.car_id = "skyline_vspec"
	root.add_child(car)
	car.global_position = Vector3(0, 10, 0)
	
	await process_frame
	await process_frame
	
	print("Car global position: ", car.global_position)
	print("Car mesh instance global position: ", car.car_mesh_instance.global_position)
	print("Car mesh instance global rotation: ", car.car_mesh_instance.global_rotation)
	print("Car mesh instance global scale: ", car.car_mesh_instance.global_basis.get_scale())
	
	# Check where some of the body meshes are
	var m_list: Array[MeshInstance3D] = []
	_gather_meshes(car.car_mesh_instance, m_list)
	print("Total meshes gathered under car_mesh_instance: ", m_list.size())
	for i in range(mini(5, m_list.size())):
		var m := m_list[i]
		print("Mesh [", m.name, "] global_pos: ", m.global_position, " aabb: ", m.get_aabb(), " visible: ", m.is_visible_in_tree())
		
	# Check wheels
	for w in car.wheels:
		print("Wheel ", w.name, " global_pos: ", w.global_position, " visual: ", w.wheel_visual)
		if w.wheel_visual:
			print("   visual global_pos: ", w.wheel_visual.global_position)

	quit(0)

func _gather_meshes(node: Node, list: Array[MeshInstance3D]) -> void:
	for c in node.get_children():
		if c is MeshInstance3D:
			list.append(c)
		_gather_meshes(c, list)
