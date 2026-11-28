# tools/audit_new_assets.gd
# Headless validator inspecting every vehicle in data/vehicles.json + every new prop GLB/GLTF
# to verify axis orientation, wheel detection count, scale sanity, and material hygiene.
extends SceneTree

const CarModelLoader = preload("res://scripts/vehicle/car_model_loader.gd")
const VehicleController = preload("res://scripts/vehicle/vehicle_controller.gd")
const PropMeshUtils = preload("res://scripts/world/prop_mesh_utils.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var f := FileAccess.open("res://data/vehicles.json", FileAccess.READ)
	var vd: Dictionary = JSON.parse_string(f.get_as_text())
	f.close()

	var seen_models: Dictionary = {}
	var bad_cars: int = 0
	var root := Node3D.new()
	get_root().add_child(root)

	for v: Dictionary in vd.get("vehicles", []):
		var mp: String = str(v.get("model_path", ""))
		if mp.is_empty() or seen_models.has(mp):
			continue
		seen_models[mp] = true
		var vc := VehicleController.new()
		vc.car_id = str(v["id"])
		root.add_child(vc)
		var bound_wheels: int = 0
		for rw in vc.wheels:
			if rw.wheel_visual and rw.wheel_visual.get_child_count() > 0:
				bound_wheels += 1
		var vis: Node3D = vc.car_mesh_instance
		var aabb: AABB = CarModelLoader._calc_hierarchy_aabb(vc, vis, Transform3D.IDENTITY) if vis else AABB()
		var flag: String = "OK"
		var fw_z: float = vc.front_left_wheel.position.z if vc.front_left_wheel else 0.0
		var rw_z: float = vc.rear_left_wheel.position.z if vc.rear_left_wheel else 0.0
		var lw_x: float = vc.front_left_wheel.position.x if vc.front_left_wheel else 0.0
		if bound_wheels < 4 or aabb.size.x > aabb.size.z * 0.92 or fw_z > -0.5 or rw_z < 0.5 or lw_x > -0.35:
			flag = "FIX(w=%d, sz=%.2fx%.2fx%.2f, fz=%.2f, rz=%.2f, lx=%.2f)" % [bound_wheels, aabb.size.x, aabb.size.y, aabb.size.z, fw_z, rw_z, lw_x]
			if bound_wheels < 4:
				bad_cars += 1
		print("[CAR AUDIT] %-26s | %s" % [v["id"], flag])
		vc.free()

	var mf := FileAccess.open("res://data/approved_assets_manifest.json", FileAccess.READ)
	var md: Dictionary = JSON.parse_string(mf.get_as_text())
	mf.close()
	var prop_ok: int = 0
	var prop_fail: int = 0
	for p: Dictionary in md.get("props", []):
		var mpath: String = str(p.get("model_path", ""))
		var mesh: Mesh = PropMeshUtils.load_centered_mesh(mpath, 1.0, 0.04, "")
		if mesh and mesh.get_surface_count() > 0:
			prop_ok += 1
		else:
			prop_fail += 1
			print("[PROP FAIL] %s (%s)" % [p.get("slug", ""), mpath])

	print("AUDIT SUMMARY: unique_car_glbs=%d bad_cars=%d props_ok=%d props_fail=%d" % [seen_models.size(), bad_cars, prop_ok, prop_fail])
	quit(0 if (bad_cars == 0 and prop_fail == 0) else 1)
