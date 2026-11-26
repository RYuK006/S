# tools/analyze_audit_screenshots.gd
extends SceneTree

func _init() -> void:
	var files: Array[String] = [
		"01_hub_starting_grid_gtr.png",
		"02_hub_mclaren_p1.png",
		"03_hub_porsche_911.png",
		"04_dust_bowl_desert.png",
		"05_volcano_ridge.png",
		"06_frozen_pass_snow.png",
		"07_neon_coast_water.png"
	]
	
	for f: String in files:
		var path: String = "build/screenshots/audit/" + f
		var img: Image = Image.load_from_file(path)
		if img:
			var w: int = img.get_width()
			var h: int = img.get_height()
			var sky_p: Color = img.get_pixel(w / 2, int(h * 0.15))
			var road_or_ground_p: Color = img.get_pixel(w / 2, int(h * 0.90))
			var car_center_p: Color = img.get_pixel(w / 2, int(h * 0.72))
			print("=== ", f, " (", w, "x", h, ") ===")
			print("  Sky color:        ", sky_p)
			print("  Car center:       ", car_center_p)
			print("  Ground / Road:    ", road_or_ground_p)
		else:
			print("FAILED to load: ", path)
	quit(0)
