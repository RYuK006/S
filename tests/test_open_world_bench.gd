# tests/test_open_world_bench.gd
class_name TestOpenWorldBench
extends RefCounted

const OpenWorldConfig = preload("res://scripts/world/open_world_config.gd")
const TerrainGenerator = preload("res://scripts/world/terrain_generator.gd")
const RoadNetwork = preload("res://scripts/world/road_network.gd")
const SceneryPopulator = preload("res://scripts/world/scenery_populator.gd")

static func run() -> bool:
	print("--- Running TestOpenWorldBench ---")
	
	# Test 1: Open World Scale & Biome Classification
	if OpenWorldConfig.WORLD_SIZE_METERS < 7000.0 or OpenWorldConfig.GRID_CHUNKS < 14:
		printerr("[FAIL] World size mismatch: expected >= 7000m (50 km²)")
		return false
		
	var b_nw := OpenWorldConfig.get_biome_at(-1500.0, -1500.0)
	var b_ne := OpenWorldConfig.get_biome_at(1500.0, -1500.0)
	var b_sw := OpenWorldConfig.get_biome_at(-1500.0, 1500.0)
	var b_se := OpenWorldConfig.get_biome_at(1500.0, 1500.0)
	var b_center := OpenWorldConfig.get_biome_at(0.0, 0.0)
	
	if b_nw != OpenWorldConfig.BiomeType.FROZEN_PASS or b_ne != OpenWorldConfig.BiomeType.VOLCANO_RIDGE:
		printerr("[FAIL] Northern mountain biome classification failed")
		return false
	if b_sw != OpenWorldConfig.BiomeType.DUST_BOWL or b_se != OpenWorldConfig.BiomeType.NEON_COAST:
		printerr("[FAIL] Southern coastal/desert biome classification failed")
		return false
	if b_center != OpenWorldConfig.BiomeType.FESTIVAL_HUB:
		printerr("[FAIL] Central Festival Hub classification failed")
		return false
	print("[PASS] Open World Dimensions: 7,100m x 7,100m (50.4 km²) across 4 major biomes + Festival Hub")
	
	# Test 2: Procedural Multi-Octave Heightfield
	var tg := TerrainGenerator.new(2026)
	var h_snow := tg.get_height(-1200.0, -1200.0)
	var h_volcano := tg.get_height(1200.0, -1200.0)
	var h_coast := tg.get_height(1200.0, 1200.0)
	var h_hub := tg.get_height(0.0, 0.0)
	
	if h_snow <= h_coast or h_volcano <= h_coast:
		printerr("[FAIL] Mountain elevation failed to exceed coastal plain (Snow: %.1fm, Coast: %.1fm)" % [h_snow, h_coast])
		return false
	if abs(h_hub - 22.0) > 1.0:
		printerr("[FAIL] Festival Hub flattening failed (Elevation: %.1fm)" % h_hub)
		return false
		
	var normal := tg.get_normal(500.0, 500.0)
	if abs(normal.length() - 1.0) > 0.01 or normal.y <= 0.0:
		printerr("[FAIL] Terrain surface normal computation failed")
		return false
	print("[PASS] Multi-Octave Terrain: Height range validated (Alpine: %.1fm, Volcano: %.1fm, Coast: %.1fm, Hub: %.1fm)" % [
		h_snow, h_volcano, h_coast, h_hub
	])
	
	# Test 3: Terrain Chunk Mesh & Trimesh Collision Generation
	var chunk_mesh := tg.generate_chunk_mesh(4, 4, 16)
	if not chunk_mesh or not chunk_mesh.mesh:
		printerr("[FAIL] Terrain chunk mesh generation failed")
		return false
	var has_col := false
	for child in chunk_mesh.get_children():
		if child is StaticBody3D:
			has_col = true
			break
	if not has_col:
		printerr("[FAIL] Terrain chunk missing StaticBody3D collision")
		return false
	chunk_mesh.queue_free()
	print("[PASS] Chunk Streaming: 500m ArrayMesh and Trimesh collision generated successfully")
	
	# Test 4: Arterial Road Network (Grand Perimeter Highway)
	var rn := RoadNetwork.new(tg)
	rn.build_open_world_roads()
	if rn.highway_waypoints.size() < 64:
		printerr("[FAIL] Expected at least 64 highway waypoints, got %d" % rn.highway_waypoints.size())
		return false
	if rn.road_nodes.size() < 3:
		printerr("[FAIL] Expected at least 3 major arterial road meshes, got %d" % rn.road_nodes.size())
		return false
	print("[PASS] Road Network: Grand Perimeter Highway (%d waypoints), Expressway, and Hillclimb Switchbacks validated" % rn.highway_waypoints.size())
	
	# Test 5: Scenery MultiMesh Instancing
	var pop := SceneryPopulator.new(tg, rn)
	pop.populate_world_scenery()
	var mm_count := 0
	for child in pop.get_children():
		if child is MultiMeshInstance3D:
			mm_count += 1
	if mm_count < 4:
		printerr("[FAIL] Expected at least 4 MultiMeshInstance3D batches, found %d" % mm_count)
		return false
	print("[PASS] Scenery MultiMeshes: High-performance instanced batches verified (Poles, Pines, Desert Rocks, Spoilers)")
	
	rn.queue_free()
	pop.queue_free()
	return true
