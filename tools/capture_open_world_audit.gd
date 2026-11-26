# tools/capture_open_world_audit.gd
extends SceneTree

const OpenWorldManager = preload("res://scripts/world/open_world_manager.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("=== Running Open World Visual Audit with Forward+ Vulkan ===")
	
	# Load the open world scene
	var scene_res := load("res://scenes/open_world.tscn") as PackedScene
	if not scene_res:
		print("ERROR: Failed to load open_world.tscn")
		quit(1)
		return
		
	var ow := scene_res.instantiate() as OpenWorldManager
	root.add_child(ow)
	
	# Let world initialize, chunks stream, and shaders compile
	for i in range(25):
		await process_frame
		
	var vp := root.get_viewport()
	var dir := DirAccess.open("res://")
	if dir and not dir.dir_exists("build/screenshots/audit"):
		dir.make_dir_recursive("build/screenshots/audit")
		
	# Audit locations and car switches
	var audits := [
		{"name": "01_hub_starting_grid_gtr", "car": "skyline_vspec", "pos": Vector3(0.0, 0.0, 15.0), "yaw": 0.0},
		{"name": "02_hub_mclaren_p1", "car": "vandal_hyper", "pos": Vector3(0.0, 0.0, 15.0), "yaw": 0.0},
		{"name": "03_hub_porsche_911", "car": "turbo_930", "pos": Vector3(0.0, 0.0, 15.0), "yaw": 0.0},
		{"name": "04_dust_bowl_desert", "car": "iron_charger", "pos": Vector3(-1100.0, 0.0, 900.0), "yaw": -PI * 0.35},
		{"name": "05_volcano_ridge", "car": "aurelia_gt", "pos": Vector3(1100.0, 0.0, -1100.0), "yaw": PI * 0.65},
		{"name": "06_frozen_pass_snow", "car": "skyline_vspec", "pos": Vector3(-1300.0, 0.0, -1300.0), "yaw": PI * 0.25},
		{"name": "07_neon_coast_water", "car": "vandal_hyper", "pos": Vector3(1200.0, 0.0, 1200.0), "yaw": PI * 0.25}
	]
	
	for a in audits:
		print("Auditing: ", a.name, " (Car: ", a.car, " at ", a.pos, ")")
		ow.switch_player_vehicle(a.car)
		ow._teleport_to_biome(a.pos, a.yaw)
		
		# Allow physics, camera rig, and rendering to settle
		for f in range(30):
			await process_frame
			
		var img := vp.get_texture().get_image()
		if img and not img.is_empty():
			var out_file := "build/screenshots/audit/%s.png" % a.name
			img.save_png(out_file)
			print("[SAVED] ", out_file)
			
	ow.free()
	print("=== Open World Visual Audit Complete! ===")
	quit(0)
