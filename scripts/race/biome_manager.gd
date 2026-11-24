# scripts/race/biome_manager.gd
class_name BiomeManager
extends Node

signal biome_changed(biome_id: String)

@export var world_environment: WorldEnvironment
@export var sun_light: DirectionalLight3D

var current_biome_id: String = "dust_bowl"
var current_grip_multiplier: float = 1.0

func _ready() -> void:
	apply_biome(current_biome_id)

func apply_biome(biome_id: String) -> bool:
	if not CampaignData.BIOMES.has(biome_id):
		return false
		
	current_biome_id = biome_id
	var b_info: Dictionary = CampaignData.BIOMES[biome_id]
	
	# Determine biome grip factor
	if biome_id == "dust_bowl":
		current_grip_multiplier = 0.88
	elif biome_id == "neon_docks":
		current_grip_multiplier = 1.05
	elif biome_id == "frozen_pass":
		current_grip_multiplier = 0.62
	elif biome_id == "volcano_ridge":
		current_grip_multiplier = 0.95
	else:
		current_grip_multiplier = 1.00
		
	# Apply visual environment if nodes exist
	if world_environment and world_environment.environment:
		var env := world_environment.environment
		var sky_hex: String = b_info.get("sky_color", "#c89454")
		var ground_hex: String = b_info.get("ground_color", "#5a4d3e")
		var sky_col := Color.from_string(sky_hex, Color.ORANGE)
		var ground_col := Color.from_string(ground_hex, Color.DARK_SLATE_GRAY)
		
		if env.sky and env.sky.sky_material is ProceduralSkyMaterial:
			var sky_mat := env.sky.sky_material as ProceduralSkyMaterial
			sky_mat.sky_top_color = sky_col.darkened(0.3)
			sky_mat.sky_horizon_color = sky_col
			sky_mat.ground_bottom_color = ground_col.darkened(0.4)
			sky_mat.ground_horizon_color = ground_col
			
		env.ambient_light_color = sky_col.lerp(Color.WHITE, 0.4)
		
	if sun_light:
		if biome_id == "dust_bowl":
			sun_light.light_color = Color(1.0, 0.95, 0.85)
			sun_light.light_energy = 1.3
		elif biome_id == "neon_docks":
			sun_light.light_color = Color(0.3, 0.5, 0.8)
			sun_light.light_energy = 0.4
		elif biome_id == "frozen_pass":
			sun_light.light_color = Color(0.85, 0.92, 1.0)
			sun_light.light_energy = 1.1
		elif biome_id == "volcano_ridge":
			sun_light.light_color = Color(1.0, 0.45, 0.2)
			sun_light.light_energy = 1.5
			
	biome_changed.emit(current_biome_id)
	return true

func get_surface_grip(surface_name: String) -> float:
	var base_grip: float = float(CampaignData.SURFACE_GRIP_TABLE.get(surface_name, 1.0))
	return base_grip * current_grip_multiplier
