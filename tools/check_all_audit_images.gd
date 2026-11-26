# tools/check_all_audit_images.gd
extends SceneTree

func _init() -> void:
	var files = [
		"01_hub_starting_grid_gtr.png",
		"02_hub_mclaren_p1.png",
		"03_hub_porsche_911.png",
		"04_dust_bowl_desert.png",
		"05_volcano_ridge.png",
		"06_frozen_pass_snow.png",
		"07_neon_coast_water.png"
	]
	for f in files:
		var path = "build/screenshots/audit/" + f
		var img = Image.load_from_file(path)
		if img:
			var w = img.get_width()
			var h = img.get_height()
			var car_p = img.get_pixel(w / 2, int(h * 0.72))
			print(f, " -> ", car_p)
		else:
			print(f, " -> FAILED TO LOAD")
	quit(0)
