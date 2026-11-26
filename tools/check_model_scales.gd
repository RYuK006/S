# tools/check_model_scales.gd
extends SceneTree

func _init() -> void:
	var models = [
		"res://assets/models/cars/nissan_gtr_r35.glb",
		"res://assets/models/cars/mclaren_p1.glb",
		"res://assets/models/cars/porsche_911_turbo.glb"
	]
	for m_path in models:
		var gltf := GLTFDocument.new()
		var state := GLTFState.new()
		var err := gltf.append_from_file(m_path, state)
		if err == OK:
			var scene := gltf.generate_scene(state)
			print("--- Model: ", m_path)
			print("  scene scale: ", scene.scale)
			for c in scene.get_children():
				print("    child: ", c.name, " scale: ", c.scale)
				for cc in c.get_children():
					print("      grandchild: ", cc.name, " scale: ", cc.scale)
	quit(0)
