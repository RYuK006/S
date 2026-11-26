# tools/inspect_all_props.gd
extends SceneTree

func _init() -> void:
	var props := [
		"res://assets/models/props/highway_guardrail.glb",
		"res://assets/models/props/street_lamp_post.glb",
		"res://assets/models/props/traffic_barriers_cones.glb",
		"res://assets/models/props/cliff_rock/scene.gltf"
	]
	for p in props:
		print("=== PROBING GLTF: ", p)
		var gltf := GLTFDocument.new()
		var state := GLTFState.new()
		var err := gltf.append_from_file(p, state)
		if err == OK:
			var scene := gltf.generate_scene(state)
			_inspect_node(scene, "")
			scene.free()
		else:
			print("GLTF failed: ", err)
	quit(0)

func _inspect_node(n: Node, indent: String) -> void:
	var extra := ""
	if n is MeshInstance3D:
		var aabb: AABB = n.get_aabb() if n.mesh else AABB()
		extra = " [Mesh: " + str(n.mesh.get_class() if n.mesh else "null") + " AABB: " + str(aabb) + "]"
	print(indent, n.name, " (", n.get_class(), ")", extra)
	for c in n.get_children():
		_inspect_node(c, indent + "  ")
