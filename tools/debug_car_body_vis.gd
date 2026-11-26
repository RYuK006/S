# tools/debug_car_body_vis.gd
@tool
extends SceneTree

const VehicleController = preload("res://scripts/vehicle/vehicle_controller.gd")

func _init() -> void:
	print("--- Debugging Car Body Visibility ---")
	var root_3d := Node3D.new()
	root.add_child(root_3d)
	
	for cid in ["skyline_vspec", "vandal_hyper", "iron_charger", "aurelia_gt"]:
		print("\nChecking: ", cid)
		var v := VehicleController.new()
		v.car_id = cid
		root_3d.add_child(v)
		v._ready()
		
		print("  v.car_mesh_instance: ", v.car_mesh_instance)
		if v.car_mesh_instance:
			print("  parent: ", v.car_mesh_instance.get_parent().name)
			print("  visible: ", v.car_mesh_instance.visible)
			print("  position: ", v.car_mesh_instance.position)
			print("  scale: ", v.car_mesh_instance.scale)
			print("  rotation: ", v.car_mesh_instance.rotation)
			print("  children count: ", v.car_mesh_instance.get_child_count())
			for c in v.car_mesh_instance.get_children():
				print("    child: ", c.name, " (", c.get_class(), ") pos: ", c.position, " vis: ", (c.visible if "visible" in c else "n/a"))
				
		v.free()
	root_3d.free()
	quit(0)
