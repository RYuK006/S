# tools/test_p1_render.gd
extends SceneTree

const OpenWorldManager = preload("res://scripts/world/open_world_manager.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene_res := load("res://scenes/open_world.tscn") as PackedScene
	var ow := scene_res.instantiate() as OpenWorldManager
	root.add_child(ow)
	
	for i in range(15):
		await process_frame
		
	ow.switch_player_vehicle("vandal_hyper")
	ow._teleport_to_biome(Vector3(0.0, 0.0, 15.0), 0.0)
	
	for i in range(30):
		await process_frame
		
	var v = ow.player_vehicle
	print("Player vehicle: ", v, " pos: ", v.global_position)
	print("Car mesh instance: ", v.car_mesh_instance, " global_scale: ", v.car_mesh_instance.global_basis.get_scale())
	
	var vp := root.get_viewport()
	var img := vp.get_texture().get_image()
	if img:
		img.save_png("build/screenshots/p1_fixed.png")
		print("[SUCCESS] Saved build/screenshots/p1_fixed.png")
	
	quit(0)
