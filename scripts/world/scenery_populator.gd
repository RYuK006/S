# scripts/world/scenery_populator.gd
# FH5-grade photogrammetry foliage, roadside ecosystem, canyon rock, and Festival staging MultiMesh populator.
class_name SceneryPopulator
extends Node3D

const TerrainGenerator = preload("res://scripts/world/terrain_generator.gd")
const RoadNetwork = preload("res://scripts/world/road_network.gd")
const PropMeshUtils = preload("res://scripts/world/prop_mesh_utils.gd")

var terrain_gen: TerrainGenerator
var road_net: RoadNetwork
var rng := RandomNumberGenerator.new()

func _init(tg: TerrainGenerator = null, rn: RoadNetwork = null) -> void:
	terrain_gen = tg if tg else TerrainGenerator.new()
	road_net = rn
	rng.seed = 202605

func populate_world_scenery() -> void:
	_build_festival_hub_staging()
	_populate_pine_forests()
	_populate_palm_promenade()
	_populate_desert_flora()
	_populate_desert_rocks()
	_populate_ground_grass()
	_build_coast_harbor_depot()

func _is_road_clear(x: float, z: float, min_clearance: float = 11.5, ignore_offset: float = -1.0) -> bool:
	if not road_net:
		return true
	var segs: Array[Dictionary] = road_net.all_road_segments
	var p2 := Vector2(x, z)
	for seg: Dictionary in segs:
		if ignore_offset >= 0.0 and absf(float(seg.get("offset", 0.0)) - ignore_offset) < 0.005:
			continue
		var a3: Vector3 = seg["p0"]
		var b3: Vector3 = seg["p1"]
		var a := Vector2(a3.x, a3.z)
		var b := Vector2(b3.x, b3.z)
		if absf(a.x - x) > 90.0 and absf(b.x - x) > 90.0:
			continue
		if absf(a.y - z) > 90.0 and absf(b.y - z) > 90.0:
			continue
		var ab: Vector2 = b - a
		var lsq: float = ab.length_squared()
		var t: float = clampf((p2 - a).dot(ab) / lsq, 0.0, 1.0) if lsq > 0.001 else 0.0
		var d: float = p2.distance_to(a + ab * t)
		if d < float(seg["half_w"]) + min_clearance:
			return false
	return true

func _sample_roadside_in_quadrant(x_min: float, x_max: float, z_min: float, z_max: float, min_d: float, max_d: float) -> Vector2:
	if road_net and not road_net.all_road_segments.is_empty():
		var segs: Array[Dictionary] = road_net.all_road_segments
		for _try: int in range(18):
			var seg: Dictionary = segs[rng.randi_range(0, segs.size() - 1)]
			var a3: Vector3 = seg["p0"]
			var b3: Vector3 = seg["p1"]
			var mid: Vector3 = a3.lerp(b3, rng.randf())
			if mid.x < x_min or mid.x > x_max or mid.z < z_min or mid.z > z_max:
				continue
			var ang: float = rng.randf() * TAU
			var dist_out: float = float(seg["half_w"]) + rng.randf_range(min_d, max_d)
			var cx: float = mid.x + cos(ang) * dist_out
			var cz: float = mid.z + sin(ang) * dist_out
			if cx >= x_min and cx <= x_max and cz >= z_min and cz <= z_max:
				return Vector2(cx, cz)
	return Vector2(rng.randf_range(x_min, x_max), rng.randf_range(z_min, z_max))

func _build_multimesh_batch(batch_name: String, mesh: Mesh, xforms: Array[Transform3D], vis_end: float = 850.0, tint: Color = Color(1, 1, 1, 1), cast_shadows: bool = true) -> void:
	if not mesh or xforms.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i: int in range(xforms.size()):
		mm.set_instance_transform(i, xforms[i])

	var inst := MultiMeshInstance3D.new()
	inst.name = batch_name
	inst.multimesh = mm
	inst.visibility_range_end = vis_end
	inst.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast_shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	if tint != Color(1, 1, 1, 1):
		var tinted_mesh: Mesh = mesh.duplicate()
		for s: int in range(tinted_mesh.get_surface_count()):
			var m: Material = tinted_mesh.surface_get_material(s)
			if m is StandardMaterial3D:
				var sd: StandardMaterial3D = m.duplicate()
				sd.albedo_color = sd.albedo_color * tint
				tinted_mesh.surface_set_material(s, sd)
		mm.mesh = tinted_mesh

	add_child(inst)

func _build_festival_hub_staging() -> void:
	var gantry_mesh: Mesh = PropMeshUtils.load_centered_mesh("res://assets/models/props/starting_line_gantry.glb", 0.046, 0.05)
	if gantry_mesh:
		var gantry_y: float = terrain_gen.get_height(0.0, -12.0) + 0.34
		var mi := MeshInstance3D.new()
		mi.name = "Mesh_FestivalStartGantry"
		mi.mesh = gantry_mesh
		mi.position = Vector3(0.0, gantry_y, -12.0)
		add_child(mi)

	var truss_mesh: Mesh = PropMeshUtils.load_centered_mesh("res://assets/models/props/festival_truss.glb", 0.95, 0.05)
	if truss_mesh:
		var truss_xforms: Array[Transform3D] = []
		for i: int in range(12):
			var ang: float = (float(i) / 12.0) * TAU
			var tx: float = cos(ang) * 98.0
			var tz: float = sin(ang) * 98.0
			if not _is_road_clear(tx, tz, 9.0):
				continue
			var ty: float = terrain_gen.get_height(tx, tz)
			truss_xforms.append(Transform3D(Basis(Vector3.UP, ang + PI * 0.5), Vector3(tx, ty, tz)))
		_build_multimesh_batch("MultiMesh_FestivalTrusses", truss_mesh, truss_xforms, 700.0)

	# Concrete barriers lined tightly along clear edges of Starting Grid
	var barrier_mesh: Mesh = PropMeshUtils.load_centered_mesh("res://assets/models/props/concrete_road_barrier_02/concrete_road_barrier_02.gltf", 0.78, 0.04)
	if barrier_mesh:
		var b_xforms: Array[Transform3D] = []
		for z_step: int in range(-66, 68, 2):
			var bz: float = float(z_step)
			for side_x: float in [-8.2, 8.2]:
				if not _is_road_clear(side_x, bz, 15.0, 0.34):
					continue
				var by: float = terrain_gen.get_height(side_x, bz) + 0.15
				b_xforms.append(Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(side_x, by, bz)))
		_build_multimesh_batch("MultiMesh_HubConcreteBarriers", barrier_mesh, b_xforms, 450.0)

	var light_mesh: Mesh = PropMeshUtils.load_centered_mesh("res://assets/models/props/flood_lights/flood_lights.gltf", 1.85, 0.02, "standing_double_a")
	if light_mesh:
		var l_xforms: Array[Transform3D] = []
		for bz: float in [-58.0, -24.0, 24.0, 58.0]:
			for sx: float in [-11.5, 11.5]:
				if not _is_road_clear(sx, bz, 15.0, 0.34):
					continue
				var ly: float = terrain_gen.get_height(sx, bz)
				var yaw: float = PI * 0.5 if sx < 0.0 else -PI * 0.5
				l_xforms.append(Transform3D(Basis(Vector3.UP, yaw), Vector3(sx, ly, bz)))
		_build_multimesh_batch("MultiMesh_HubFloodLights", light_mesh, l_xforms, 420.0)

func _populate_pine_forests() -> void:
	var pine_mesh: Mesh = PropMeshUtils.load_centered_mesh("res://assets/models/foliage/pine_tree_opt.glb", 0.24, 0.15)
	if not pine_mesh:
		return
	var xforms_alpine: Array[Transform3D] = []
	var xforms_hub: Array[Transform3D] = []

	# Dense Alpine pine forest hugging Frozen Pass Hillclimb & snow slopes
	for i: int in range(1100):
		var pt: Vector2 = _sample_roadside_in_quadrant(-2450.0, -160.0, -2450.0, -160.0, 10.0, 125.0) if i < 880 else Vector2(rng.randf_range(-2400.0, -180.0), rng.randf_range(-2400.0, -180.0))
		if not _is_road_clear(pt.x, pt.y, 12.0):
			continue
		if terrain_gen.get_normal(pt.x, pt.y).y < 0.70:
			continue
		var py: float = terrain_gen.get_height(pt.x, pt.y)
		var sc: float = rng.randf_range(0.75, 1.45)
		var bas := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sc, sc * rng.randf_range(0.92, 1.18), sc))
		xforms_alpine.append(Transform3D(bas, Vector3(pt.x, py, pt.y)))

	# Dense perimeter Hub pines framing meadows & surrounding hills
	for i: int in range(460):
		var ang: float = rng.randf() * TAU
		var rad: float = rng.randf_range(85.0, 520.0)
		var px: float = cos(ang) * rad
		var pz: float = sin(ang) * rad
		if px > 420.0 and pz < -420.0:
			continue
		if not _is_road_clear(px, pz, 12.5):
			continue
		var py: float = terrain_gen.get_height(px, pz)
		var sc: float = rng.randf_range(0.75, 1.32)
		xforms_hub.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sc, sc, sc)), Vector3(px, py, pz)))

	_build_multimesh_batch("MultiMesh_FrozenPassPines", pine_mesh, xforms_alpine, 1100.0, Color(0.88, 0.94, 0.98))
	_build_multimesh_batch("MultiMesh_HubPines", pine_mesh, xforms_hub, 950.0)

func _populate_palm_promenade() -> void:
	var palm_mesh: Mesh = PropMeshUtils.load_centered_mesh("res://assets/models/foliage/palm_tree_opt.glb", 2.0, 0.12)
	if not palm_mesh:
		return
	var palm_xforms: Array[Transform3D] = []
	for i: int in range(420):
		var pt: Vector2 = _sample_roadside_in_quadrant(950.0, 2600.0, 250.0, 2400.0, 7.5, 95.0) if i < 340 else Vector2(rng.randf_range(950.0, 2550.0), rng.randf_range(250.0, 2350.0))
		var py: float = terrain_gen.get_height(pt.x, pt.y)
		if py < 2.2:
			continue
		if not _is_road_clear(pt.x, pt.y, 9.5):
			continue
		var sc: float = rng.randf_range(0.85, 1.38)
		palm_xforms.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sc, sc * rng.randf_range(0.9, 1.18), sc)), Vector3(pt.x, py, pt.y)))
	_build_multimesh_batch("MultiMesh_CoastPalms", palm_mesh, palm_xforms, 950.0)

func _populate_desert_flora() -> void:
	var saguaro_mesh: Mesh = PropMeshUtils.load_centered_mesh("res://assets/models/foliage/saguaro_cactus.glb", 1.30, 0.12, "bark")
	var bush_mesh: Mesh = PropMeshUtils.load_centered_mesh("res://assets/models/foliage/desert_bush.glb", 0.36, 0.06)

	if saguaro_mesh:
		var cactus_xforms: Array[Transform3D] = []
		for i: int in range(420):
			var pt: Vector2 = _sample_roadside_in_quadrant(-2350.0, -220.0, 220.0, 2350.0, 7.0, 85.0) if i < 360 else Vector2(rng.randf_range(-2350.0, -240.0), rng.randf_range(240.0, 2350.0))
			if not _is_road_clear(pt.x, pt.y, 9.5):
				continue
			if terrain_gen.get_normal(pt.x, pt.y).y < 0.78:
				continue
			var cy: float = terrain_gen.get_height(pt.x, pt.y)
			var sc: float = rng.randf_range(0.85, 1.50)
			cactus_xforms.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sc, sc * rng.randf_range(0.9, 1.2), sc)), Vector3(pt.x, cy, pt.y)))
		_build_multimesh_batch("MultiMesh_DustBowlSaguaros", saguaro_mesh, cactus_xforms, 720.0)

	if bush_mesh:
		var desert_bushes: Array[Transform3D] = []
		var hub_bushes: Array[Transform3D] = []
		for i: int in range(1100):
			var pt: Vector2 = _sample_roadside_in_quadrant(-2350.0, -180.0, 180.0, 2350.0, 4.0, 68.0)
			if not _is_road_clear(pt.x, pt.y, 7.5):
				continue
			var by: float = terrain_gen.get_height(pt.x, pt.y)
			var sc: float = rng.randf_range(0.65, 1.45)
			desert_bushes.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sc, sc, sc)), Vector3(pt.x, by, pt.y)))
		for i: int in range(360):
			var ang: float = rng.randf() * TAU
			var rad: float = rng.randf_range(20.0, 280.0)
			var bx: float = cos(ang) * rad
			var bz: float = sin(ang) * rad
			if not _is_road_clear(bx, bz, 8.5):
				continue
			var by: float = terrain_gen.get_height(bx, bz)
			var sc: float = rng.randf_range(0.55, 1.15)
			hub_bushes.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sc, sc, sc)), Vector3(bx, by, bz)))
		_build_multimesh_batch("MultiMesh_DesertBushes", bush_mesh, desert_bushes, 450.0)
		_build_multimesh_batch("MultiMesh_HubBushes", bush_mesh, hub_bushes, 380.0, Color(0.68, 0.85, 0.56))

func _populate_desert_rocks() -> void:
	# Poly Haven real photogrammetry organic boulders (replaces angular quarry blocks!)
	var granite_boulder: Mesh = PropMeshUtils.load_centered_mesh("res://assets/models/rocks/boulder_01/boulder_01.gltf", 2.1, 0.30)
	var sandstone_slab: Mesh = PropMeshUtils.load_centered_mesh("res://assets/models/rocks/namaqualand_boulder_02/namaqualand_boulder_02.gltf", 2.3, 0.25)
	var desert_outcrop: Mesh = PropMeshUtils.load_centered_mesh("res://assets/models/rocks/namaqualand_boulder_04/namaqualand_boulder_04.gltf", 2.4, 0.45)

	# 1. Dust Bowl Photogrammetry Desert Boulders & Sandstone Outcrops
	var x_dust: Array[Transform3D] = []
	for i: int in range(110):
		var pt: Vector2 = _sample_roadside_in_quadrant(-2350.0, -220.0, 220.0, 2350.0, 9.0, 95.0)
		if not _is_road_clear(pt.x, pt.y, 11.5):
			continue
		var ry: float = terrain_gen.get_height(pt.x, pt.y) - 0.35
		var sc: float = rng.randf_range(0.60, 1.40)
		var bas := Basis.from_euler(Vector3(rng.randf_range(-0.15, 0.15), rng.randf() * TAU, rng.randf_range(-0.15, 0.15))).scaled(Vector3(sc * rng.randf_range(1.0, 1.3), sc * 0.85, sc))
		x_dust.append(Transform3D(bas, Vector3(pt.x, ry, pt.y)))
	_build_multimesh_batch("MultiMesh_DustBowlRocks", desert_outcrop, x_dust, 650.0, Color(0.95, 0.78, 0.62))

	# 2. Volcano Basalt Boulders & Obsidian Crags
	var x_volcano: Array[Transform3D] = []
	for i: int in range(140):
		var pt: Vector2 = _sample_roadside_in_quadrant(200.0, 2200.0, -2200.0, -200.0, 9.0, 110.0)
		if not _is_road_clear(pt.x, pt.y, 11.5):
			continue
		var ry: float = terrain_gen.get_height(pt.x, pt.y) - 0.40
		var sc: float = rng.randf_range(0.65, 1.55)
		var bas := Basis.from_euler(Vector3(rng.randf_range(-0.18, 0.18), rng.randf() * TAU, rng.randf_range(-0.18, 0.18))).scaled(Vector3(sc, sc * 0.80, sc))
		x_volcano.append(Transform3D(bas, Vector3(pt.x, ry, pt.y)))
	_build_multimesh_batch("MultiMesh_VolcanoBasaltCrags", granite_boulder, x_volcano, 700.0, Color(0.28, 0.25, 0.27))

	# 3. Frozen Pass Alpine Granite Outcrops
	var x_granite: Array[Transform3D] = []
	for i: int in range(110):
		var pt: Vector2 = _sample_roadside_in_quadrant(-2300.0, -260.0, -2300.0, -260.0, 10.0, 110.0)
		if not _is_road_clear(pt.x, pt.y, 12.0):
			continue
		var ry: float = terrain_gen.get_height(pt.x, pt.y) - 0.35
		var sc: float = rng.randf_range(0.65, 1.40)
		var bas := Basis.from_euler(Vector3(rng.randf_range(-0.15, 0.15), rng.randf() * TAU, rng.randf_range(-0.15, 0.15))).scaled(Vector3(sc, sc * 0.85, sc))
		x_granite.append(Transform3D(bas, Vector3(pt.x, ry, pt.y)))
	_build_multimesh_batch("MultiMesh_SnowGraniteBoulders", sandstone_slab, x_granite, 650.0, Color(0.72, 0.76, 0.82))

func _populate_ground_grass() -> void:
	var green_grass: Mesh = PropMeshUtils.load_centered_mesh("res://assets/models/foliage/grass_medium_01/grass_medium_01.gltf", 3.4, 0.02, "small_a_lod0")
	var dry_grass: Mesh = PropMeshUtils.load_centered_mesh("res://assets/models/foliage/dry_grass.glb", 0.0068, 0.03, "grasspatch1")

	if green_grass:
		var hub_g: Array[Transform3D] = []
		for i: int in range(2200):
			var pt: Vector2 = _sample_roadside_in_quadrant(-280.0, 280.0, -280.0, 280.0, 1.5, 45.0)
			if not _is_road_clear(pt.x, pt.y, 2.5):
				continue
			var gy: float = terrain_gen.get_height(pt.x, pt.y)
			var sc: float = rng.randf_range(0.85, 1.60)
			hub_g.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sc, sc, sc)), Vector3(pt.x, gy, pt.y)))
		_build_multimesh_batch("MultiMesh_HubMeadowGrass", green_grass, hub_g, 210.0, Color(1, 1, 1, 1), false)

	if dry_grass:
		var dg_xforms: Array[Transform3D] = []
		for i: int in range(2200):
			var pt: Vector2 = _sample_roadside_in_quadrant(-2100.0, -280.0, 280.0, 2100.0, 1.8, 38.0)
			if not _is_road_clear(pt.x, pt.y, 2.2):
				continue
			var gy: float = terrain_gen.get_height(pt.x, pt.y)
			var sc: float = rng.randf_range(0.85, 1.65)
			dg_xforms.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sc, sc, sc)), Vector3(pt.x, gy, pt.y)))
		_build_multimesh_batch("MultiMesh_DesertDryGrass", dry_grass, dg_xforms, 260.0, Color(1, 1, 1, 1), false)

func _build_coast_harbor_depot() -> void:
	var c_box := BoxMesh.new()
	c_box.size = Vector3(2.5, 2.6, 6.2)
	var rib_nor: Texture2D = load("res://assets/textures/cliff_nor.jpg") as Texture2D
	var cols: Array[Color] = [Color(0.55, 0.14, 0.12), Color(0.12, 0.28, 0.50), Color(0.62, 0.42, 0.14)]
	for ci: int in range(cols.size()):
		var xf_list: Array[Transform3D] = []
		var cmat := StandardMaterial3D.new()
		cmat.albedo_color = cols[ci]
		cmat.metallic = 0.55
		cmat.roughness = 0.48
		if rib_nor:
			cmat.normal_enabled = true
			cmat.normal_texture = rib_nor
			cmat.uv1_scale = Vector3(2.0, 1.0, 4.0)
		for r: int in range(6):
			var cx: float = 1910.0 + float(ci) * 10.0 + float(r % 2) * 3.2
			var cz: float = 1220.0 + float(r) * 14.0
			if not _is_road_clear(cx, cz, 12.0):
				continue
			var cy: float = terrain_gen.get_height(cx, cz) + 1.3
			if cy < 2.5:
				continue
			xf_list.append(Transform3D(Basis(Vector3.UP, 0.15), Vector3(cx, cy, cz)))
		if not xf_list.is_empty():
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = c_box
			mm.instance_count = xf_list.size()
			for i: int in range(xf_list.size()):
				mm.set_instance_transform(i, xf_list[i])
			var inst := MultiMeshInstance3D.new()
			inst.name = "MultiMesh_HarborContainers_%d" % ci
			inst.multimesh = mm
			inst.material_override = cmat
			inst.visibility_range_end = 750.0
			add_child(inst)
