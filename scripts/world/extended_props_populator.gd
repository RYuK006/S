# scripts/world/extended_props_populator.gd
# Distributes 60+ verified high-detail 3D city, highway, paddock, harbor & biome props
# cleanly outside every road geometry with AABB-aware clearance & heterogeneous physics registration.
class_name ExtendedPropsPopulator
extends RefCounted

const TerrainGenerator = preload("res://scripts/world/terrain_generator.gd")
const RoadNetwork = preload("res://scripts/world/road_network.gd")
const PropMeshUtils = preload("res://scripts/world/prop_mesh_utils.gd")

static func populate_all(tg: TerrainGenerator, rn: RoadNetwork, rng: RandomNumberGenerator, sample_fn: Callable, mm_fn: Callable) -> void:
	_populate_town_streets(tg, rn, rng, mm_fn)
	_populate_highway_corridors(tg, rn, rng, mm_fn)
	_populate_paddock_festival(tg, rn, rng, sample_fn, mm_fn)
	_populate_harbor_industrial(tg, rn, rng, mm_fn)
	_populate_biome_nature_and_cabins(tg, rn, rng, sample_fn, mm_fn)

static func _load_fit(path: String, desired_max_dim: float, embed: float = 0.04, filter: String = "") -> Mesh:
	return PropMeshUtils.load_centered_mesh(path, 1.0, embed, filter, desired_max_dim)

static func _scatter_along_roads(tg: TerrainGenerator, rn: RoadNetwork, road_filter: String, stride_m: float, offset_min: float, offset_max: float, min_dist: float, max_items: int, rng: RandomNumberGenerator, fixed_scale: float = 1.0, face_road: bool = true) -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	if not rn or rn.all_road_segments.is_empty():
		return out
	var accum: float = 0.0
	for seg: Dictionary in rn.all_road_segments:
		var rname: String = str(seg.get("road", "")).to_lower()
		if not road_filter.is_empty() and not (road_filter in rname):
			continue
		var p0: Vector3 = seg["p0"]
		var p1: Vector3 = seg["p1"]
		var seg_v := Vector2(p1.x - p0.x, p1.z - p0.z)
		var seg_l: float = seg_v.length()
		if seg_l < 0.5:
			continue
		accum += seg_l
		if accum < stride_m:
			continue
		accum = fmod(accum, stride_m)
		var fwd2: Vector2 = seg_v / seg_l
		var right2 := Vector2(fwd2.y, -fwd2.x)
		var side: float = -1.0 if (out.size() % 2 == 0) else 1.0
		var half_w: float = float(seg.get("half_w", 5.5))
		var out_d: float = half_w + rng.randf_range(offset_min, offset_max)
		var mid: Vector3 = p0.lerp(p1, 0.5)
		var px: float = mid.x + right2.x * side * out_d
		var pz: float = mid.z + right2.y * side * out_d
		if absf(px) > 3300.0 or absf(pz) > 3300.0:
			continue
		if not rn.is_point_clear_of_roads(px, pz, min_dist, ""):
			continue
		var py: float = tg.get_height(px, pz)
		if py < 2.1:
			continue
		if tg.get_normal(px, pz).y < 0.78:
			continue
		var yaw: float = atan2(-right2.x * side, -right2.y * side) if face_road else rng.randf() * TAU
		var sc: float = fixed_scale * rng.randf_range(0.92, 1.08)
		out.append(Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(sc, sc, sc)), Vector3(px, py, pz)))
		if out.size() >= max_items:
			break
	return out

static func _spawn_prop_set(tg: TerrainGenerator, rn: RoadNetwork, rng: RandomNumberGenerator, mm_fn: Callable, specs: Array[Dictionary]) -> void:
	for sp: Dictionary in specs:
		var path: String = str(sp["path"])
		var batch: String = str(sp["batch"])
		var m: Mesh = _load_fit(path, float(sp["dim"]), float(sp.get("embed", 0.04)), str(sp.get("filter", "")))
		if not m:
			continue
		var aabb_sz: Vector3 = m.get_aabb().size
		var foot_r: float = maxf(float(sp.get("clear", 3.0)), 0.52 * Vector2(aabb_sz.x, aabb_sz.z).length() + 1.4)
		var xforms: Array[Transform3D] = _scatter_along_roads(
			tg, rn,
			str(sp.get("road", "")),
			float(sp.get("stride", 48.0)),
			float(sp.get("off_min", 4.5)),
			float(sp.get("off_max", 12.0)),
			foot_r,
			int(sp.get("max", 60)),
			rng, 1.0,
			bool(sp.get("face", true))
		)
		if not xforms.is_empty():
			var col_tint: Color = sp["tint"] if sp.has("tint") else Color(1, 1, 1, 1)
			mm_fn.call(batch, m, xforms, float(sp.get("vis", 620.0)), col_tint, true)

static func _populate_town_streets(tg: TerrainGenerator, rn: RoadNetwork, rng: RandomNumberGenerator, mm_fn: Callable) -> void:
	var specs: Array[Dictionary] = [
		{"batch": "MM_TownLampClassic", "path": "res://assets/models/props/street_lamp_01/street_lamp_01.gltf", "dim": 5.4, "road": "town", "stride": 38.0, "off_min": 2.4, "off_max": 3.4, "clear": 2.2, "max": 85},
		{"batch": "MM_TownLampModern", "path": "res://assets/models/props/street_lamp_02/street_lamp_02.gltf", "dim": 6.2, "road": "harbor town", "stride": 36.0, "off_min": 2.5, "off_max": 3.5, "clear": 2.2, "max": 75},
		{"batch": "MM_TownFireHydrant", "path": "res://assets/models/props/fire_hydrant/fire_hydrant.gltf", "dim": 1.05, "road": "st", "stride": 55.0, "off_min": 2.2, "off_max": 3.2, "clear": 2.0, "max": 55},
		{"batch": "MM_TownBusShelter", "path": "res://assets/models/props/bus_stop_shelter.glb", "dim": 4.8, "road": "ave", "stride": 145.0, "off_min": 4.8, "off_max": 6.8, "clear": 4.2, "max": 24},
		{"batch": "MM_TownBollard", "path": "res://assets/models/props/steel_bollard.glb", "dim": 1.15, "road": "plaza", "stride": 24.0, "off_min": 2.0, "off_max": 2.8, "clear": 1.8, "max": 60},
		{"batch": "MM_TownMailbox", "path": "res://assets/models/props/mailbox_street.glb", "dim": 1.35, "road": "st", "stride": 95.0, "off_min": 2.6, "off_max": 4.2, "clear": 2.1, "max": 36},
		{"batch": "MM_TownTrashCan", "path": "res://assets/models/props/metal_trash_can/metal_trash_can.gltf", "dim": 1.10, "road": "st", "stride": 62.0, "off_min": 2.3, "off_max": 3.5, "clear": 1.9, "max": 48},
		{"batch": "MM_TownRecycleBin", "path": "res://assets/models/props/street_trash_can.glb", "dim": 1.25, "road": "ave", "stride": 68.0, "off_min": 2.5, "off_max": 3.8, "clear": 2.1, "max": 42},
		{"batch": "MM_TownVendingMachine", "path": "res://assets/models/props/street_vending_machine.glb", "dim": 2.25, "road": "ave", "stride": 115.0, "off_min": 4.2, "off_max": 6.2, "clear": 3.0, "max": 26},
		{"batch": "MM_TownFuseBox", "path": "res://assets/models/props/electric_transformer_box.glb", "dim": 1.80, "road": "st", "stride": 105.0, "off_min": 3.5, "off_max": 5.0, "clear": 2.6, "max": 32},
		{"batch": "MM_TownParkBench", "path": "res://assets/models/props/park_bench_iron.glb", "dim": 2.10, "road": "plaza", "stride": 54.0, "off_min": 3.2, "off_max": 4.8, "clear": 2.4, "max": 45},
		{"batch": "MM_TownStreetSeating", "path": "res://assets/models/props/modular_street_seating/modular_street_seating.gltf", "dim": 2.40, "road": "marina", "stride": 64.0, "off_min": 3.5, "off_max": 5.5, "clear": 2.6, "max": 38},
		{"batch": "MM_TownShopBuilding", "path": "res://assets/models/props/modern_shop_building.glb", "dim": 9.8, "road": "marina", "stride": 110.0, "off_min": 9.5, "off_max": 18.0, "clear": 8.0, "max": 28},
		{"batch": "MM_TownLpgTank", "path": "res://assets/models/props/small_lpg_tank/small_lpg_tank.gltf", "dim": 1.15, "road": "st", "stride": 125.0, "off_min": 3.5, "off_max": 6.0, "clear": 2.2, "max": 32},
		{"batch": "MM_TownWineBarrels", "path": "res://assets/models/props/wooden_barrels_01/wooden_barrels_01.gltf", "dim": 1.35, "road": "cross", "stride": 88.0, "off_min": 3.8, "off_max": 6.8, "clear": 2.4, "max": 34},
		{"batch": "MM_TownTrafficSign", "path": "res://assets/models/props/traffic_stop_sign_kit.glb", "dim": 3.2, "road": "ave", "stride": 78.0, "off_min": 2.4, "off_max": 3.4, "clear": 2.2, "max": 44}
	]
	_spawn_prop_set(tg, rn, rng, mm_fn, specs)

static func _populate_highway_corridors(tg: TerrainGenerator, rn: RoadNetwork, rng: RandomNumberGenerator, mm_fn: Callable) -> void:
	var specs: Array[Dictionary] = [
		{"batch": "MM_HwyBillboard", "path": "res://assets/models/props/highway_billboard.glb", "dim": 11.5, "road": "highway", "stride": 210.0, "off_min": 9.5, "off_max": 16.0, "clear": 7.8, "max": 32, "vis": 820.0},
		{"batch": "MM_HwyConcreteBarrier", "path": "res://assets/models/props/concrete_road_barrier/concrete_road_barrier.gltf", "dim": 3.4, "road": "expressway", "stride": 52.0, "off_min": 2.4, "off_max": 3.4, "clear": 2.4, "max": 95},
		{"batch": "MM_HwyConstructionBarricade", "path": "res://assets/models/props/road_construction_barrier.glb", "dim": 2.4, "road": "boulevard", "stride": 95.0, "off_min": 2.8, "off_max": 4.2, "clear": 2.3, "max": 48},
		{"batch": "MM_HwyGasPump", "path": "res://assets/models/props/gas_station_pump.glb", "dim": 2.6, "road": "highway", "stride": 260.0, "off_min": 8.5, "off_max": 14.0, "clear": 5.0, "max": 18},
		{"batch": "MM_HwyRetroFuelPump", "path": "res://assets/models/props/gas_pump_retro.glb", "dim": 2.5, "road": "canyon", "stride": 240.0, "off_min": 8.0, "off_max": 13.0, "clear": 4.6, "max": 16},
		{"batch": "MM_HwyWindTurbine", "path": "res://assets/models/props/wind_turbine_tall.glb", "dim": 32.0, "road": "expressway", "stride": 280.0, "off_min": 38.0, "off_max": 85.0, "clear": 18.0, "max": 16, "vis": 850.0, "face": false},
		{"batch": "MM_HwySolarPole", "path": "res://assets/models/props/solar_street_panel.glb", "dim": 5.8, "road": "canyon", "stride": 82.0, "off_min": 3.5, "off_max": 5.5, "clear": 2.8, "max": 46}
	]
	_spawn_prop_set(tg, rn, rng, mm_fn, specs)

static func _populate_paddock_festival(tg: TerrainGenerator, rn: RoadNetwork, rng: RandomNumberGenerator, _sample_fn: Callable, mm_fn: Callable) -> void:
	var specs: Array[Dictionary] = [
		{"batch": "MM_PaddockRiggingStage", "path": "res://assets/models/props/rigging_truss_stage.glb", "dim": 8.5, "road": "plaza", "stride": 140.0, "off_min": 8.5, "off_max": 14.0, "clear": 6.5, "max": 12},
		{"batch": "MM_PaddockCrowdBarriers", "path": "res://assets/models/props/metal_barrier_crowd.glb", "dim": 2.6, "road": "starting grid", "stride": 14.0, "off_min": 3.0, "off_max": 4.2, "clear": 2.1, "max": 36},
		{"batch": "MM_PaddockGeneratorYellow", "path": "res://assets/models/props/metal_generator_yellow.glb", "dim": 1.85, "road": "plaza", "stride": 74.0, "off_min": 5.0, "off_max": 9.5, "clear": 2.8, "max": 28},
		{"batch": "MM_PaddockPortableGenerator", "path": "res://assets/models/props/portable_generator/portable_generator.gltf", "dim": 1.65, "road": "grid", "stride": 42.0, "off_min": 4.5, "off_max": 8.5, "clear": 2.5, "max": 28},
		{"batch": "MM_PaddockSearchlight", "path": "res://assets/models/props/portable_searchlight/portable_searchlight.gltf", "dim": 2.8, "road": "plaza", "stride": 58.0, "off_min": 4.8, "off_max": 8.0, "clear": 2.6, "max": 32},
		{"batch": "MM_PaddockWeldingCart", "path": "res://assets/models/props/portable_welding_cart/portable_welding_cart.gltf", "dim": 1.45, "road": "grid", "stride": 38.0, "off_min": 4.0, "off_max": 7.5, "clear": 2.2, "max": 24},
		{"batch": "MM_PaddockJerrycanExplosive", "path": "res://assets/models/props/metal_jerrycan/metal_jerrycan.gltf", "dim": 0.72, "road": "plaza", "stride": 32.0, "off_min": 3.4, "off_max": 6.5, "clear": 2.0, "max": 48},
		{"batch": "MM_PaddockMilCrateWood", "path": "res://assets/models/props/wooden_military_crate/wooden_military_crate.gltf", "dim": 1.35, "road": "plaza", "stride": 36.0, "off_min": 4.0, "off_max": 8.5, "clear": 2.2, "max": 44},
		{"batch": "MM_PaddockPicnicTable", "path": "res://assets/models/props/wooden_picnic_table/wooden_picnic_table.gltf", "dim": 2.2, "road": "plaza", "stride": 46.0, "off_min": 5.5, "off_max": 12.0, "clear": 2.8, "max": 32},
		{"batch": "MM_PaddockLooseTires", "path": "res://assets/models/props/old_tyre/old_tyre.gltf", "dim": 1.05, "road": "grid", "stride": 26.0, "off_min": 4.2, "off_max": 7.5, "clear": 2.2, "max": 48},
		{"batch": "MM_PaddockJacarandaTrees", "path": "res://assets/models/props/jacaranda_tree/jacaranda_tree.gltf", "dim": 9.5, "road": "plaza", "stride": 65.0, "off_min": 9.5, "off_max": 24.0, "clear": 6.5, "max": 45, "vis": 850.0, "face": false}
	]
	_spawn_prop_set(tg, rn, rng, mm_fn, specs)

static func _populate_harbor_industrial(tg: TerrainGenerator, rn: RoadNetwork, rng: RandomNumberGenerator, mm_fn: Callable) -> void:
	var specs: Array[Dictionary] = [
		{"batch": "MM_PortGuardBooth", "path": "res://assets/models/props/guard_booth.glb", "dim": 5.2, "road": "harbor", "stride": 180.0, "off_min": 6.5, "off_max": 10.5, "clear": 5.0, "max": 12},
		{"batch": "MM_PortOverheadCrane", "path": "res://assets/models/props/overhead_crane/overhead_crane.gltf", "dim": 14.0, "road": "harbor", "stride": 220.0, "off_min": 12.0, "off_max": 22.0, "clear": 9.5, "max": 10},
		{"batch": "MM_PortBarrelRedExplosive", "path": "res://assets/models/props/Barrel_01/Barrel_01.gltf", "dim": 1.15, "road": "harbor", "stride": 38.0, "off_min": 3.0, "off_max": 6.0, "clear": 2.0, "max": 58},
		{"batch": "MM_PortBarrelBlueSlide", "path": "res://assets/models/props/Barrel_02/Barrel_02.gltf", "dim": 1.15, "road": "harbor", "stride": 42.0, "off_min": 3.2, "off_max": 6.5, "clear": 2.0, "max": 52},
		{"batch": "MM_PortBarrelRustExplosive", "path": "res://assets/models/props/barrel_03/barrel_03.gltf", "dim": 1.15, "road": "marina", "stride": 48.0, "off_min": 3.5, "off_max": 7.5, "clear": 2.0, "max": 44},
		{"batch": "MM_PortPropaneExplosive", "path": "res://assets/models/props/propane_tank/propane_tank.gltf", "dim": 1.45, "road": "harbor", "stride": 62.0, "off_min": 3.8, "off_max": 7.0, "clear": 2.1, "max": 36},
		{"batch": "MM_PortWoodenCrate1", "path": "res://assets/models/props/wooden_crate_01/wooden_crate_01.gltf", "dim": 1.35, "road": "harbor", "stride": 36.0, "off_min": 3.4, "off_max": 7.0, "clear": 2.2, "max": 56},
		{"batch": "MM_PortWoodenCrate2", "path": "res://assets/models/props/wooden_crate_02/wooden_crate_02.gltf", "dim": 1.55, "road": "marina", "stride": 44.0, "off_min": 3.8, "off_max": 8.0, "clear": 2.4, "max": 48},
		{"batch": "MM_PortWoodenBoxFlat", "path": "res://assets/models/props/CheeseBox_01/CheeseBox_01.gltf", "dim": 1.15, "road": "marina", "stride": 54.0, "off_min": 3.5, "off_max": 6.5, "clear": 2.0, "max": 36},
		{"batch": "MM_PortWoodenPallet", "path": "res://assets/models/props/wooden_pallet.glb", "dim": 1.85, "road": "harbor", "stride": 48.0, "off_min": 3.5, "off_max": 7.5, "clear": 2.4, "max": 44},
		{"batch": "MM_PortChainlinkFence", "path": "res://assets/models/props/modular_chainlink_fence/modular_chainlink_fence.gltf", "dim": 4.2, "road": "harbor", "stride": 56.0, "off_min": 4.2, "off_max": 6.2, "clear": 3.5, "max": 38},
		{"batch": "MM_PortModularPipes", "path": "res://assets/models/props/modular_pipes/modular_pipes.gltf", "dim": 3.8, "road": "harbor", "stride": 72.0, "off_min": 5.5, "off_max": 10.0, "clear": 3.6, "max": 28}
	]
	_spawn_prop_set(tg, rn, rng, mm_fn, specs)

static func _populate_biome_nature_and_cabins(tg: TerrainGenerator, rn: RoadNetwork, rng: RandomNumberGenerator, sample_fn: Callable, mm_fn: Callable) -> void:
	var specs: Array[Dictionary] = [
		{"batch": "MM_CoastLighthouse", "path": "res://assets/models/props/coastal_lighthouse.glb", "dim": 24.0, "road": "coastline", "stride": 380.0, "off_min": 18.0, "off_max": 34.0, "clear": 15.0, "max": 5, "vis": 850.0},
		{"batch": "MM_CoastLifeguardHut", "path": "res://assets/models/props/beach_lifeguard_tower.glb", "dim": 5.2, "road": "coastline", "stride": 145.0, "off_min": 12.0, "off_max": 24.0, "clear": 5.0, "max": 18},
		{"batch": "MM_CoastParasolTable", "path": "res://assets/models/props/beach_parasol_umbrella.glb", "dim": 3.1, "road": "coastline", "stride": 64.0, "off_min": 8.0, "off_max": 18.0, "clear": 3.5, "max": 36},
		{"batch": "MM_CoastWoodenPier", "path": "res://assets/models/props/modular_wooden_pier/modular_wooden_pier.gltf", "dim": 8.0, "road": "coastline", "stride": 220.0, "off_min": 16.0, "off_max": 26.0, "clear": 7.0, "max": 10},
		{"batch": "MM_CoastRowboat", "path": "res://assets/models/props/wooden_rowboat.glb", "dim": 4.2, "road": "coastline", "stride": 150.0, "off_min": 14.0, "off_max": 28.0, "clear": 4.2, "max": 16},
		{"batch": "MM_CoastIslandTree", "path": "res://assets/models/props/island_tree_01/island_tree_01.gltf", "dim": 8.5, "road": "coast", "stride": 52.0, "off_min": 8.0, "off_max": 28.0, "clear": 6.2, "max": 55, "face": false},
		{"batch": "MM_CoastRocksOutcrop", "path": "res://assets/models/props/coast_land_rocks_02/coast_land_rocks_02.gltf", "dim": 4.6, "road": "coast", "stride": 65.0, "off_min": 9.0, "off_max": 25.0, "clear": 4.8, "max": 42, "face": false},
		{"batch": "MM_CoastFern", "path": "res://assets/models/props/fern_02/fern_02.gltf", "dim": 1.35, "road": "coast", "stride": 22.0, "off_min": 3.5, "off_max": 14.0, "clear": 2.2, "max": 110, "vis": 280.0, "face": false},
		{"batch": "MM_DesertHayBale", "path": "res://assets/models/props/hay_bale_round.glb", "dim": 1.75, "road": "dust bowl", "stride": 52.0, "off_min": 4.8, "off_max": 15.0, "clear": 2.5, "max": 60},
		{"batch": "MM_DesertWaterTower", "path": "res://assets/models/props/desert_water_tower.glb", "dim": 11.5, "road": "mesa", "stride": 260.0, "off_min": 14.0, "off_max": 28.0, "clear": 8.5, "max": 10},
		{"batch": "MM_DesertWoodHangar", "path": "res://assets/models/props/wooden_warehouse_shed.glb", "dim": 12.5, "road": "canyon", "stride": 240.0, "off_min": 14.0, "off_max": 28.0, "clear": 9.0, "max": 12},
		{"batch": "MM_DesertJoshuaTree", "path": "res://assets/models/props/joshua_desert_tree.glb", "dim": 5.4, "road": "baja", "stride": 48.0, "off_min": 6.5, "off_max": 26.0, "clear": 4.5, "max": 75, "face": false},
		{"batch": "MM_DesertQuiverTree", "path": "res://assets/models/props/quiver_tree_01/quiver_tree_01.gltf", "dim": 5.8, "road": "shafer", "stride": 54.0, "off_min": 7.0, "off_max": 28.0, "clear": 4.6, "max": 68, "face": false, "tint": Color(0.84, 0.72, 0.58)},
		{"batch": "MM_DesertSandstoneCliff", "path": "res://assets/models/props/namaqualand_cliff_01/namaqualand_cliff_01.gltf", "dim": 14.0, "road": "mesa", "stride": 120.0, "off_min": 16.0, "off_max": 48.0, "clear": 11.5, "max": 34, "face": false, "vis": 850.0, "tint": Color(0.88, 0.62, 0.44)},
		{"batch": "MM_DesertRockCluster", "path": "res://assets/models/rocks/cliff_rocks_pack.glb", "dim": 8.5, "road": "baja", "stride": 85.0, "off_min": 11.0, "off_max": 38.0, "clear": 7.5, "max": 38, "filter": "smallrockcluster_cliffs", "face": false, "tint": Color(0.84, 0.54, 0.36)},
		{"batch": "MM_DesertSucculent", "path": "res://assets/models/props/cheiridopsis_succulent/cheiridopsis_succulent.gltf", "dim": 1.15, "road": "baja", "stride": 20.0, "off_min": 3.0, "off_max": 12.0, "clear": 2.0, "max": 120, "vis": 260.0, "face": false},
		{"batch": "MM_AlpineWoodenCabin", "path": "res://assets/models/props/alpine_wooden_cabin.glb", "dim": 8.8, "road": "alpine", "stride": 220.0, "off_min": 13.0, "off_max": 26.0, "clear": 7.8, "max": 16},
		{"batch": "MM_AlpineFirTree", "path": "res://assets/models/props/fir_tree_01/fir_tree_01.gltf", "dim": 11.0, "road": "frozen", "stride": 38.0, "off_min": 7.5, "off_max": 32.0, "clear": 5.5, "max": 120, "face": false},
		{"batch": "MM_AlpinePineSapling", "path": "res://assets/models/props/pine_sapling_medium/pine_sapling_medium.gltf", "dim": 3.2, "road": "glacier", "stride": 28.0, "off_min": 4.2, "off_max": 16.0, "clear": 3.0, "max": 95, "face": false},
		{"batch": "MM_AlpineBarkDebris", "path": "res://assets/models/props/bark_debris_01/bark_debris_01.gltf", "dim": 1.8, "road": "glacier", "stride": 36.0, "off_min": 3.8, "off_max": 12.0, "clear": 2.4, "max": 60, "face": false},
		{"batch": "MM_VolcanoMoonBoulder", "path": "res://assets/models/props/moon_rock_01/moon_rock_01.gltf", "dim": 6.4, "road": "volcano", "stride": 22.0, "off_min": 6.2, "off_max": 38.0, "clear": 5.2, "max": 170, "face": false, "tint": Color(0.28, 0.25, 0.26)}
	]
	_spawn_prop_set(tg, rn, rng, mm_fn, specs)
	if sample_fn.is_valid():
		pass
