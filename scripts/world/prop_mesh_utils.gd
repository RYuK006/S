# scripts/world/prop_mesh_utils.gd
# Utility for extracting, centering, grounding, LOD-generating, and MultiMesh-preparing GLB/GLTF prop meshes.
class_name PropMeshUtils
extends RefCounted

static var _mesh_cache: Dictionary = {}

static func load_centered_mesh(path: String, scale_factor: float = 1.0, embed_bottom_m: float = 0.05, submesh_filter: String = "", fit_max_dim: float = 0.0) -> Mesh:
	var cache_key: String = "%s|%.4f|%.4f|%s|%.4f" % [path, scale_factor, embed_bottom_m, submesh_filter.to_lower(), fit_max_dim]
	if _mesh_cache.has(cache_key):
		return _mesh_cache[cache_key] as Mesh

	if not FileAccess.file_exists(path):
		return null
	var root: Node3D = null
	if ResourceLoader.exists(path):
		var packed := load(path) as PackedScene
		if packed:
			root = packed.instantiate() as Node3D
	if not root:
		var gltf := GLTFDocument.new()
		var state := GLTFState.new()
		if gltf.append_from_file(path, state) != OK:
			return null
		root = gltf.generate_scene(state) as Node3D
	if not root:
		return null

	var collected: Array[Dictionary] = []
	_collect_meshes(root, Transform3D.IDENTITY, collected, submesh_filter.to_lower())
	if collected.is_empty():
		root.free()
		return null

	var combined_aabb := AABB()
	var first: bool = true
	for item: Dictionary in collected:
		var mi: MeshInstance3D = item["node"]
		var xf: Transform3D = item["xf"]
		var ma: AABB = xf * mi.mesh.get_aabb()
		if first:
			combined_aabb = ma
			first = false
		else:
			combined_aabb = combined_aabb.merge(ma)

	var eff_scale: float = scale_factor
	if fit_max_dim > 0.0:
		var raw_max: float = maxf(combined_aabb.size.x, maxf(combined_aabb.size.y, combined_aabb.size.z))
		if raw_max > 0.001:
			eff_scale = fit_max_dim / raw_max
	var ctr: Vector3 = combined_aabb.get_center()
	var min_y: float = combined_aabb.position.y
	var shift := Vector3(-ctr.x * eff_scale, -min_y * eff_scale - embed_bottom_m, -ctr.z * eff_scale)

	var im := ImporterMesh.new()
	var mats_out: Array[Material] = []

	for item: Dictionary in collected:
		var mi: MeshInstance3D = item["node"]
		var xf: Transform3D = item["xf"]
		var src: Mesh = mi.mesh
		for s: int in range(src.get_surface_count()):
			var src_arr: Array = src.surface_get_arrays(s)
			var verts: PackedVector3Array = src_arr[Mesh.ARRAY_VERTEX]
			if verts.is_empty():
				continue

			var clean_arr: Array = []
			clean_arr.resize(Mesh.ARRAY_MAX)

			var out_verts := PackedVector3Array()
			out_verts.resize(verts.size())
			for i: int in range(verts.size()):
				out_verts[i] = (xf * verts[i]) * eff_scale + shift
			clean_arr[Mesh.ARRAY_VERTEX] = out_verts

			var basis_n: Basis = xf.basis.orthonormalized()
			if src_arr.size() > Mesh.ARRAY_NORMAL and src_arr[Mesh.ARRAY_NORMAL] is PackedVector3Array:
				var norms: PackedVector3Array = src_arr[Mesh.ARRAY_NORMAL]
				if norms.size() == verts.size():
					var out_norms := PackedVector3Array()
					out_norms.resize(norms.size())
					for i: int in range(norms.size()):
						out_norms[i] = (basis_n * norms[i]).normalized()
					clean_arr[Mesh.ARRAY_NORMAL] = out_norms

			if src_arr.size() > Mesh.ARRAY_TANGENT and src_arr[Mesh.ARRAY_TANGENT] is PackedFloat32Array:
				var tangs: PackedFloat32Array = src_arr[Mesh.ARRAY_TANGENT]
				if tangs.size() == verts.size() * 4:
					var out_tangs := PackedFloat32Array()
					out_tangs.resize(tangs.size())
					for i: int in range(verts.size()):
						var bi: int = i * 4
						var t_vec := basis_n * Vector3(tangs[bi], tangs[bi + 1], tangs[bi + 2])
						t_vec = t_vec.normalized()
						out_tangs[bi] = t_vec.x
						out_tangs[bi + 1] = t_vec.y
						out_tangs[bi + 2] = t_vec.z
						out_tangs[bi + 3] = tangs[bi + 3]
					clean_arr[Mesh.ARRAY_TANGENT] = out_tangs

			if src_arr.size() > Mesh.ARRAY_TEX_UV and src_arr[Mesh.ARRAY_TEX_UV] is PackedVector2Array:
				var uvs: PackedVector2Array = src_arr[Mesh.ARRAY_TEX_UV]
				if uvs.size() == verts.size():
					clean_arr[Mesh.ARRAY_TEX_UV] = uvs

			if src_arr.size() > Mesh.ARRAY_TEX_UV2 and src_arr[Mesh.ARRAY_TEX_UV2] is PackedVector2Array:
				var uvs2: PackedVector2Array = src_arr[Mesh.ARRAY_TEX_UV2]
				if uvs2.size() == verts.size():
					clean_arr[Mesh.ARRAY_TEX_UV2] = uvs2

			if src_arr.size() > Mesh.ARRAY_COLOR and src_arr[Mesh.ARRAY_COLOR] is PackedColorArray:
				var cols: PackedColorArray = src_arr[Mesh.ARRAY_COLOR]
				if cols.size() == verts.size():
					clean_arr[Mesh.ARRAY_COLOR] = cols

			var idx_arr: PackedInt32Array = src_arr[Mesh.ARRAY_INDEX] if (src_arr.size() > Mesh.ARRAY_INDEX and src_arr[Mesh.ARRAY_INDEX] is PackedInt32Array) else PackedInt32Array()
			if idx_arr.is_empty():
				var st_idx := SurfaceTool.new()
				st_idx.create_from_arrays(clean_arr, Mesh.PRIMITIVE_TRIANGLES)
				st_idx.index()
				clean_arr = st_idx.commit_to_arrays()
			else:
				clean_arr[Mesh.ARRAY_INDEX] = idx_arr

			var mat_dup: Material = null
			var mat: Material = mi.get_active_material(s)
			if mat:
				mat_dup = mat.duplicate()
				if mat_dup is StandardMaterial3D:
					var std: StandardMaterial3D = mat_dup
					var ml: String = (mi.name + " " + std.resource_name + " " + path).to_lower()
					var is_foliage: bool = ("leaf" in ml or "branch" in ml or "atlas" in ml or "frond" in ml or "bush" in ml or "grass" in ml or "fir_" in ml or "palm" in ml or "yucca" in ml or "tree" in ml or "fence" in ml or "object_4" in ml or "fern" in ml or "shrub" in ml or "jacaranda" in ml or "joshua" in ml or "quiver" in ml or "succulent" in ml)
					var is_stone_wood: bool = ("rock" in ml or "boulder" in ml or "cliff" in ml or "stone" in ml or "crate" in ml or "pallet" in ml or "cabin" in ml or "wood" in ml or "hay" in ml or "building" in ml or "shop" in ml or "concrete" in ml or "pier" in ml or "lighthouse" in ml)
					if std.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA or is_foliage:
						std.cull_mode = BaseMaterial3D.CULL_DISABLED
						if std.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA:
							std.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
							std.alpha_scissor_threshold = 0.36
						std.roughness = clampf(maxf(std.roughness, 0.64), 0.64, 0.90)
						std.metallic = minf(std.metallic, 0.02)
						std.metallic_specular = 0.24
						std.backlight_enabled = true
						std.backlight = Color(0.24, 0.30, 0.16)
					elif is_stone_wood:
						std.roughness = clampf(maxf(std.roughness, 0.68), 0.68, 0.94)
						std.metallic = minf(std.metallic, 0.06)
						std.metallic_specular = 0.32
					else:
						std.roughness = maxf(std.roughness, 0.28)
						std.metallic_specular = minf(std.metallic_specular, 0.48)
					if std.emission_enabled and std.emission_energy_multiplier > 1.35:
						std.emission_energy_multiplier = 1.35

			im.add_surface(Mesh.PRIMITIVE_TRIANGLES, clean_arr, [], {}, mat_dup, "surf_%d" % mats_out.size(), 0)
			mats_out.append(mat_dup)

	# Generate automatic GPU hardware LOD chain only for heavy >4.5k vertex meshes (huge boot speedup)
	var total_verts: int = 0
	for si_v: int in range(im.get_surface_count()):
		var va: Array = im.get_surface_arrays(si_v)
		if va.size() > Mesh.ARRAY_VERTEX and va[Mesh.ARRAY_VERTEX] is PackedVector3Array:
			total_verts += (va[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	if im.get_surface_count() > 0:
		if total_verts <= 4500:
			var fast_mesh: ArrayMesh = im.get_mesh()
			root.free()
			_mesh_cache[cache_key] = fast_mesh
			return fast_mesh
		im.generate_lods(deg_to_rad(60.0), deg_to_rad(30.0), [])
		var rebuilt := ImporterMesh.new()
		var any_decimated: bool = false
		for si: int in range(im.get_surface_count()):
			var s_arr: Array = im.get_surface_arrays(si)
			var s_idx: PackedInt32Array = s_arr[Mesh.ARRAY_INDEX] if (s_arr.size() > Mesh.ARRAY_INDEX and s_arr[Mesh.ARRAY_INDEX] is PackedInt32Array) else PackedInt32Array()
			var base_tris: int = int(s_idx.size() / 3.0)
			if base_tris > 18000 and im.get_surface_lod_count(si) > 0:
				var chosen_idx: PackedInt32Array = PackedInt32Array()
				var chosen_lods: Dictionary = {}
				for li: int in range(im.get_surface_lod_count(si)):
					var l_idx: PackedInt32Array = im.get_surface_lod_indices(si, li)
					var l_tris: int = int(l_idx.size() / 3.0)
					if chosen_idx.is_empty():
						if l_tris <= 18000 or li == im.get_surface_lod_count(si) - 1:
							chosen_idx = l_idx
					else:
						chosen_lods[im.get_surface_lod_size(si, li)] = l_idx
				if not chosen_idx.is_empty():
					s_arr[Mesh.ARRAY_INDEX] = chosen_idx
					rebuilt.add_surface(Mesh.PRIMITIVE_TRIANGLES, s_arr, [], chosen_lods, im.get_surface_material(si), im.get_surface_name(si), 0)
					any_decimated = true
					continue
			var kept_lods: Dictionary = {}
			for li: int in range(im.get_surface_lod_count(si)):
				kept_lods[im.get_surface_lod_size(si, li)] = im.get_surface_lod_indices(si, li)
			rebuilt.add_surface(Mesh.PRIMITIVE_TRIANGLES, s_arr, [], kept_lods, im.get_surface_material(si), im.get_surface_name(si), 0)
		var out_mesh: ArrayMesh = rebuilt.get_mesh() if any_decimated else im.get_mesh()
		root.free()
		_mesh_cache[cache_key] = out_mesh
		return out_mesh

	root.free()
	return null

static func _collect_meshes(node: Node, parent_xf: Transform3D, out: Array[Dictionary], filter: String) -> void:
	var xf: Transform3D = parent_xf * (node as Node3D).transform if node is Node3D else parent_xf
	if node is MeshInstance3D:
		var mi: MeshInstance3D = node
		if mi.mesh:
			if filter.is_empty() or filter in mi.name.to_lower() or (mi.get_parent() and filter in mi.get_parent().name.to_lower()):
				out.append({"node": mi, "xf": xf})
	for c in node.get_children():
		_collect_meshes(c, xf, out, filter)
