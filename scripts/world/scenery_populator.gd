# scripts/world/scenery_populator.gd
# FH5-grade photogrammetry foliage, roadside ecosystem, canyon rock arches, and Festival Hub MultiMesh populator.
class_name SceneryPopulator
extends Node3D

const TerrainGenerator = preload("res://scripts/world/terrain_generator.gd")
const RoadNetwork = preload("res://scripts/world/road_network.gd")
const PropMeshUtils = preload("res://scripts/world/prop_mesh_utils.gd")
const BiomePropsBuilder = preload("res://scripts/world/biome_props_builder.gd")
const ExtendedPropsPopulator = preload("res://scripts/world/extended_props_populator.gd")
const DestructiblePropManager = preload("res://scripts/world/destructible_prop_manager.gd")

var terrain_gen: TerrainGenerator
var road_net: RoadNetwork
var destruct_mgr: DestructiblePropManager
var rng := RandomNumberGenerator.new()

func _init(tg: TerrainGenerator = null, rn: RoadNetwork = null, dm: DestructiblePropManager = null) -> void:
	terrain_gen = tg if tg else TerrainGenerator.new()
	road_net = rn
	destruct_mgr = dm
	rng.seed = 202605

func populate_world_scenery() -> void:
	var clear_fn := Callable(self, "_is_road_clear")
	var mm_fn := Callable(self, "_build_multimesh_batch")
	BiomePropsBuilder.build_festival_hub_arena(self, terrain_gen, road_net, clear_fn, mm_fn)
	BiomePropsBuilder.build_coast_harbor_depot(self, terrain_gen, clear_fn, mm_fn)
	BiomePropsBuilder.build_dust_bowl_monuments(terrain_gen, road_net, clear_fn, mm_fn)
	BiomePropsBuilder.build_volcano_caldera_plume(self, terrain_gen)
	_populate_pine_forests()
	_populate_palm_promenade()
	_populate_desert_flora()
	_populate_desert_rocks()
	_populate_ground_grass()
	ExtendedPropsPopulator.populate_all(terrain_gen, road_net, rng, Callable(self, "_sample_roadside_in_quadrant"), mm_fn)

func _is_road_clear(x: float, z: float, min_clearance: float = 11.5, _ignore_offset: float = -1.0) -> bool:
	if not road_net:
		return true
	return road_net.is_point_clear_of_roads(x, z, min_clearance, "")

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

	var base_mesh: Mesh = mesh
	if tint != Color(1, 1, 1, 1):
		var tinted_mesh: Mesh = mesh.duplicate()
		for s: int in range(tinted_mesh.get_surface_count()):
			var m: Material = tinted_mesh.surface_get_material(s)
			if m is StandardMaterial3D:
				var sd: StandardMaterial3D = m.duplicate()
				sd.albedo_color = sd.albedo_color * tint
				tinted_mesh.surface_set_material(s, sd)
		base_mesh = tinted_mesh

	var aabb_sz: Vector3 = base_mesh.get_aabb().size
	var base_foot_r: float = maxf(0.85, 0.50 * Vector2(aabb_sz.x, aabb_sz.z).length() + 1.15)
	var cells: Dictionary = {}
	for xf: Transform3D in xforms:
		if road_net:
			var sc_xz: float = maxf(xf.basis.x.length(), xf.basis.z.length())
			if not road_net.is_point_clear_of_roads(xf.origin.x, xf.origin.z, base_foot_r * sc_xz, ""):
				continue
		var key := Vector2i(int(floorf(xf.origin.x / 900.0)), int(floorf(xf.origin.z / 900.0)))
		if not cells.has(key):
			var arr: Array[Transform3D] = []
			cells[key] = arr
		(cells[key] as Array[Transform3D]).append(xf)

	var clamped_vis: float = minf(vis_end, 850.0)
	var d_type := DestructiblePropManager.DestructType.SOLID_BUILDING
	if destruct_mgr:
		d_type = destruct_mgr.classify_batch_name(batch_name)
	for key: Vector2i in cells.keys():
		var cell_xforms: Array[Transform3D] = cells[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = base_mesh
		mm.instance_count = cell_xforms.size()
		for i: int in range(cell_xforms.size()):
			mm.set_instance_transform(i, cell_xforms[i])

		var inst := MultiMeshInstance3D.new()
		inst.name = "%s_%d_%d" % [batch_name, key.x, key.y]
		inst.multimesh = mm
		inst.visibility_range_end = clamped_vis
		inst.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast_shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(inst)
		if destruct_mgr:
			destruct_mgr.register_multimesh_prop_batch(batch_name, mm, base_mesh, d_type, cell_xforms)

func _populate_pine_forests() -> void:
	# Note: Object_2 = evergreen summer conifer; Object_3 = snow-laden winter alpine conifer
	var fir_summer: Mesh = PropMeshUtils.load_centered_mesh("res://assets/models/foliage/fir_winter_summer.glb", 0.044, 0.20, "object_2")
	var fir_winter: Mesh = PropMeshUtils.load_centered_mesh("res://assets/models/foliage/fir_winter_summer.glb", 0.044, 0.20, "object_3")
	if not fir_summer:
		fir_summer = PropMeshUtils.load_centered_mesh("res://assets/models/foliage/pine_tree_opt.glb", 0.24, 0.15)
	if not fir_winter:
		fir_winter = fir_summer
	if not fir_winter:
		return

	var xforms_alpine_snow: Array[Transform3D] = []
	var xforms_alpine_green: Array[Transform3D] = []
	var xforms_hub: Array[Transform3D] = []

	for i: int in range(1250):
		var pt: Vector2 = _sample_roadside_in_quadrant(-2500.0, -160.0, -2500.0, -160.0, 9.5, 130.0) if i < 950 else Vector2(rng.randf_range(-2450.0, -180.0), rng.randf_range(-2450.0, -180.0))
		if not _is_road_clear(pt.x, pt.y, 12.0):
			continue
		if terrain_gen.get_normal(pt.x, pt.y).y < 0.68:
			continue
		var py: float = terrain_gen.get_height(pt.x, pt.y)
		var sc: float = rng.randf_range(0.75, 1.48)
		var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sc, sc * rng.randf_range(0.92, 1.18), sc)), Vector3(pt.x, py, pt.y))
		if py > 74.0:
			xforms_alpine_snow.append(xf)
		else:
			xforms_alpine_green.append(xf)

	for i: int in range(520):
		var ang: float = rng.randf() * TAU
		var rad: float = rng.randf_range(75.0, 560.0)
		var px: float = cos(ang) * rad
		var pz: float = sin(ang) * rad
		if px > 420.0 and pz < -420.0:
			continue
		if not _is_road_clear(px, pz, 12.5):
			continue
		var py: float = terrain_gen.get_height(px, pz)
		var sc: float = rng.randf_range(0.78, 1.38)
		xforms_hub.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sc, sc, sc)), Vector3(px, py, pz)))

	_build_multimesh_batch("MultiMesh_FrozenPassSnowPines", fir_winter, xforms_alpine_snow, 1200.0)
	_build_multimesh_batch("MultiMesh_FrozenPassGreenPines", fir_summer, xforms_alpine_green, 1200.0)
	_build_multimesh_batch("MultiMesh_HubPines", fir_summer, xforms_hub, 1050.0)

func _populate_palm_promenade() -> void:
	var palm_mesh: Mesh = PropMeshUtils.load_centered_mesh("res://assets/models/foliage/coconut_palm.glb", 1.65, 0.14)
	if not palm_mesh:
		palm_mesh = PropMeshUtils.load_centered_mesh("res://assets/models/foliage/palm_tree_opt.glb", 2.0, 0.12)
	if not palm_mesh:
		return
	var palm_xforms: Array[Transform3D] = []
	for i: int in range(520):
		var pt: Vector2 = _sample_roadside_in_quadrant(900.0, 2550.0, 200.0, 2400.0, 6.8, 95.0) if i < 400 else Vector2(rng.randf_range(950.0, 2320.0), rng.randf_range(220.0, 2300.0))
		var py: float = terrain_gen.get_height(pt.x, pt.y)
		if py < 2.2:
			continue
		if not _is_road_clear(pt.x, pt.y, 9.5):
			continue
		var sc: float = rng.randf_range(0.82, 1.35)
		palm_xforms.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sc, sc * rng.randf_range(0.9, 1.18), sc)), Vector3(pt.x, py, pt.y)))
	_build_multimesh_batch("MultiMesh_CoastPalms", palm_mesh, palm_xforms, 1050.0)

func _populate_desert_flora() -> void:
	var saguaro_mesh: Mesh = PropMeshUtils.load_centered_mesh("res://assets/models/foliage/saguaro_cactus.glb", 1.35, 0.12, "bark")
	var yucca_rosette: Mesh = PropMeshUtils.load_centered_mesh("res://assets/models/foliage/yucca_beaked.glb", 1.85, 0.08)
	var yucca_tall: Mesh = PropMeshUtils.load_centered_mesh("res://assets/models/foliage/yucca_tall.glb", 1.85, 0.10)
	var scrub_mesh: Mesh = PropMeshUtils.load_centered_mesh("res://assets/models/foliage/grass_medium_01/grass_medium_01.gltf", 4.8, 0.03, "small_a_lod0")

	if saguaro_mesh:
		var cactus_xforms: Array[Transform3D] = []
		for i: int in range(440):
			var pt: Vector2 = _sample_roadside_in_quadrant(-2350.0, -220.0, 220.0, 2350.0, 7.0, 90.0) if i < 360 else Vector2(rng.randf_range(-2350.0, -240.0), rng.randf_range(240.0, 2350.0))
			if not _is_road_clear(pt.x, pt.y, 9.5):
				continue
			if terrain_gen.get_normal(pt.x, pt.y).y < 0.78:
				continue
			var cy: float = terrain_gen.get_height(pt.x, pt.y)
			var sc: float = rng.randf_range(0.85, 1.50)
			cactus_xforms.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sc, sc * rng.randf_range(0.9, 1.2), sc)), Vector3(pt.x, cy, pt.y)))
		_build_multimesh_batch("MultiMesh_DustBowlSaguaros", saguaro_mesh, cactus_xforms, 780.0)

	if yucca_rosette:
		var y_xforms: Array[Transform3D] = []
		for i: int in range(380):
			var pt: Vector2 = _sample_roadside_in_quadrant(-2350.0, -200.0, 200.0, 2350.0, 5.5, 65.0)
			if not _is_road_clear(pt.x, pt.y, 7.5):
				continue
			var sc: float = rng.randf_range(0.75, 1.35)
			y_xforms.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sc, sc, sc)), Vector3(pt.x, terrain_gen.get_height(pt.x, pt.y), pt.y)))
		_build_multimesh_batch("MultiMesh_DustBowlYuccas", yucca_rosette, y_xforms, 420.0)

	if yucca_tall:
		var yt_xforms: Array[Transform3D] = []
		for i: int in range(260):
			var pt: Vector2 = _sample_roadside_in_quadrant(-2350.0, -220.0, 220.0, 2350.0, 7.5, 95.0)
			if not _is_road_clear(pt.x, pt.y, 9.0):
				continue
			var sc: float = rng.randf_range(0.80, 1.40)
			yt_xforms.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sc, sc, sc)), Vector3(pt.x, terrain_gen.get_height(pt.x, pt.y), pt.y)))
		_build_multimesh_batch("MultiMesh_DustBowlJoshuaYuccas", yucca_tall, yt_xforms, 560.0)

	if scrub_mesh:
		var desert_bushes: Array[Transform3D] = []
		var hub_bushes: Array[Transform3D] = []
		for i: int in range(1100):
			var pt: Vector2 = _sample_roadside_in_quadrant(-2350.0, -180.0, 180.0, 2350.0, 4.0, 68.0)
			if not _is_road_clear(pt.x, pt.y, 7.5):
				continue
			var by: float = terrain_gen.get_height(pt.x, pt.y)
			var sc: float = rng.randf_range(0.75, 1.55)
			desert_bushes.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sc, sc * 1.15, sc)), Vector3(pt.x, by, pt.y)))
		for i: int in range(420):
			var ang: float = rng.randf() * TAU
			var rad: float = rng.randf_range(24.0, 320.0)
			var bx: float = cos(ang) * rad
			var bz: float = sin(ang) * rad
			if not _is_road_clear(bx, bz, 8.5):
				continue
			var by: float = terrain_gen.get_height(bx, bz)
			var sc: float = rng.randf_range(0.65, 1.35)
			hub_bushes.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sc, sc, sc)), Vector3(bx, by, bz)))
		_build_multimesh_batch("MultiMesh_DesertBushes", scrub_mesh, desert_bushes, 420.0, Color(0.86, 0.72, 0.44), false)
		_build_multimesh_batch("MultiMesh_HubBushes", scrub_mesh, hub_bushes, 360.0, Color(0.62, 0.82, 0.48), false)

func _populate_desert_rocks() -> void:
	var granite_boulder: Mesh = PropMeshUtils.load_centered_mesh("res://assets/models/rocks/boulder_01/boulder_01.gltf", 2.2, 0.30)
	var sandstone_slab: Mesh = PropMeshUtils.load_centered_mesh("res://assets/models/rocks/namaqualand_boulder_02/namaqualand_boulder_02.gltf", 2.4, 0.25)
	var cliff_spire: Mesh = PropMeshUtils.load_centered_mesh("res://assets/models/rocks/cliff_rocks_pack.glb", 0.045, 0.40, "smallrockcluster_cliffs")

	var x_dust: Array[Transform3D] = []
	for i: int in range(180):
		var pt: Vector2 = _sample_roadside_in_quadrant(-2350.0, -220.0, 220.0, 2350.0, 8.5, 95.0)
		if not _is_road_clear(pt.x, pt.y, 11.5):
			continue
		var ry: float = terrain_gen.get_height(pt.x, pt.y) - 0.30
		var sc: float = rng.randf_range(0.75, 1.55)
		var bas := Basis.from_euler(Vector3(rng.randf_range(-0.15, 0.15), rng.randf() * TAU, rng.randf_range(-0.15, 0.15))).scaled(Vector3(sc * rng.randf_range(1.0, 1.3), sc * 0.90, sc))
		x_dust.append(Transform3D(bas, Vector3(pt.x, ry, pt.y)))
	_build_multimesh_batch("MultiMesh_DustBowlRocks", sandstone_slab, x_dust, 750.0, Color(0.84, 0.50, 0.30))

	var x_volcano: Array[Transform3D] = []
	for i: int in range(440):
		var pt: Vector2 = _sample_roadside_in_quadrant(160.0, 2350.0, -2350.0, -160.0, 7.2, 130.0)
		if i >= 280:
			var ang_v: float = rng.randf() * TAU
			var rad_v: float = rng.randf_range(235.0, 620.0)
			pt = Vector2(980.0 + cos(ang_v) * rad_v, -1140.0 + sin(ang_v) * rad_v)
		if Vector2(pt.x - 980.0, pt.y + 1140.0).length() < 230.0:
			continue
		if not _is_road_clear(pt.x, pt.y, 11.5):
			continue
		if terrain_gen.get_normal(pt.x, pt.y).y < 0.62:
			continue
		var ry: float = terrain_gen.get_height(pt.x, pt.y) - 0.85
		var sc: float = rng.randf_range(0.75, 2.25)
		var bas := Basis.from_euler(Vector3(rng.randf_range(-0.14, 0.14), rng.randf() * TAU, rng.randf_range(-0.14, 0.14))).scaled(Vector3(sc * rng.randf_range(0.95, 1.3), sc * 0.88, sc))
		x_volcano.append(Transform3D(bas, Vector3(pt.x, ry, pt.y)))
	_build_multimesh_batch("MultiMesh_VolcanoBasaltCrags", granite_boulder, x_volcano, 850.0, Color(0.24, 0.22, 0.24))

	var x_granite: Array[Transform3D] = []
	for i: int in range(160):
		var pt: Vector2 = _sample_roadside_in_quadrant(-2300.0, -260.0, -2300.0, -260.0, 9.0, 110.0)
		if not _is_road_clear(pt.x, pt.y, 12.0):
			continue
		var ry: float = terrain_gen.get_height(pt.x, pt.y) - 0.35
		var sc: float = rng.randf_range(0.70, 1.50)
		var bas := Basis.from_euler(Vector3(rng.randf_range(-0.15, 0.15), rng.randf() * TAU, rng.randf_range(-0.15, 0.15))).scaled(Vector3(sc, sc * 0.85, sc))
		x_granite.append(Transform3D(bas, Vector3(pt.x, ry, pt.y)))
	_build_multimesh_batch("MultiMesh_SnowGraniteBoulders", sandstone_slab, x_granite, 750.0, Color(0.70, 0.74, 0.80))

	# Coastal rocky shoreline breakwaters
	var x_coast_rocks: Array[Transform3D] = []
	for i: int in range(90):
		var z_c: float = rng.randf_range(150.0, 2150.0)
		var curve_x: float = 2160.0 - 0.00014 * (z_c - 200.0) * (z_c - 200.0)
		var x_c: float = curve_x + rng.randf_range(28.0, 68.0)
		var cy: float = terrain_gen.get_height(x_c, z_c) - 0.25
		var sc: float = rng.randf_range(0.75, 1.65)
		x_coast_rocks.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sc, sc * 0.75, sc)), Vector3(x_c, cy, z_c)))
	_build_multimesh_batch("MultiMesh_CoastBreakwaterRocks", granite_boulder, x_coast_rocks, 850.0, Color(0.55, 0.56, 0.54))

func _populate_ground_grass() -> void:
	var green_grass: Mesh = PropMeshUtils.load_centered_mesh("res://assets/models/foliage/grass_medium_01/grass_medium_01.gltf", 3.6, 0.02, "small_a_lod0")
	var dry_grass: Mesh = PropMeshUtils.load_centered_mesh("res://assets/models/foliage/dry_grass.glb", 0.0072, 0.03, "grasspatch1")

	if green_grass:
		var hub_g: Array[Transform3D] = []
		var coast_g: Array[Transform3D] = []
		for i: int in range(2800):
			var pt: Vector2 = _sample_roadside_in_quadrant(-320.0, 320.0, -320.0, 320.0, 1.5, 48.0)
			if not _is_road_clear(pt.x, pt.y, 2.5):
				continue
			var gy: float = terrain_gen.get_height(pt.x, pt.y)
			var sc: float = rng.randf_range(0.85, 1.65)
			hub_g.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sc, sc, sc)), Vector3(pt.x, gy, pt.y)))
		for i: int in range(1800):
			var pt: Vector2 = _sample_roadside_in_quadrant(1100.0, 2250.0, 200.0, 2200.0, 2.0, 42.0)
			var gy: float = terrain_gen.get_height(pt.x, pt.y)
			if gy < 3.0 or not _is_road_clear(pt.x, pt.y, 2.5):
				continue
			var sc: float = rng.randf_range(0.85, 1.55)
			coast_g.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sc, sc, sc)), Vector3(pt.x, gy, pt.y)))
		_build_multimesh_batch("MultiMesh_HubMeadowGrass", green_grass, hub_g, 220.0, Color(1, 1, 1, 1), false)
		_build_multimesh_batch("MultiMesh_CoastMeadowGrass", green_grass, coast_g, 220.0, Color(0.95, 1.0, 0.85), false)

	if dry_grass:
		var dg_xforms: Array[Transform3D] = []
		for i: int in range(2500):
			var pt: Vector2 = _sample_roadside_in_quadrant(-2150.0, -260.0, 260.0, 2150.0, 1.8, 40.0)
			if not _is_road_clear(pt.x, pt.y, 2.2):
				continue
			var gy: float = terrain_gen.get_height(pt.x, pt.y)
			var sc: float = rng.randf_range(0.85, 1.65)
			dg_xforms.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sc, sc, sc)), Vector3(pt.x, gy, pt.y)))
		_build_multimesh_batch("MultiMesh_DesertDryGrass", dry_grass, dg_xforms, 260.0, Color(1, 1, 1, 1), false)
