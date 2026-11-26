# tools/capture_open_world_audit.gd
extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var dir := DirAccess.open("res://")
	if dir and not dir.dir_exists("build/screenshots/audit_v2"):
		dir.make_dir_recursive("build/screenshots/audit_v2")

	var packed := load("res://scenes/open_world.tscn") as PackedScene
	if not packed:
		push_error("Failed to load open_world.tscn")
		quit(1)
		return

	var world: Node3D = packed.instantiate() as Node3D
	get_root().add_child(world)
	await process_frame
	await process_frame

	var shots: Array[Dictionary] = [
		{"file": "01_hub_chase_gtr", "car": "skyline_vspec", "pos": Vector3(0.0, 0.0, 12.0), "yaw": 0.0, "mode": "chase"},
		{"file": "02_hub_hero_ferrari", "car": "noir_phantom", "pos": Vector3(0.0, 0.0, 4.0), "yaw": 0.15, "mode": "hero"},
		{"file": "03_dust_bowl_bronco", "car": "desert_corsair", "road": "Dust Bowl", "t": 0.56, "mode": "chase"},
		{"file": "04_dust_bowl_hero", "car": "mud_reaper", "road": "Dust Bowl", "t": 0.38, "mode": "hero"},
		{"file": "05_volcano_ridge", "car": "aurelia_gt", "road": "Volcano Ridge", "t": 0.52, "mode": "chase"},
		{"file": "06_frozen_pass_sti", "car": "tundra_wolf", "road": "Frozen Pass", "t": 0.48, "mode": "chase"},
		{"file": "07_neon_coast_p1", "car": "vandal_hyper", "road": "Neon Coastline", "t": 0.25, "mode": "chase"},
		{"file": "08_coast_ocean_hero", "car": "countach_apex", "road": "Neon Coastline", "t": 0.36, "mode": "hero_ocean"}
	]

	var hero_cam := Camera3D.new()
	hero_cam.fov = 44.0
	world.add_child(hero_cam)

	for s: Dictionary in shots:
		world.switch_player_vehicle(s["car"])
		if s.has("road"):
			world._teleport_to_road(s["road"], float(s["t"]))
		else:
			world._teleport_to_biome(s["pos"], float(s["yaw"]))

		for _i: int in range(60):
			await physics_frame

		var pv: Node3D = world.player_vehicle
		var cr: CameraRig = world.camera_rig
		if str(s["mode"]).begins_with("hero") and pv:
			var forward: Vector3 = -pv.global_transform.basis.z
			var right: Vector3 = pv.global_transform.basis.x
			# For ocean hero: stand inland (-right = west) looking east across car toward ocean bay
			var side_sign: float = -1.0 if s["mode"] == "hero_ocean" else 1.0
			var cam_pos: Vector3 = pv.global_position + forward * 4.2 + right * (3.4 * side_sign) + Vector3(0.0, 1.45, 0.0)
			hero_cam.position = cam_pos
			hero_cam.look_at(pv.global_position + Vector3(0.0, 0.72, 0.0))
			hero_cam.current = true
		elif cr and cr.camera:
			cr.snap_to_target()
			cr.camera.current = true

		for _f: int in range(6):
			await process_frame

		var img: Image = get_root().get_texture().get_image()
		if img:
			var out_path: String = "res://build/screenshots/audit_v2/" + str(s["file"]) + ".png"
			img.save_png(out_path)
			print("CAPTURED: ", out_path, " car_y=", pv.global_position.y if pv else 0.0)

	print("OPEN_WORLD_AUDIT_COMPLETE")
	quit(0)
