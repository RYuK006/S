# scripts/vehicle/car_model_loader.gd
# Generalized multi-model loader, spatial/quadrant wheel hub binder, and FH5 clearcoat PBR material pipeline.
class_name CarModelLoader
extends RefCounted

const ProceduralCarMesh = preload("res://scripts/vehicle/procedural_car_mesh.gd")
const RaycastWheel = preload("res://scripts/vehicle/raycast_wheel.gd")

static func load_car_visuals(controller: Node3D, recipe: Dictionary) -> Node3D:
	var glb_path: String = "res://assets/models/cars/subaru_sti.glb"
	if recipe.has("model_path") and FileAccess.file_exists(str(recipe.model_path)):
		glb_path = str(recipe.model_path)

	var loaded_model: Node3D = null
	if ResourceLoader.exists(glb_path):
		var packed_car: Resource = load(glb_path)
		if packed_car is PackedScene:
			loaded_model = packed_car.instantiate() as Node3D
	if not loaded_model and FileAccess.file_exists(glb_path):
		var gltf := GLTFDocument.new()
		var state := GLTFState.new()
		if gltf.append_from_file(glb_path, state) == OK:
			loaded_model = gltf.generate_scene(state) as Node3D

	if not loaded_model:
		var proc := ProceduralCarMesh.new()
		var mesh_inst: Node3D = proc.build_car(recipe)
		controller.add_child(mesh_inst)
		_setup_car_reflection_probe(controller)
		return mesh_inst

	var path_low: String = glb_path.to_lower()
	var holder := Node3D.new()
	holder.name = "CarVisualHolder"
	controller.add_child(holder)
	holder.add_child(loaded_model)

	# 1. Strip baked shadow planes / studio floors before measuring AABB
	_strip_studio_artifacts(loaded_model, path_low)

	# 2. Orient model front toward -Z and normalize horizontal length
	var spec: Dictionary = _get_model_spec(path_low)
	loaded_model.rotation.y = float(spec.get("rot_y", PI))
	var target_len: float = float(spec.get("target_len", 4.65))

	var body_aabb: AABB = _calc_hierarchy_aabb(holder, loaded_model, Transform3D.IDENTITY)
	var max_horiz: float = maxf(body_aabb.size.x, body_aabb.size.z)
	if "mclaren" in path_low:
		max_horiz = body_aabb.size.z
	if max_horiz > 0.0001:
		var s: float = target_len / max_horiz
		loaded_model.scale = Vector3(s, s, s)

	var scaled_aabb: AABB = _calc_hierarchy_aabb(holder, loaded_model, Transform3D.IDENTITY)
	var ctr: Vector3 = scaled_aabb.get_center()
	loaded_model.position -= Vector3(ctr.x, scaled_aabb.position.y, ctr.z)

	# 3. Spatial + quadrant-split wheel binding with outlier-resistant radius & vertex straightening
	_bind_spatial_wheels(controller, holder, loaded_model, path_low)

	# 4. Selective Forza Horizon 5 PBR Paint, Rubber & Light enhancements across body + wheels
	_apply_fh5_car_materials(controller, path_low)
	_setup_car_reflection_probe(controller)
	return holder

static func _get_model_spec(path_low: String) -> Dictionary:
	if "ford_bronco" in path_low:
		return {"rot_y": PI, "target_len": 4.42}
	if "ford_raptor" in path_low:
		return {"rot_y": 0.0, "target_len": 5.38}
	if "subaru_sti" in path_low:
		return {"rot_y": PI, "target_len": 4.46}
	if "dodge_challenger" in path_low:
		return {"rot_y": PI, "target_len": 4.95}
	if "ferrari_488" in path_low:
		return {"rot_y": PI * 0.5, "target_len": 4.65}
	if "nissan_gtr" in path_low:
		return {"rot_y": PI, "target_len": 4.72}
	if "mclaren_p1" in path_low:
		return {"rot_y": PI, "target_len": 4.59}
	if "porsche_911" in path_low:
		return {"rot_y": PI, "target_len": 4.35}
	if "bmw_m4" in path_low:
		return {"rot_y": PI, "target_len": 4.76}
	if "aventador" in path_low:
		return {"rot_y": -PI * 0.5, "target_len": 4.78}
	if "countach" in path_low:
		return {"rot_y": 0.0, "target_len": 4.80}
	if "mustang_gt" in path_low:
		return {"rot_y": PI * 0.5, "target_len": 4.78}
	return {"rot_y": PI, "target_len": 4.65}

static func _strip_studio_artifacts(node: Node, path_low: String) -> void:
	var to_remove: Array[Node] = []
	for child in node.get_children():
		var nl: String = child.name.to_lower()
		var is_junk: bool = false
		if "shadow_plane" in nl or "clouds" in nl:
			is_junk = true
		elif "dodge_challenger" in path_low and nl == "object_5":
			is_junk = true
		elif "gt_sports" in path_low and "plane" in nl:
			is_junk = true
		elif child is MeshInstance3D:
			var mi: MeshInstance3D = child
			if mi.mesh:
				var aabb: AABB = mi.mesh.get_aabb()
				if aabb.size.y < 0.02 and maxf(aabb.size.x, aabb.size.z) > 8.0 and not ("challenger" in path_low):
					is_junk = true
		if is_junk:
			to_remove.append(child)
		else:
			_strip_studio_artifacts(child, path_low)
	for n in to_remove:
		n.visible = false
		if n.get_parent():
			n.get_parent().remove_child(n)
		n.queue_free()

static func _calc_hierarchy_aabb(space_root: Node3D, node: Node, parent_xform: Transform3D) -> AABB:
	var cur_xform: Transform3D = parent_xform
	if node is Node3D and node != space_root:
		var n3: Node3D = node
		cur_xform = parent_xform * n3.transform
	var total := AABB()
	var has_aabb: bool = false
	if node is MeshInstance3D:
		var mi: MeshInstance3D = node
		if mi.visible and mi.mesh:
			total = cur_xform * mi.mesh.get_aabb()
			has_aabb = true
	for c in node.get_children():
		var sub: AABB = _calc_hierarchy_aabb(space_root, c, cur_xform)
		if sub.size != Vector3.ZERO or sub.position != Vector3.ZERO:
			if has_aabb:
				total = total.merge(sub)
			else:
				total = sub
				has_aabb = true
	return total

static func _bind_spatial_wheels(controller: Node3D, holder: Node3D, loaded_model: Node3D, path_low: String) -> void:
	if not ("front_left_wheel" in controller):
		return
	var corner_meshes: Dictionary = {"FL": [], "FR": [], "RL": [], "RR": []}
	var to_split: Array[Dictionary] = []
	_collect_wheel_meshes(loaded_model, loaded_model.transform, corner_meshes, to_split, path_low)

	for item in to_split:
		_split_mesh_by_quadrants(item["node"], item["holder_xform"], corner_meshes)

	var wheel_map: Dictionary = {
		"FL": controller.get("front_left_wheel"),
		"FR": controller.get("front_right_wheel"),
		"RL": controller.get("rear_left_wheel"),
		"RR": controller.get("rear_right_wheel")
	}

	var corner_aabbs: Dictionary = {}
	var bottoms: Array[float] = []
	var radii: Array[float] = []
	var sum_x: float = 0.0
	var bound_count: int = 0

	for key: String in ["FL", "FR", "RL", "RR"]:
		var list: Array = corner_meshes[key]
		if list.is_empty():
			continue
		var w_aabb := AABB()
		var first: bool = true
		for item in list:
			var mi: MeshInstance3D = item["node"]
			var hx: Transform3D = item["holder_xform"]
			var ma: AABB = _calc_hierarchy_aabb(mi, mi, hx)
			if first:
				w_aabb = ma
				first = false
			else:
				w_aabb = w_aabb.merge(ma)
		corner_aabbs[key] = w_aabb
		bottoms.append(w_aabb.position.y)
		radii.append(clampf(w_aabb.size.y * 0.5, 0.28, 0.54))
		sum_x += w_aabb.get_center().x
		bound_count += 1

	if bound_count == 0:
		return

	# Outlier-resistant ground Y and tire radius across all bound corners
	bottoms.sort()
	radii.sort()
	var tire_ground_y: float = bottoms[int(floorf(float(bottoms.size()) * 0.5))]
	var median_radius: float = radii[int(floorf(float(radii.size()) * 0.5))]
	var mid_wheel_x: float = sum_x / float(bound_count)

	if absf(tire_ground_y) > 0.002 or absf(mid_wheel_x) > 0.01:
		loaded_model.position.y -= tire_ground_y
		loaded_model.position.x -= mid_wheel_x

	for key: String in ["FL", "FR", "RL", "RR"]:
		var list: Array = corner_meshes[key]
		var rw: RaycastWheel = wheel_map.get(key, null) as RaycastWheel
		if list.is_empty() or not rw or not corner_aabbs.has(key):
			continue

		var raw_aabb: AABB = corner_aabbs[key]
		var raw_r: float = clampf(raw_aabb.size.y * 0.5, 0.28, 0.54)
		var wheel_r: float = median_radius if absf(raw_r - median_radius) > median_radius * 0.12 else raw_r

		var hub_center: Vector3 = raw_aabb.get_center()
		hub_center.x -= mid_wheel_x
		hub_center.y = wheel_r + maxf(0.0, raw_aabb.position.y - tire_ground_y)

		rw.position = hub_center
		rw.wheel_radius = wheel_r
		if rw.raycast:
			rw.raycast.target_position = Vector3(0.0, -(rw.rest_length + rw.travel + wheel_r), 0.0)

		var pivot := Node3D.new()
		pivot.name = "WheelPivot_" + key
		rw.add_child(pivot)
		pivot.position = Vector3.ZERO
		pivot.rotation = Vector3.ZERO
		rw.wheel_visual = pivot

		var raw_ctr_shifted := Vector3(raw_aabb.get_center().x - mid_wheel_x, raw_aabb.get_center().y - tire_ground_y, raw_aabb.get_center().z)
		for item in list:
			var mi: MeshInstance3D = item["node"]
			var hx: Transform3D = item["holder_xform"]
			if mi.get_parent():
				mi.owner = null
				mi.get_parent().remove_child(mi)
			pivot.add_child(mi)
			var rel_xform: Transform3D = hx
			rel_xform.origin.x -= mid_wheel_x
			rel_xform.origin.y -= tire_ground_y
			rel_xform.origin -= raw_ctr_shifted
			mi.transform = rel_xform

		# Auto-unbake static steering poses on front wheels using exact vertex X-span minimization
		if key.begins_with("F"):
			_auto_straighten_pivot_vertices(pivot)

static func _auto_straighten_pivot_vertices(pivot: Node3D) -> void:
	var pts: PackedVector3Array = _gather_pivot_vertices(pivot, pivot, Transform3D.IDENTITY)
	if pts.is_empty():
		return
	var init_span: float = _calc_x_span(pts, 0.0)
	if init_span <= 0.45:
		return
	var best_x: float = init_span
	var best_yaw: float = 0.0
	for deg: int in range(-45, 46, 2):
		var rad: float = deg_to_rad(float(deg))
		var sp: float = _calc_x_span(pts, rad)
		if sp < best_x:
			best_x = sp
			best_yaw = rad
	if best_x < init_span * 0.85:
		var rot_b := Basis(Vector3.UP, best_yaw)
		for c in pivot.get_children():
			if c is Node3D:
				var cn: Node3D = c
				cn.transform = Transform3D(rot_b, Vector3.ZERO) * cn.transform

static func _gather_pivot_vertices(root: Node3D, node: Node, parent_xf: Transform3D) -> PackedVector3Array:
	var xf: Transform3D = parent_xf
	if node is Node3D and node != root:
		xf = parent_xf * (node as Node3D).transform
	var out := PackedVector3Array()
	if node is MeshInstance3D:
		var mi: MeshInstance3D = node
		if mi.mesh and mi.mesh.get_surface_count() > 0:
			var arr: Array = mi.mesh.surface_get_arrays(0)
			if arr.size() > Mesh.ARRAY_VERTEX and arr[Mesh.ARRAY_VERTEX] is PackedVector3Array:
				var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
				var step: int = maxi(1, int(floorf(float(v.size()) / 160.0)))
				var i: int = 0
				while i < v.size():
					out.append(xf * v[i])
					i += step
	for c in node.get_children():
		out.append_array(_gather_pivot_vertices(root, c, xf))
	return out

static func _calc_x_span(pts: PackedVector3Array, yaw_rad: float) -> float:
	var cs: float = cos(yaw_rad)
	var sn: float = sin(yaw_rad)
	var min_x: float = 1e9
	var max_x: float = -1e9
	for p: Vector3 in pts:
		var rx: float = p.x * cs + p.z * sn
		if rx < min_x: min_x = rx
		if rx > max_x: max_x = rx
	return max_x - min_x

static func _collect_wheel_meshes(node: Node, cur_xform: Transform3D, corners: Dictionary, to_split: Array[Dictionary], path_low: String) -> void:
	for c in node.get_children():
		var next_xform: Transform3D = cur_xform
		if c is Node3D:
			next_xform = cur_xform * (c as Node3D).transform
		if c is MeshInstance3D:
			var mi: MeshInstance3D = c
			if mi.visible and mi.mesh and _is_wheel_candidate(mi, path_low):
				var ma: AABB = next_xform * mi.mesh.get_aabb()
				var max_d: float = maxf(ma.size.x, maxf(ma.size.y, ma.size.z))
				var ctr: Vector3 = ma.get_center()
				var min_sz: float = 0.28 if ("porsche" in path_low or "countach" in path_low) else 0.04
				if max_d > min_sz and max_d < 1.25 and ma.size.y > 0.20 and ctr.y < 0.85 and absf(ctr.x) > 0.42 and absf(ctr.z) > 0.72:
					var key: String = ("F" if ctr.z < 0.0 else "R") + ("L" if ctr.x < 0.0 else "R")
					corners[key].append({"node": mi, "holder_xform": next_xform})
					continue
				elif not ("countach" in path_low) and (ma.size.x > 1.25 or ma.size.z > 1.60) and ma.size.y > 0.30 and ctr.y < 0.85:
					to_split.append({"node": mi, "holder_xform": next_xform})
					continue
		_collect_wheel_meshes(c, next_xform, corners, to_split, path_low)

static func _split_mesh_by_quadrants(mi: MeshInstance3D, hx: Transform3D, corners: Dictionary) -> void:
	var src_mesh: Mesh = mi.mesh
	if not src_mesh:
		return
	var quad_meshes: Dictionary = {"FL": ArrayMesh.new(), "FR": ArrayMesh.new(), "RL": ArrayMesh.new(), "RR": ArrayMesh.new(), "CENTER": ArrayMesh.new()}
	var quad_mats: Dictionary = {"FL": [], "FR": [], "RL": [], "RR": [], "CENTER": []}

	for s: int in range(src_mesh.get_surface_count()):
		var arrays: Array = src_mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		if verts.is_empty():
			continue
		var has_n: bool = arrays[Mesh.ARRAY_NORMAL] is PackedVector3Array and (arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array).size() == verts.size()
		var has_u: bool = arrays[Mesh.ARRAY_TEX_UV] is PackedVector2Array and (arrays[Mesh.ARRAY_TEX_UV] as PackedVector2Array).size() == verts.size()
		var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if has_n else PackedVector3Array()
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if has_u else PackedVector2Array()
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] is PackedInt32Array else PackedInt32Array()

		var tri_count: int = int(idx.size() / 3.0) if not idx.is_empty() else int(verts.size() / 3.0)
		var b_v: Dictionary = {"FL": PackedVector3Array(), "FR": PackedVector3Array(), "RL": PackedVector3Array(), "RR": PackedVector3Array(), "CENTER": PackedVector3Array()}
		var b_n: Dictionary = {"FL": PackedVector3Array(), "FR": PackedVector3Array(), "RL": PackedVector3Array(), "RR": PackedVector3Array(), "CENTER": PackedVector3Array()}
		var b_u: Dictionary = {"FL": PackedVector2Array(), "FR": PackedVector2Array(), "RL": PackedVector2Array(), "RR": PackedVector2Array(), "CENTER": PackedVector2Array()}

		for t: int in range(tri_count):
			var i0: int = idx[t * 3] if not idx.is_empty() else t * 3
			var i1: int = idx[t * 3 + 1] if not idx.is_empty() else t * 3 + 1
			var i2: int = idx[t * 3 + 2] if not idx.is_empty() else t * 3 + 2
			var c_world: Vector3 = hx * ((verts[i0] + verts[i1] + verts[i2]) / 3.0)
			var q: String = "CENTER"
			if absf(c_world.x) > 0.48 and absf(c_world.z) > 0.65 and c_world.y < 0.85:
				q = ("F" if c_world.z < 0.0 else "R") + ("L" if c_world.x < 0.0 else "R")
			b_v[q].append(verts[i0]); b_v[q].append(verts[i1]); b_v[q].append(verts[i2])
			if has_n:
				b_n[q].append(norms[i0]); b_n[q].append(norms[i1]); b_n[q].append(norms[i2])
			if has_u:
				b_u[q].append(uvs[i0]); b_u[q].append(uvs[i1]); b_u[q].append(uvs[i2])

		var mat: Material = mi.get_active_material(s)
		for q: String in ["FL", "FR", "RL", "RR", "CENTER"]:
			var qv: PackedVector3Array = b_v[q]
			if qv.is_empty():
				continue
			var out_arr: Array = []
			out_arr.resize(Mesh.ARRAY_MAX)
			out_arr[Mesh.ARRAY_VERTEX] = qv
			if has_n: out_arr[Mesh.ARRAY_NORMAL] = b_n[q]
			if has_u: out_arr[Mesh.ARRAY_TEX_UV] = b_u[q]
			(quad_meshes[q] as ArrayMesh).add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out_arr)
			quad_mats[q].append(mat)

	var par: Node = mi.get_parent()
	for q: String in ["FL", "FR", "RL", "RR"]:
		var qm: ArrayMesh = quad_meshes[q]
		if qm.get_surface_count() > 0:
			var sub := MeshInstance3D.new()
			sub.name = mi.name + "_" + q
			sub.mesh = qm
			var mats: Array = quad_mats[q]
			for s_idx: int in range(mats.size()):
				sub.set_surface_override_material(s_idx, mats[s_idx] as Material)
			par.add_child(sub)
			corners[q].append({"node": sub, "holder_xform": hx})

	var cm: ArrayMesh = quad_meshes["CENTER"]
	if cm.get_surface_count() > 0:
		mi.mesh = cm
		var cmats: Array = quad_mats["CENTER"]
		for s_idx: int in range(cmats.size()):
			mi.set_surface_override_material(s_idx, cmats[s_idx] as Material)
	else:
		mi.visible = false

static func _is_wheel_candidate(mi: MeshInstance3D, path_low: String) -> bool:
	var combined: String = mi.name.to_lower()
	var mats_low: String = ""
	var p: Node = mi.get_parent()
	for _depth in range(3):
		if not p:
			break
		combined += " " + p.name.to_lower()
		p = p.get_parent()
	if mi.mesh:
		for s in range(mi.mesh.get_surface_count()):
			var mat: Material = mi.get_active_material(s)
			if mat and mat.resource_name:
				var rl: String = mat.resource_name.to_lower()
				combined += " " + rl
				mats_low += " " + rl
	if "steering" in combined or "caliper" in combined or "calliper" in combined or "brake" in combined or "disc" in combined or "rotor" in combined or "__paint_2_" in combined:
		return false
	if "porsche" in path_low and "circle_048" in combined:
		return false
	# Challenger: ONLY Material__301 (full wheels/tires; avoids Object_23 chrome trunk strip)
	if "dodge_challenger" in path_low and "material__301" in mats_low:
		return true
	if "countach" in path_low and ("material.025" in mats_low or "material.011" in mats_low):
		return true
	if "bmw_m4" in path_low and "meshesm8rim" in mats_low:
		return true
	return ("wheel" in combined or "rim" in combined or "tyre" in combined or "tire" in combined or "matte2" in combined or "matte3" in combined or "matte4" in combined or "matte5" in combined or "metal2" in combined or "metal3" in combined or "metal4" in combined or "metal5" in combined or "930_rim" in combined or "930_tire" in combined or "tyrewallblack" in combined)

static func _setup_car_reflection_probe(controller: Node3D) -> void:
	if not controller.get_node_or_null("CarDynamicReflectionProbe"):
		var probe := ReflectionProbe.new()
		probe.name = "CarDynamicReflectionProbe"
		# Bake sky + local biome cubemap once on spawn/biome change instead of re-rendering 6 faces every frame
		probe.update_mode = ReflectionProbe.UPDATE_ONCE
		probe.intensity = 0.80
		probe.ambient_mode = ReflectionProbe.AMBIENT_DISABLED
		# Bottom at 1.45 - 1.20 = +0.25m above ground so probe NEVER creates dark square shadows on terrain
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

static func _apply_fh5_car_materials(root: Node, path_low: String) -> void:
	var custom_paint: Color = Color(-1, 0, 0)
	if "nissan_gtr" in path_low:
		custom_paint = Color(0.04, 0.14, 0.48) # Bayside Midnight Blue Metallic
	elif "mclaren_p1" in path_low:
		custom_paint = Color(0.95, 0.34, 0.03) # Volcano Papaya Orange
	elif "porsche_911" in path_low:
		custom_paint = Color(0.78, 0.05, 0.04) # Guards Red
	elif "aventador" in path_low:
		custom_paint = Color(0.94, 0.68, 0.04) # Giallo Orion
	elif "ferrari_488" in path_low:
		custom_paint = Color(0.76, 0.02, 0.03) # Rosso Corsa
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
					if not has_tex and ("paint" in rname or "coat" in rname or "scocca" in rname or "coloured" in rname or rname == "mt_body" or rname == "mt_mirrorcover"):
						if custom_paint.r >= 0.0 and not is_secondary:
							std.albedo_color = custom_paint
						std.metallic = maxf(std.metallic, 0.78)
						std.roughness = minf(maxf(std.roughness, 0.14), 0.24)
						std.clearcoat_enabled = true
						std.clearcoat = 1.0
						std.clearcoat_roughness = 0.03
					elif "countach" in path_low and rname == "material.008":
						# Tame clipped pure-white body highlight to pearl white so sun specular doesn't wash out
						std.albedo_color = Color(0.84, 0.85, 0.88)
						std.metallic = 0.35
						std.roughness = 0.16
						std.clearcoat_enabled = true
						std.clearcoat = 1.0
						std.clearcoat_roughness = 0.03
					elif "undercarriage" in rname:
						# Eliminate bright white inside Ford Raptor wheel-well fender arches
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
						# Clean matte dark performance tire sidewalls & treads (removes chalk stencils & harsh specular bumps)
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
