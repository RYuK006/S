# tools/audit_visual_upgrade.gd
# Captures multi-biome lighting/blending shots, restructured real-world road town/mountain grids,
# new exotic car showcase, and live high-speed heterogeneous prop destruction impacts.
extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var dir := DirAccess.open("res://")
	if dir and not dir.dir_exists("build/screenshots/upgrade_v1"):
		dir.make_dir_recursive("build/screenshots/upgrade_v1")

	var packed := load("res://scenes/open_world.tscn") as PackedScene
	if not packed:
		push_error("Failed to load open_world.tscn")
		quit(1)
		return

	var world: Node3D = packed.instantiate() as Node3D
	get_root().add_child(world)
	await process_frame
	await process_frame

	var hero_cam := Camera3D.new()
	hero_cam.fov = 46.0
	world.add_child(hero_cam)

	var shots: Array[Dictionary] = [
		{"file": "01_hub_town_grid_bugatti", "car": "bugatti_centodieci", "pos": Vector3(0.0, 0.0, 12.0), "yaw": 0.0, "mode": "chase"},
		{"file": "02_town_street_f40", "car": "ferrari_f40_lm", "road": "Horizon Plaza", "t": 0.14, "mode": "hero"},
		{"file": "03_frozen_pass_switchbacks_quattro", "car": "audi_sport_quattro", "road": "Frozen Pass Hillclimb", "t": 0.24, "mode": "chase"},
		{"file": "04_dust_bowl_baja_defender", "car": "land_rover_defender", "road": "Baja Red-Rock", "t": 0.32, "mode": "chase"},
		{"file": "05_volcano_rim_720s", "car": "mclaren_720s", "road": "Caldera Rim", "t": 0.56, "mode": "chase"},
		{"file": "06_coast_harbor_g63", "car": "mercedes_g63_amg", "road": "Harbor Town Ave 1840", "t": 0.45, "mode": "hero"},
		{"file": "08_rx7_hero", "car": "mazda_rx7_fd", "road": "Festival Main", "t": 0.28, "mode": "hero"}
	]

	for s: Dictionary in shots:
		world.switch_player_vehicle(str(s["car"]))
		if s.has("road"):
			world._teleport_to_road(str(s["road"]), float(s["t"]))
		else:
			world._teleport_to_biome(s["pos"], float(s["yaw"]))
		for _i: int in range(55):
			await physics_frame
		var pv: Node3D = world.player_vehicle
		var cr: CameraRig = world.camera_rig
		if str(s["mode"]) == "hero" and pv:
			var forward: Vector3 = -pv.global_transform.basis.z
			var right: Vector3 = pv.global_transform.basis.x
			hero_cam.position = pv.global_position + forward * 4.5 + right * 3.2 + Vector3(0.0, 1.45, 0.0)
			hero_cam.look_at(pv.global_position + Vector3(0.0, 0.72, 0.0))
			hero_cam.current = true
		elif cr and cr.camera:
			cr.snap_to_target()
			cr.camera.current = true
		for _f: int in range(6):
			await process_frame
		var img: Image = get_root().get_texture().get_image()
		if img:
			var p_out: String = "res://build/screenshots/upgrade_v1/" + str(s["file"]) + ".png"
			img.save_png(p_out)
			print("CAPTURED: ", p_out, " pos=", pv.global_position if pv else Vector3.ZERO)

	# Action Shot 7: Live Heterogeneous Destruction Ram into Crates/Hydrants/Poles/Tires on Flat Hub Ground
	var dm = world.destruct_manager
	if dm:
		world.switch_player_vehicle("ford_gt_2017")
		for _i: int in range(25):
			await physics_frame
		var pv2: RigidBody3D = world.player_vehicle
		var tg = world.terrain_gen
		var target_pos := Vector3.ZERO
		var approach_dir := Vector3(0.0, 0.0, -1.0)
		var best_d := 1e9
		for e: Dictionary in dm._prop_entries:
			var dt: int = int(e["type"])
			if dt >= 3 and dt <= 8:
				var gp: Vector3 = e["ground_pos"]
				if Vector2(gp.x, gp.z).length() < 280.0:
					var d2: float = gp.length()
					if d2 < best_d and d2 > 22.0:
						best_d = d2
						target_pos = gp
		if target_pos != Vector3.ZERO:
			# Pick approach tangent along flat ground clear of slopes
			var rad_dir := Vector3(target_pos.x, 0.0, target_pos.z).normalized()
			approach_dir = Vector3(-rad_dir.z, 0.0, rad_dir.x).normalized()
			var start_xz: Vector3 = target_pos - approach_dir * 10.5
			var start_y: float = tg.get_height(start_xz.x, start_xz.z) + 0.42
			pv2.global_position = Vector3(start_xz.x, start_y, start_xz.z)
			pv2.look_at(Vector3(target_pos.x, start_y, target_pos.z), Vector3.UP)
			pv2.linear_velocity = approach_dir * 30.0
			dm.force_refresh_near(pv2.global_position)
			for _k: int in range(44):
				await physics_frame
			var cr2: CameraRig = world.camera_rig
			if cr2 and cr2.camera:
				cr2.snap_to_target()
				cr2.camera.current = true
			for _f: int in range(4):
				await process_frame
			var img2: Image = get_root().get_texture().get_image()
			if img2:
				img2.save_png("res://build/screenshots/upgrade_v1/07_destruction_impact.png")
				print("CAPTURED: 07_destruction_impact.png broken_props=", dm.get_broken_prop_count(), "/", dm.get_total_prop_count())

	var vram_mb: float = float(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED)) / (1024.0 * 1024.0)
	var draws: int = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	var objs: int = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)
	print("GPU TELEMETRY: VRAM=%.1f MB draws=%d objs=%d" % [vram_mb, draws, objs])
	print("UPGRADE_AUDIT_COMPLETE")
	quit(0)
