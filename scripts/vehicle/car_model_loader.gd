# scripts/vehicle/car_model_loader.gd
# Dedicated multi-model loader, wheel binding, and Forza Horizon 5 PBR material pipeline.
class_name CarModelLoader
extends RefCounted

const ProceduralCarMesh = preload("res://scripts/vehicle/procedural_car_mesh.gd")
const RaycastWheel = preload("res://scripts/vehicle/raycast_wheel.gd")

static func load_car_visuals(controller: RigidBody3D, recipe: Dictionary) -> Node3D:
	var glb_path := "res://assets/models/cars/CarConcept.glb"
	if recipe.has("model_path") and FileAccess.file_exists(recipe.model_path):
		glb_path = recipe.model_path
		
	var loaded_model: Node3D = null
	if FileAccess.file_exists(glb_path):
		var gltf := GLTFDocument.new()
		var state := GLTFState.new()
		var err := gltf.append_from_file(glb_path, state)
		if err == OK:
			loaded_model = gltf.generate_scene(state) as Node3D
			
	if not loaded_model:
		var proc := ProceduralCarMesh.new()
		var mesh_inst: Node3D = proc.build_car(recipe)
		controller.add_child(mesh_inst)
		_bind_model_wheels(controller, proc, glb_path)
		_setup_car_reflection_probe(controller)
		return mesh_inst
		
	# Apply model-specific rotation and scaling to align forward with -Z
	if "mustang_gt" in glb_path.to_lower():
		loaded_model.rotation.y = PI * 0.5
		loaded_model.scale = Vector3.ONE
	elif "aventador" in glb_path.to_lower():
		loaded_model.rotation.y = -PI * 0.5
		loaded_model.scale = Vector3(0.175, 0.175, 0.175)
	elif "nissan_gtr" in glb_path.to_lower():
		loaded_model.rotation.y = PI
		loaded_model.scale = Vector3.ONE
	elif "mclaren_p1" in glb_path.to_lower():
		loaded_model.rotation.y = PI
		loaded_model.scale = Vector3(0.0225, 0.0225, 0.0225)
	elif "porsche_911" in glb_path.to_lower():
		loaded_model.rotation.y = PI
		loaded_model.scale = Vector3(0.0145, 0.0145, 0.0145)
	elif "countach" in glb_path.to_lower():
		loaded_model.rotation.y = PI
		loaded_model.scale = Vector3(0.5, 0.5, 0.5)
	elif "carconcept" in glb_path.to_lower():
		loaded_model.rotation.y = PI
		loaded_model.scale = Vector3.ONE
	else:
		loaded_model.rotation.y = PI
		loaded_model.scale = Vector3.ONE
		
	controller.add_child(loaded_model)
	_bind_model_wheels(controller, loaded_model, glb_path)
	_apply_fh5_car_materials(loaded_model, glb_path)
	_setup_car_reflection_probe(controller)
	return loaded_model

static func _setup_car_reflection_probe(controller: RigidBody3D) -> void:
	var existing = controller.get_node_or_null("CarDynamicReflectionProbe")
	if not existing:
		var probe := ReflectionProbe.new()
		probe.name = "CarDynamicReflectionProbe"
		probe.update_mode = ReflectionProbe.UPDATE_ALWAYS
		probe.size = Vector3(32.0, 16.0, 32.0)
		probe.origin_offset = Vector3(0.0, 1.2, 0.0)
		probe.max_distance = 64.0
		probe.enable_shadows = false
		probe.position = Vector3(0.0, 0.8, 0.0)
		controller.add_child(probe)

static func _bind_model_wheels(controller: RigidBody3D, root: Node3D, glb_path: String) -> void:
	var fl: Node3D = null
	var fr: Node3D = null
	var rl: Node3D = null
	var rr: Node3D = null
	var rot_l := Vector3.ZERO
	var rot_r := Vector3.ZERO
	var offset_l := Vector3.ZERO
	var offset_r := Vector3.ZERO
	var base_scale := Vector3.ONE
	
	var path_low := glb_path.to_lower()
	if "mustang_gt" in path_low:
		fl = _find_child_recursive(root, ["wheel0"])
		fr = _find_child_recursive(root, ["wheel2"])
		rl = _find_child_recursive(root, ["wheel1"])
		rr = _find_child_recursive(root, ["wheel3"])
		rot_l = Vector3(0.0, -PI * 0.5, 0.0)
		rot_r = Vector3(0.0, PI * 0.5, 0.0)
		offset_r = Vector3(-0.11, 0.0, 0.0)
		base_scale = Vector3.ONE
	elif "aventador" in path_low:
		fl = _find_child_recursive(root, ["Obj_WheelHub_FL"])
		fr = _find_child_recursive(root, ["Obj_WheelHub_FR"])
		rl = _find_child_recursive(root, ["Obj_WheelHub_RL"])
		rr = _find_child_recursive(root, ["Obj_WheelHub_RR"])
		rot_l = Vector3(0.0, PI * 0.5, 0.0)
		rot_r = Vector3(0.0, -PI * 0.5, 0.0)
		base_scale = Vector3(0.175, 0.175, 0.175)
	elif "nissan_gtr" in path_low:
		fl = _find_child_recursive(root, ["3DWheel Front L_60", "3DWheel Front L"])
		fr = _find_child_recursive(root, ["3DWheel Front R_173", "3DWheel Front R"])
		rl = _find_child_recursive(root, ["3DWheel Rear L_286", "3DWheel Rear L"])
		rr = _find_child_recursive(root, ["3DWheel Rear R_403", "3DWheel Rear R"])
		rot_l = Vector3.ZERO
		rot_r = Vector3.ZERO
		base_scale = Vector3.ONE
	elif "mclaren_p1" in path_low:
		fl = _find_child_recursive(root, ["WHEEL_LF"])
		fr = _find_child_recursive(root, ["WHEEL_RF"])
		rl = _find_child_recursive(root, ["WHEEL_LR"])
		rr = _find_child_recursive(root, ["WHEEL_RR"])
		rot_l = Vector3.ZERO
		rot_r = Vector3(0.0, PI, 0.0)
		base_scale = Vector3(0.0225, 0.0225, 0.0225)
	else:
		fl = _find_child_recursive(root, ["WheelFrontL", "wheel_FL", "Wheel_FL"])
		fr = _find_child_recursive(root, ["WheelFrontR", "wheel_FR", "Wheel_FR"])
		rl = _find_child_recursive(root, ["WheelRearL", "wheel_RL", "Wheel_RL"])
		rr = _find_child_recursive(root, ["WheelRearR", "wheel_RR", "Wheel_RR"])
		rot_l = Vector3.ZERO
		rot_r = Vector3.ZERO
		base_scale = Vector3.ONE
		
	if "front_left_wheel" in controller and controller.front_left_wheel and fl:
		_attach_wheel_visual(controller.front_left_wheel, fl, rot_l, base_scale, offset_l)
	if "front_right_wheel" in controller and controller.front_right_wheel and fr:
		_attach_wheel_visual(controller.front_right_wheel, fr, rot_r, base_scale, offset_r)
	if "rear_left_wheel" in controller and controller.rear_left_wheel and rl:
		_attach_wheel_visual(controller.rear_left_wheel, rl, rot_l, base_scale, offset_l)
	if "rear_right_wheel" in controller and controller.rear_right_wheel and rr:
		_attach_wheel_visual(controller.rear_right_wheel, rr, rot_r, base_scale, offset_r)

static func _attach_wheel_visual(wheel: RaycastWheel, visual_node: Node3D, base_rot: Vector3 = Vector3.ZERO, base_scale: Vector3 = Vector3.ONE, offset: Vector3 = Vector3.ZERO) -> void:
	visual_node.owner = null
	if visual_node.get_parent():
		visual_node.get_parent().remove_child(visual_node)
		
	var pivot := Node3D.new()
	pivot.name = "WheelPivot"
	wheel.add_child(pivot)
	pivot.position = offset
	pivot.rotation = Vector3.ZERO
	
	pivot.add_child(visual_node)
	visual_node.position = Vector3.ZERO
	visual_node.rotation = base_rot
	visual_node.scale = base_scale
	
	wheel.wheel_visual = pivot

static func _find_child_recursive(node: Node, names: Array[String]) -> Node3D:
	for n in names:
		if node.name.nocasecmp_to(n) == 0:
			return node as Node3D
	for child in node.get_children():
		var res := _find_child_recursive(child, names)
		if res:
			return res
	return null

static func _apply_fh5_car_materials(root: Node, glb_path: String) -> void:
	var path_low := glb_path.to_lower()
	
	# Base Car Paint Color
	var paint_color := Color(0.82, 0.08, 0.06) # Default Rosso Corsa
	if "mustang" in path_low:
		paint_color = Color(0.08, 0.28, 0.78) # Radiant Velocity Blue Metallic
	elif "aventador" in path_low:
		paint_color = Color(0.95, 0.72, 0.05) # Giallo Orion Pearl Yellow
	elif "nissan_gtr" in path_low:
		paint_color = Color(0.10, 0.14, 0.42) # Bayside Midnight Blue Metallic
	elif "mclaren_p1" in path_low:
		paint_color = Color(0.95, 0.38, 0.04) # Volcano Papaya Orange Pearl
	elif "porsche" in path_low:
		paint_color = Color(0.86, 0.08, 0.05) # Guards Red Gloss
		
	# Forza Horizon 5 Multi-Layer Clearcoat Material
	var paint_mat := StandardMaterial3D.new()
	paint_mat.albedo_color = paint_color
	paint_mat.metallic = 0.88
	paint_mat.roughness = 0.14
	paint_mat.clearcoat_enabled = true
	paint_mat.clearcoat = 1.0
	paint_mat.clearcoat_roughness = 0.03
	
	# Smoked Tinted Automotive Glass
	var glass_mat := StandardMaterial3D.new()
	glass_mat.albedo_color = Color(0.05, 0.07, 0.10, 0.65)
	glass_mat.metallic = 0.0
	glass_mat.roughness = 0.03
	glass_mat.clearcoat_enabled = true
	glass_mat.clearcoat = 1.0
	glass_mat.clearcoat_roughness = 0.02
	glass_mat.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
	
	# Matte Rubber Gaskets & Wipers
	var rubber_mat := StandardMaterial3D.new()
	rubber_mat.albedo_color = Color(0.06, 0.06, 0.07)
	rubber_mat.metallic = 0.0
	rubber_mat.roughness = 0.85
	
	# High-Intensity Projector Xenon Headlights
	var headlight_mat := StandardMaterial3D.new()
	headlight_mat.albedo_color = Color(0.95, 0.98, 1.0)
	headlight_mat.emission_enabled = true
	headlight_mat.emission = Color(1.2, 1.35, 1.6)
	headlight_mat.emission_energy_multiplier = 1.8
	
	# Radiant Neon Taillights
	var taillight_mat := StandardMaterial3D.new()
	taillight_mat.albedo_color = Color(0.85, 0.04, 0.02)
	taillight_mat.emission_enabled = true
	taillight_mat.emission = Color(1.4, 0.05, 0.02)
	taillight_mat.emission_energy_multiplier = 2.0
	
	# Carbon Fiber Aero & Underside
	var carbon_mat := StandardMaterial3D.new()
	carbon_mat.albedo_color = Color(0.10, 0.10, 0.11)
	carbon_mat.metallic = 0.30
	carbon_mat.roughness = 0.30
	
	# Forged Gunmetal Rims
	var rim_mat := StandardMaterial3D.new()
	rim_mat.albedo_color = Color(0.30, 0.32, 0.35)
	rim_mat.metallic = 0.92
	rim_mat.roughness = 0.16
	
	# Carbon-Ceramic Perforated Brake Discs
	var disc_mat := StandardMaterial3D.new()
	disc_mat.albedo_color = Color(0.55, 0.56, 0.58)
	disc_mat.metallic = 0.95
	disc_mat.roughness = 0.22
	
	# Racing Calipers (Red for Mustang/CarConcept, Yellow for Lambo)
	var caliper_mat := StandardMaterial3D.new()
	caliper_mat.albedo_color = Color(0.92, 0.70, 0.05) if "aventador" in path_low else Color(0.85, 0.06, 0.04)
	caliper_mat.metallic = 0.45
	caliper_mat.roughness = 0.20
	
	# Semi-Slick Vulcanized Tires
	var tire_mat := StandardMaterial3D.new()
	tire_mat.albedo_color = Color(0.08, 0.08, 0.09)
	tire_mat.metallic = 0.0
	tire_mat.roughness = 0.88
	
	_assign_materials_recursive(root, paint_mat, glass_mat, rubber_mat, headlight_mat, taillight_mat, carbon_mat, rim_mat, disc_mat, caliper_mat, tire_mat)

static func _assign_materials_recursive(node: Node, paint: Material, glass: Material, rubber: Material, hl: Material, tl: Material, carbon: Material, rim: Material, disc: Material, cal: Material, tire: Material) -> void:
	if node is MeshInstance3D:
		var n_lower := node.name.to_lower()
		if "windshield" in n_lower or "window" in n_lower or "glass" in n_lower or "windscreen" in n_lower:
			node.material_override = glass
		elif "headlight" in n_lower or "lamp" in n_lower:
			node.material_override = hl
		elif "taillight" in n_lower or "turnsignal" in n_lower or "tail_led" in n_lower or "tail_light" in n_lower:
			node.material_override = tl
		elif "rim" in n_lower or "wheelhub" in n_lower or "chrome" in n_lower:
			node.material_override = rim
		elif "brakepad" in n_lower or "caliper" in n_lower:
			node.material_override = cal
		elif "rotor" in n_lower or "discrotor" in n_lower or "brakedisc" in n_lower:
			node.material_override = disc
		elif "tyre" in n_lower or "tire" in n_lower or ("mesh" in n_lower and "wheel" in node.get_parent().name.to_lower()):
			node.material_override = tire
		elif "diffuser" in n_lower or "spoiler" in n_lower or "skirt" in n_lower or "underbody" in n_lower or "color2" in n_lower or "matte" in n_lower:
			node.material_override = carbon
		elif "color1" in n_lower or "paint" in n_lower or "hood" in n_lower or "door" in n_lower or "bumper" in n_lower or "boot" in n_lower or "fender" in n_lower:
			node.material_override = paint
			
	for child in node.get_children():
		_assign_materials_recursive(child, paint, glass, rubber, hl, tl, carbon, rim, disc, cal, tire)
