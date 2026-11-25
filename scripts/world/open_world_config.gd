# scripts/world/open_world_config.gd
class_name OpenWorldConfig
extends RefCounted

const WORLD_SIZE_METERS: float = 4000.0
const HALF_SIZE: float = WORLD_SIZE_METERS * 0.5
const CHUNK_SIZE: float = 500.0
const GRID_CHUNKS: int = int(WORLD_SIZE_METERS / CHUNK_SIZE) # 8x8 = 64 chunks

enum BiomeType {
	DUST_BOWL,
	NEON_COAST,
	FROZEN_PASS,
	VOLCANO_RIDGE,
	FESTIVAL_HUB
}

const BIOME_DATA = {
	BiomeType.DUST_BOWL: {
		"name": "The Dust Bowl",
		"base_height": 18.0,
		"height_variation": 24.0,
		"primary_color": Color(0.72, 0.44, 0.20),
		"rock_color": Color(0.52, 0.28, 0.14),
		"surface_type": "sand",
		"friction": 0.85
	},
	BiomeType.NEON_COAST: {
		"name": "Neon Coast & Docks",
		"base_height": 4.0,
		"height_variation": 12.0,
		"primary_color": Color(0.14, 0.16, 0.18),
		"rock_color": Color(0.10, 0.12, 0.14),
		"surface_type": "asphalt_wet",
		"friction": 1.05
	},
	BiomeType.FROZEN_PASS: {
		"name": "Frozen Pass",
		"base_height": 70.0,
		"height_variation": 90.0,
		"primary_color": Color(0.92, 0.95, 1.0),
		"rock_color": Color(0.32, 0.34, 0.38),
		"surface_type": "snow",
		"friction": 0.62
	},
	BiomeType.VOLCANO_RIDGE: {
		"name": "Volcano Ridge",
		"base_height": 85.0,
		"height_variation": 110.0,
		"primary_color": Color(0.08, 0.08, 0.09),
		"rock_color": Color(0.05, 0.05, 0.06),
		"surface_type": "packed_dirt",
		"friction": 0.95
	},
	BiomeType.FESTIVAL_HUB: {
		"name": "Horizon Festival Central",
		"base_height": 22.0,
		"height_variation": 4.0,
		"primary_color": Color(0.22, 0.23, 0.26),
		"rock_color": Color(0.18, 0.18, 0.20),
		"surface_type": "asphalt_dry",
		"friction": 1.00
	}
}

static func get_biome_at(x: float, z: float) -> BiomeType:
	var dist_from_center: float = Vector2(x, z).length()
	if dist_from_center < 350.0:
		return BiomeType.FESTIVAL_HUB
		
	# Quadrant division with organic noise blending
	if z < 0.0:
		if x < 0.0:
			return BiomeType.FROZEN_PASS
		else:
			return BiomeType.VOLCANO_RIDGE
	else:
		if x < 0.0:
			return BiomeType.DUST_BOWL
		else:
			return BiomeType.NEON_COAST
