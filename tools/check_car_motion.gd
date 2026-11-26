# tools/check_car_motion.gd
extends SceneTree

const OpenWorldManager = preload("res://scripts/world/open_world_manager.gd")

func _init() -> void:
	var scene_res := load("res://scenes/open_world.tscn") as PackedScene
	var ow := scene_res.instantiate() as OpenWorldManager
	root.add_child(ow)
	
	# wait 10 frames for world ready
	for i in range(10):
		await process_frame
		
	ow.switch_player_vehicle("skyline_vspec")
	ow._teleport_to_biome(Vector3(0.0, 0.0, 15.0), 0.0)
	
	print("--- Tracking car position for 30 frames ---")
	for f in range(30):
		await process_frame
		if f % 5 == 0:
			var v = ow.player_vehicle
			print("Frame ", f, " pos: ", v.global_position, " lin_vel: ", v.linear_velocity, " cam_pos: ", ow.camera_rig.camera.global_position)
	quit(0)
