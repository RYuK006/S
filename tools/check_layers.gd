# tools/check_layers.gd
extends SceneTree

const OpenWorldManager = preload("res://scripts/world/open_world_manager.gd")

func _init() -> void:
	var scene_res := load("res://scenes/open_world.tscn") as PackedScene
	var ow := scene_res.instantiate() as OpenWorldManager
	root.add_child(ow)
	
	for i in range(10): await process_frame
	ow.switch_player_vehicle("skyline_vspec")
	for i in range(5): await process_frame
	
	var cam = ow.camera_rig.camera
	print("Camera cull_mask: ", cam.cull_mask, " near: ", cam.near, " far: ", cam.far)
	var v = ow.player_vehicle
	print("Car mesh instance layers: ", v.car_mesh_instance.get("layers"))
	for c in v.car_mesh_instance.get_children():
		_print_layer(c)
	quit(0)

func _print_layer(n: Node) -> void:
	if n is VisualInstance3D:
		print("  Node: ", n.name, " layers: ", n.layers, " visible: ", n.visible)
	for c in n.get_children():
		_print_layer(c)
