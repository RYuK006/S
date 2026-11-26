# tools/verify_all_cars_physics.gd
extends SceneTree

const VehicleController = preload("res://scripts/vehicle/vehicle_controller.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var d := DirAccess.open("res://")
	if d and not d.dir_exists("build/screenshots/cars_verify"):
		d.make_dir_recursive("build/screenshots/cars_verify")

	var root_3d := Node3D.new()
	get_root().add_child(root_3d)

	# Studio lighting using our new FH5 HDRI sky
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := PanoramaSkyMaterial.new()
	sky_mat.panorama = load("res://assets/hdri/kloofendal_48d_partly_cloudy_puresky_4k.hdr") as Texture2D
	sky.sky_material = sky_mat
	env.sky = sky
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 0.92
	env.ssao_enabled = true
	env.ssao_intensity = 2.0
	var we := WorldEnvironment.new()
	we.environment = env
	root_3d.add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.68, 0.72, 0.0)
	sun.light_energy = 2.4
	sun.shadow_enabled = true
	root_3d.add_child(sun)

	# Static asphalt floor at y = 0
	var ground_body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(80.0, 1.0, 80.0)
	col.shape = box
	col.position = Vector3(0.0, -0.5, 0.0)
	ground_body.add_child(col)
	ground_body.set_meta("surface", "asphalt_dry")

	var ground_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(80.0, 80.0)
	ground_mi.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_texture = load("res://assets/textures/asphalt_diff.jpg") as Texture2D
	gm.normal_enabled = true
	gm.normal_texture = load("res://assets/textures/asphalt_nor.jpg") as Texture2D
	gm.roughness_texture = load("res://assets/textures/asphalt_rough.jpg") as Texture2D
	gm.uv1_scale = Vector3(16.0, 16.0, 1.0)
	ground_mi.material_override = gm
	ground_body.add_child(ground_mi)
	root_3d.add_child(ground_body)

	var cam := Camera3D.new()
	cam.fov = 38.0
	cam.current = true
	root_3d.add_child(cam)

	var test_cars: Array[String] = [
		"tundra_wolf",      # subaru_sti.glb
		"desert_corsair",   # ford_bronco.glb
		"mud_reaper",       # ford_raptor.glb
		"iron_charger",     # dodge_challenger.glb
		"skyline_vspec",    # nissan_gtr_r35.glb
		"bavarian_evo",     # bmw_m4.glb
		"turbo_930",        # porsche_911_turbo.glb
		"aurelia_gt",       # aventador.glb
		"noir_phantom",     # ferrari_488_pista.glb
		"vandal_hyper",     # mclaren_p1.glb
		"countach_apex"     # lamborghini_countach_lpi.glb
	]

	for cid: String in test_cars:
		var car := VehicleController.new()
		car.car_id = cid
		car.position = Vector3(0.0, 0.25, 0.0)
		root_3d.add_child(car)

		# Let physics run 90 physics ticks (~0.75s) for suspension to settle naturally
		for _i: int in range(90):
			await physics_frame

		var wheel_report: String = ""
		for rw in car.wheels:
			var vis_children: int = rw.wheel_visual.get_child_count() if rw.wheel_visual else -1
			var vis_y: float = rw.wheel_visual.position.y if rw.wheel_visual else 0.0
			wheel_report += " [g=%s r=%.2f vy=%.3f ch=%d]" % [str(rw.is_grounded), rw.wheel_radius, vis_y, vis_children]

		print("CAR ", cid, " -> pos=", car.global_position.snapped(Vector3(0.001, 0.001, 0.001)), wheel_report)

		# Shot 1: Front 3/4 view (front is -Z)
		cam.position = Vector3(3.6, 1.30, -4.1)
		cam.look_at(Vector3(0.0, 0.55, 0.0))
		for _f: int in range(4):
			await process_frame
		var img_front: Image = get_root().get_texture().get_image()

		# Shot 2: Rear 3/4 + Side profile view
		cam.position = Vector3(-4.0, 1.35, 3.6)
		cam.look_at(Vector3(0.0, 0.55, 0.0))
		for _f: int in range(4):
			await process_frame
		var img_rear: Image = get_root().get_texture().get_image()

		# Stitch side-by-side into one wide strip
		var w: int = img_front.get_width()
		var h: int = img_front.get_height()
		var half_w: int = int(w / 2.0)
		img_front.resize(half_w, int(h / 2.0))
		img_rear.resize(half_w, int(h / 2.0))
		var combined := Image.create(w, int(h / 2.0), false, img_front.get_format())
		combined.blit_rect(img_front, Rect2i(0, 0, half_w, int(h / 2.0)), Vector2i(0, 0))
		combined.blit_rect(img_rear, Rect2i(0, 0, half_w, int(h / 2.0)), Vector2i(half_w, 0))
		combined.save_png("res://build/screenshots/cars_verify/" + cid + ".png")

		car.queue_free()
		await process_frame

	print("VERIFY_ALL_CARS_COMPLETE")
	quit(0)
