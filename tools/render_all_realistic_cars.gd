# tools/render_all_realistic_cars.gd
@tool
extends SceneTree

const VehicleController = preload("res://scripts/vehicle/vehicle_controller.gd")

func _init() -> void:
	print("=== Rendering Photorealistic Studio Screenshots for All Realistic Cars ===")
	
	var cars := [
		{"id": "skyline_vspec", "out": "build/screenshots/car_nissan_gtr.png", "title": "Nissan GT-R R35 Aimgain Type 2"},
		{"id": "vandal_hyper", "out": "build/screenshots/car_mclaren_p1.png", "title": "McLaren P1 Hypercar"},
		{"id": "turbo_930", "out": "build/screenshots/car_porsche_911.png", "title": "1975 Porsche 911 Turbo Widebody"},
		{"id": "aurelia_gt", "out": "build/screenshots/car_aventador.png", "title": "Lamborghini Aventador LP-700"},
		{"id": "iron_charger", "out": "build/screenshots/car_mustang.png", "title": "Ford Mustang GT"},
		{"id": "bavarian_evo", "out": "build/screenshots/car_bmw_m4.png", "title": "BMW M4 Competition"},
		{"id": "sprinter_r2", "out": "build/screenshots/car_concept.png", "title": "Hero Concept Hypercar"}
	]
	
	var dir := DirAccess.open("res://")
	if dir and not dir.dir_exists("build/screenshots"):
		dir.make_dir_recursive("build/screenshots")
		
	for car in cars:
		print("\nRendering: ", car.title, " (", car.id, ") -> ", car.out)
		var root_3d := Node3D.new()
		root.add_child(root_3d)
		
		# Ground Asphalt Plane
		var ground := MeshInstance3D.new()
		var plane_mesh := PlaneMesh.new()
		plane_mesh.size = Vector2(50.0, 50.0)
		ground.mesh = plane_mesh
		var ground_mat := StandardMaterial3D.new()
		ground_mat.albedo_color = Color(0.18, 0.19, 0.21)
		ground_mat.roughness = 0.35
		ground_mat.metallic = 0.1
		ground.material_override = ground_mat
		root_3d.add_child(ground)
		
		# Studio Key Sun Light
		var sun := DirectionalLight3D.new()
		sun.position = Vector3(15.0, 25.0, 15.0)
		sun.rotation = Vector3(-0.75, 0.65, 0.0)
		sun.light_color = Color(1.0, 0.98, 0.95)
		sun.light_energy = 2.2
		sun.shadow_enabled = true
		root_3d.add_child(sun)
		
		# Soft Ambient Fill Light
		var fill := DirectionalLight3D.new()
		fill.rotation = Vector3(0.5, -2.4, 0.0)
		fill.light_color = Color(0.7, 0.8, 0.95)
		fill.light_energy = 0.6
		root_3d.add_child(fill)
		
		# Spawn Vehicle
		var v := VehicleController.new()
		v.car_id = car.id
		v.position = Vector3(0.0, 0.0, 0.0)
		v._ready()
		root_3d.add_child(v)
		
		# Camera at 3/4 Hero Beauty Angle
		var cam := Camera3D.new()
		cam.position = Vector3(3.8, 1.4, 4.6)
		cam.look_at(v.position + Vector3(0.0, 0.5, 0.0))
		cam.fov = 42.0
		cam.current = true
		root_3d.add_child(cam)
		
		await process_frame
		await process_frame
		await process_frame
		
		var vp := root.get_viewport()
		if vp:
			var img := vp.get_texture().get_image()
			if img and not img.is_empty():
				img.save_png(car.out)
				print("[OK] Successfully saved: ", car.out)
			else:
				print("[FAIL] Image was empty for: ", car.id)
				
		root_3d.free()
		
	print("\n=== All Car Screenshots Rendered Successfully! ===")
	quit(0)
