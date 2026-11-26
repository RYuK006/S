# scripts/world/prop_mesh_utils.gd
# Utility for extracting, centering, grounding, and MultiMesh-ready preparing GLB/GLTF prop meshes.
class_name PropMeshUtils
extends RefCounted

static func load_centered_mesh(path: String, scale_factor: float = 1.0, embed_bottom_m: float = 0.05, submesh_filter: String = "") -> Mesh:
	if not FileAccess.file_exists(path):
		return null
	var root: Node3D = null
	if path.ends_with(".glb"):
		var gltf := GLTFDocument.new()
		var state := GLTFState.new()
		if gltf.append_from_file(path, state) != OK:
			return null
		root = gltf.generate_scene(state) as Node3D
	else:
		var packed := load(path) as PackedScene
		if packed:
			root = packed.instantiate() as Node3D
	if not root:
		return null

	var collected: Array[Dictionary] = []
	_collect_meshes(root, Transform3D.IDENTITY, collected, submesh_filter.to_lower())
	if collected.is_empty():
		root.free()
		return null

	var combined_aabb := AABB()
	var first: bool = true
	for item in collected:
		var mi: MeshInstance3D = item["node"]
		var xf: Transform3D = item["xf"]
		var ma: AABB = xf * mi.mesh.get_aabb()
		if first:
			combined_aabb = ma
			first = false
		else:
			combined_aabb = combined_aabb.merge(ma)

	var ctr: Vector3 = combined_aabb.get_center()
	var min_y: float = combined_aabb.position.y
	var shift := Vector3(-ctr.x * scale_factor, -min_y * scale_factor - embed_bottom_m, -ctr.z * scale_factor)

	var out_mesh := ArrayMesh.new()
	for item in collected:
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
				out_verts[i] = (xf * verts[i]) * scale_factor + shift
			clean_arr[Mesh.ARRAY_VERTEX] = out_verts

			if src_arr.size() > Mesh.ARRAY_NORMAL and src_arr[Mesh.ARRAY_NORMAL] is PackedVector3Array:
				var norms: PackedVector3Array = src_arr[Mesh.ARRAY_NORMAL]
				if norms.size() == verts.size():
					var basis_n: Basis = xf.basis.orthonormalized()
					var out_norms := PackedVector3Array()
					out_norms.resize(norms.size())
					for i: int in range(norms.size()):
						out_norms[i] = (basis_n * norms[i]).normalized()
					clean_arr[Mesh.ARRAY_NORMAL] = out_norms

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

			if src_arr.size() > Mesh.ARRAY_INDEX and src_arr[Mesh.ARRAY_INDEX] is PackedInt32Array:
				var idxs: PackedInt32Array = src_arr[Mesh.ARRAY_INDEX]
				if not idxs.is_empty():
					clean_arr[Mesh.ARRAY_INDEX] = idxs

			var surf_idx: int = out_mesh.get_surface_count()
			out_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, clean_arr)
			var mat: Material = mi.get_active_material(s)
			if mat and out_mesh.get_surface_count() > surf_idx:
				var mat_dup: Material = mat.duplicate()
				if mat_dup is StandardMaterial3D:
					var std: StandardMaterial3D = mat_dup
					var ml: String = (mi.name + " " + std.resource_name).to_lower()
					if "leaf" in ml or "branch" in ml or "atlas" in ml or "frond" in ml or "bush" in ml or "grass" in ml or "object_2" in ml:
						std.cull_mode = BaseMaterial3D.CULL_DISABLED
						if std.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA:
							std.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
							std.alpha_scissor_threshold = 0.42
						std.roughness = maxf(std.roughness, 0.58)
				out_mesh.surface_set_material(surf_idx, mat_dup)

	root.free()
	return out_mesh

static func _collect_meshes(node: Node, parent_xf: Transform3D, out: Array[Dictionary], filter: String) -> void:
	var xf: Transform3D = parent_xf * (node as Node3D).transform if node is Node3D else parent_xf
	if node is MeshInstance3D:
		var mi: MeshInstance3D = node
		if mi.mesh:
			if filter.is_empty() or filter in mi.name.to_lower() or (mi.get_parent() and filter in mi.get_parent().name.to_lower()):
				out.append({"node": mi, "xf": xf})
	for c in node.get_children():
		_collect_meshes(c, xf, out, filter)
