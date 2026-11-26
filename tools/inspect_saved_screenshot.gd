# tools/inspect_saved_screenshot.gd
extends SceneTree

func _init() -> void:
	var path := "build/screenshots/gtr_test.png"
	var img := Image.load_from_file(path)
	if img:
		var w := img.get_width()
		var h := img.get_height()
		var center_pixel := img.get_pixel(w / 2, h / 2)
		var car_pixel := img.get_pixel(w / 2, int(h * 0.7))
		print(path, " size: ", w, "x", h, " center: ", center_pixel, " car_spot: ", car_pixel)
		# Scan vertical line in center of image to find car pixels
		var car_pixels := 0
		for y in range(int(h * 0.4), int(h * 0.95)):
			var p := img.get_pixel(w / 2, y)
			# If pixel is not blue sky (blue > 0.6) and not asphalt (around 0.3-0.4)
			# Check color
			if y % 20 == 0:
				print("  y=", y, " color=", p)
	else:
		print("Could not load: ", path)
	quit(0)
