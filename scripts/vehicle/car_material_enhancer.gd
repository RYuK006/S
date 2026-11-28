# scripts/vehicle/car_material_enhancer.gd
# Forza Horizon 5 clearcoat PBR car paint, wheel tire calibration, carbon fiber, emissive lights, and reflection probe setup.
class_name CarMaterialEnhancer
extends RefCounted

static func setup_car_reflection_probe(controller: Node3D) -> void:
	if not controller.get_node_or_null("CarDynamicReflectionProbe"):
		var probe := ReflectionProbe.new()
		probe.name = "CarDynamicReflectionProbe"
		probe.update_mode = ReflectionProbe.UPDATE_ONCE
		probe.intensity = 0.80
		probe.ambient_mode = ReflectionProbe.AMBIENT_DISABLED
		probe.size = Vector3(5.2, 2.4, 6.0)
		probe.origin_offset = Vector3(0.0, 0.0, 0.0)
		probe.max_distance = 48.0
		probe.enable_shadows = false
		probe.position = Vector3(0.0, 1.45, 0.0)
		controller.add_child(probe)

static func apply_custom_paint(root: Node, custom_paint: Color, finish: String = "metallic") -> void:
	var seen: Dictionary = {}
	_apply_custom_paint_recursive(root, custom_paint, finish, seen)

static func _apply_custom_paint_recursive(node: Node, custom_paint: Color, finish: String, seen: Dictionary) -> void:
	if node is MeshInstance3D:
		var mi: MeshInstance3D = node
		if mi.mesh:
			for s: int in range(mi.mesh.get_surface_count()):
				var mat: Material = mi.get_active_material(s)
				if mat is StandardMaterial3D:
					var std: StandardMaterial3D = mat
					var rid: int = std.get_instance_id()
					if seen.has(rid):
						continue
					seen[rid] = true
					var rname: String = std.resource_name.to_lower()
					var is_secondary: bool = ("black" in rname or rname.ends_with("2") or "paint2" in rname or "coat2" in rname or "interior" in rname or "glass" in rname or "tire" in rname or "tyre" in rname or "rim" in rname or "brake" in rname or "caliper" in rname or "carbon" in rname or "chrome" in rname)
					if is_secondary:
						continue
					var is_body: bool = ("paint" in rname or "coat" in rname or "scocca" in rname or "coloured" in rname or "body" in rname or "livery" in rname or rname == "mt_body" or rname == "mt_mirrorcover" or rname == "material.008")
					if is_body:
						if std.albedo_texture == null:
							std.albedo_color = custom_paint
						match finish:
							"metallic":
								std.metallic = 0.85
								std.roughness = 0.14
								std.clearcoat_enabled = true
								std.clearcoat = 1.0
								std.clearcoat_roughness = 0.03
							"gloss":
								std.metallic = 0.15
								std.roughness = 0.08
								std.clearcoat_enabled = true
								std.clearcoat = 0.90
								std.clearcoat_roughness = 0.02
							"matte":
								std.metallic = 0.05
								std.roughness = 0.68
								std.clearcoat_enabled = false
								std.clearcoat = 0.0
							"satin":
								std.metallic = 0.45
								std.roughness = 0.34
								std.clearcoat_enabled = true
								std.clearcoat = 0.40
								std.clearcoat_roughness = 0.15
							"pearl":
								std.metallic = 0.72
								std.roughness = 0.15
								std.clearcoat_enabled = true
								std.clearcoat = 1.0
								std.clearcoat_roughness = 0.03
	for c: Node in node.get_children():
		_apply_custom_paint_recursive(c, custom_paint, finish, seen)

static func apply_fh5_car_materials(root: Node, path_low: String) -> void:
	var custom_paint: Color = Color(-1, 0, 0)
	if "nissan_gtr" in path_low:
		custom_paint = Color(0.04, 0.14, 0.48)
	elif "mclaren_p1" in path_low:
		custom_paint = Color(0.95, 0.34, 0.03)
	elif "porsche_911" in path_low:
		custom_paint = Color(0.78, 0.05, 0.04)
	elif "aventador" in path_low:
		custom_paint = Color(0.94, 0.68, 0.04)
	elif "ferrari_488" in path_low:
		custom_paint = Color(0.76, 0.02, 0.03)
	elif "mustang_gt" in path_low:
		custom_paint = Color(0.06, 0.25, 0.72)

	var processed_mats: Dictionary = {}
	_enhance_materials_recursive(root, custom_paint, path_low, processed_mats)

static func _enhance_materials_recursive(node: Node, custom_paint: Color, path_low: String, seen: Dictionary) -> void:
	if node is MeshInstance3D:
		var mi: MeshInstance3D = node
		if mi.mesh:
			for s in range(mi.mesh.get_surface_count()):
				var mat: Material = mi.get_active_material(s)
				if mat is StandardMaterial3D:
					var std: StandardMaterial3D = mat
					var rid: int = std.get_instance_id()
					if seen.has(rid):
						continue
					seen[rid] = true
					var rname: String = std.resource_name.to_lower()
					var has_tex: bool = std.albedo_texture != null

					var is_secondary: bool = ("black" in rname or rname.ends_with("2") or "paint2" in rname or "coat2" in rname)
					if not has_tex and ("paint" in rname or "coat" in rname or "scocca" in rname or "coloured" in rname or "carbody" in rname or rname == "mt_body" or rname == "mt_mirrorcover"):
						if custom_paint.r >= 0.0 and not is_secondary:
							std.albedo_color = custom_paint
						std.metallic = maxf(std.metallic, 0.74)
						std.roughness = minf(maxf(std.roughness, 0.14), 0.24)
						std.clearcoat_enabled = true
						std.clearcoat = 1.0
						std.clearcoat_roughness = 0.03
					elif "countach" in path_low and rname == "material.008":
						std.albedo_color = Color(0.84, 0.85, 0.88)
						std.metallic = 0.35
						std.roughness = 0.16
						std.clearcoat_enabled = true
						std.clearcoat = 1.0
						std.clearcoat_roughness = 0.03
					elif "undercarriage" in rname:
						std.albedo_color = Color(0.08, 0.08, 0.09)
						std.roughness = 0.88
						std.metallic = 0.05
					elif has_tex and ("coat" in rname or "body" in rname or "livery" in rname or "texturede" in rname):
						if "texturede" in rname:
							std.metallic = 0.45
							std.roughness = 0.22
						std.clearcoat_enabled = true
						std.clearcoat = 0.90
						std.clearcoat_roughness = 0.04
					elif "glass" in rname or "windscreen" in rname or "windshield" in rname or "window" in rname or "cristal" in rname or "lunas" in rname:
						std.clearcoat_enabled = true
						std.clearcoat = 1.0
						std.clearcoat_roughness = 0.02
						std.roughness = 0.03
					elif "sasasa" in rname or "tyre_side" in rname or "volk" in rname or "material_7" in rname or ("countach" in path_low and rname == "material.025") or (("tyre" in rname or "tire" in rname) and ("ferrari" in path_low or "mclaren" in path_low)):
						std.albedo_texture = null
						std.normal_enabled = false
						std.albedo_color = Color(0.06, 0.06, 0.065)
						std.roughness = 0.88
						std.metallic = 0.0
						std.metallic_specular = 0.22
					elif "carbon" in rname:
						std.albedo_color = Color(0.09, 0.09, 0.10)
						std.metallic = 0.25
						std.roughness = 0.22
						std.clearcoat_enabled = true
						std.clearcoat = 0.65
						std.clearcoat_roughness = 0.08
					elif ("taillight" in rname or "brakelight" in rname or "redlight" in rname or "led_rojo" in rname or "reflector_tl" in rname or "reflector_bl" in rname) and not has_tex:
						std.emission_enabled = true
						std.emission = Color(0.95, 0.04, 0.02)
						std.emission_energy_multiplier = 1.8
					elif ("headlight" in rname or "light_emissive" in rname) and not has_tex and not ("glass" in rname):
						std.emission_enabled = true
						std.emission = Color(1.0, 0.96, 0.90)
						std.emission_energy_multiplier = 1.4
	for c in node.get_children():
		_enhance_materials_recursive(c, custom_paint, path_low, seen)
