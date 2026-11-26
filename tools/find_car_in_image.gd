# tools/find_car_in_image.gd
extends SceneTree

func _init() -> void:
	var path := "build/screenshots/audit/01_hub_starting_grid_gtr.png"
	var img := Image.load_from_file(path)
	if not img:
		print("Could not load image")
		quit(1)
		return
	var w := img.get_width()
	var h := img.get_height()
	print("Scanning image ", w, "x", h)
	var min_x := 9999
	var max_x := -1
	var min_y := 9999
	var max_y := -1
	var diff_count := 0
	# Asphalt is roughly R: 0.35-0.45, G: 0.35-0.45, B: 0.15-0.30
	# Sky is R: 0.45-0.65, G: 0.60-0.75, B: 0.85-1.0
	for y in range(h):
		for x in range(w):
			var p := img.get_pixel(x, y)
			# Look for dark/black (tires/carbon) or bright metallic or saturated colors
			# Or anything with high saturation or very low brightness (< 0.15)
			var max_c = maxf(p.r, maxf(p.g, p.b))
			var min_c = minf(p.r, minf(p.g, p.b))
			var sat = (max_c - min_c) / max_c if max_c > 0.001 else 0.0
			var lum = 0.2126 * p.r + 0.7152 * p.g + 0.0722 * p.b
			
			if lum < 0.12 or sat > 0.45 or (p.r > 0.7 and p.b < 0.3):
				diff_count += 1
				min_x = mini(min_x, x)
				max_x = maxi(max_x, x)
				min_y = mini(min_y, y)
				max_y = maxi(max_y, y)
				
	print("Found %d distinct car/object pixels" % diff_count)
	if diff_count > 0:
		print("Bounding box: X [%d..%d] (w=%d), Y [%d..%d] (h=%d)" % [min_x, max_x, max_x - min_x, min_y, max_y, max_y - min_y])
		# Sample a few pixels inside bounding box
		for sy in range(min_y, max_y, maxi(1, (max_y - min_y) / 5)):
			print("   Sample at y=%d: " % sy, img.get_pixel((min_x + max_x) / 2, sy))
	quit(0)
