# tools/test_prop_details.gd
extends SceneTree

func _init() -> void:
	var props = [
		"res://assets/models/props/highway_guardrail.glb",
		"res://assets/models/props/street_lamp_post.glb",
		"res://assets/models/props/traffic_barriers_cones.glb"
	]
	for p in props:
		var scn = load(p) as PackedScene
		if scn:
			var inst = scn.instantiate()
			print("Loaded: ", p)
			_inspect(inst, "")
			inst.free()
	quit(0)

func _inspect(n: Node, ind: String) -> void:
	if n is MeshInstance3D and n.mesh:
		print(ind, n.name, " AABB: ", n.mesh.get_aabb(), " mat: ", n.get_active_material(0))
	for c in n.get_children():
		_inspect(c, ind + "  ")
