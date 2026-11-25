shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// 5-Way Biome PBR Splat Shader (Forza Horizon 5 Fidelity)
// Blends authentic 1K PBR textures across Grass, Sand, Snow, Volcano Basalt, and Cliff Rock

uniform sampler2D tex_grass_diff : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D tex_grass_nor : hint_normal, filter_linear_mipmap_anisotropic;
uniform sampler2D tex_grass_rough : hint_default_white, filter_linear_mipmap_anisotropic;

uniform sampler2D tex_sand_diff : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D tex_sand_nor : hint_normal, filter_linear_mipmap_anisotropic;
uniform sampler2D tex_sand_rough : hint_default_white, filter_linear_mipmap_anisotropic;

uniform sampler2D tex_snow_diff : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D tex_snow_nor : hint_normal, filter_linear_mipmap_anisotropic;
uniform sampler2D tex_snow_rough : hint_default_white, filter_linear_mipmap_anisotropic;

uniform sampler2D tex_volcano_diff : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D tex_volcano_nor : hint_normal, filter_linear_mipmap_anisotropic;
uniform sampler2D tex_volcano_rough : hint_default_white, filter_linear_mipmap_anisotropic;

uniform sampler2D tex_cliff_diff : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D tex_cliff_nor : hint_normal, filter_linear_mipmap_anisotropic;
uniform sampler2D tex_cliff_rough : hint_default_white, filter_linear_mipmap_anisotropic;

uniform float uv_scale : hint_range(0.01, 0.5) = 0.08;
uniform float micro_uv_scale : hint_range(0.1, 2.0) = 0.45;

void fragment() {
	vec3 world_pos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 world_norm = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	
	// Dual-scale UVs to break tiling across massive 50 km² distances
	vec2 uv_macro = world_pos.xz * uv_scale;
	vec2 uv_micro = world_pos.xz * micro_uv_scale;
	
	// 1. Calculate Biome Weights from World Coordinates
	float dist_from_hub = length(world_pos.xz);
	float w_hub = clamp(1.0 - (dist_from_hub / 500.0), 0.0, 1.0);
	w_hub = w_hub * w_hub * (3.0 - 2.0 * w_hub); // smoothstep
	
	float blend_zone = 300.0;
	float w_east = clamp((world_pos.x + blend_zone) / (2.0 * blend_zone), 0.0, 1.0);
	float w_south = clamp((world_pos.z + blend_zone) / (2.0 * blend_zone), 0.0, 1.0);
	
	float w_snow = (1.0 - w_east) * (1.0 - w_south) * (1.0 - w_hub);     // NW: Frozen Pass
	float w_volcano = w_east * (1.0 - w_south) * (1.0 - w_hub);          // NE: Volcano Ridge
	float w_sand = ((1.0 - w_east) * w_south + w_east * w_south * 0.7) * (1.0 - w_hub); // SW & SE Coast
	float w_grass = w_hub + (w_east * w_south * 0.3) * (1.0 - w_hub);    // Central Hub + Coast inland
	
	// Normalize weights
	float total_w = w_grass + w_sand + w_snow + w_volcano + 0.0001;
	w_grass /= total_w;
	w_sand /= total_w;
	w_snow /= total_w;
	w_volcano /= total_w;
	
	// 2. Sample PBR Maps with Micro/Macro Dual Blend
	vec3 diff_grass = mix(texture(tex_grass_diff, uv_macro).rgb, texture(tex_grass_diff, uv_micro).rgb, 0.35);
	vec3 diff_sand = mix(texture(tex_sand_diff, uv_macro).rgb, texture(tex_sand_diff, uv_micro).rgb, 0.35);
	vec3 diff_snow = mix(texture(tex_snow_diff, uv_macro).rgb, texture(tex_snow_diff, uv_micro).rgb, 0.35);
	vec3 diff_volcano = mix(texture(tex_volcano_diff, uv_macro).rgb, texture(tex_volcano_diff, uv_micro).rgb, 0.35) * vec3(0.32, 0.30, 0.28);
	
	vec3 nor_grass = texture(tex_grass_nor, uv_macro).rgb * 2.0 - 1.0;
	vec3 nor_sand = texture(tex_sand_nor, uv_macro).rgb * 2.0 - 1.0;
	vec3 nor_snow = texture(tex_snow_nor, uv_macro).rgb * 2.0 - 1.0;
	vec3 nor_volcano = texture(tex_volcano_nor, uv_macro).rgb * 2.0 - 1.0;
	
	float r_grass = mix(texture(tex_grass_rough, uv_macro).r, texture(tex_grass_rough, uv_micro).r, 0.35);
	float r_sand = mix(texture(tex_sand_rough, uv_macro).r, texture(tex_sand_rough, uv_micro).r, 0.35);
	float r_snow = mix(texture(tex_snow_rough, uv_macro).r, texture(tex_snow_rough, uv_micro).r, 0.35);
	float r_volcano = mix(texture(tex_volcano_rough, uv_macro).r, texture(tex_volcano_rough, uv_micro).r, 0.35);
	
	// Biome Blending
	vec3 base_diff = diff_grass * w_grass + diff_sand * w_sand + diff_snow * w_snow + diff_volcano * w_volcano;
	vec3 base_nor = nor_grass * w_grass + nor_sand * w_sand + nor_snow * w_snow + nor_volcano * w_volcano;
	float base_rough = r_grass * w_grass + r_sand * w_sand + r_snow * w_snow + r_volcano * w_volcano;
	
	// 3. Slope-Based Triplanar Cliff Projection
	float slope = 1.0 - clamp(world_norm.y, 0.0, 1.0);
	float cliff_weight = smoothstep(0.32, 0.55, slope);
	
	// Triplanar UV for cliffs (projected along vertical walls)
	vec2 uv_cliff_side = vec2(world_pos.x + world_pos.z, world_pos.y) * uv_scale;
	vec3 diff_cliff = texture(tex_cliff_diff, uv_cliff_side).rgb;
	vec3 nor_cliff = texture(tex_cliff_nor, uv_cliff_side).rgb * 2.0 - 1.0;
	float r_cliff = texture(tex_cliff_rough, uv_cliff_side).r;
	
	vec3 final_albedo = mix(base_diff, diff_cliff, cliff_weight);
	vec3 final_nor = mix(base_nor, nor_cliff, cliff_weight);
	float final_roughness = mix(base_rough, r_cliff, cliff_weight);
	
	// 4. Volcanic Glowing Lava Vein Check
	bool is_magma = (COLOR.r > 1.1 && COLOR.b < 0.2);
	if (is_magma) {
		float pulse = 0.85 + 0.15 * sin(TIME * 2.5 + world_pos.x * 0.05 + world_pos.z * 0.05);
		ALBEDO = COLOR.rgb * pulse;
		EMISSION = COLOR.rgb * pulse * 2.5;
		ROUGHNESS = 0.3;
		METALLIC = 0.1;
		SPECULAR = 0.5;
	} else {
		ALBEDO = final_albedo;
		ROUGHNESS = clamp(final_roughness, 0.45, 0.98);
		SPECULAR = 0.2;
		METALLIC = 0.02;
		NORMAL = (VIEW_MATRIX * vec4(normalize(world_norm + final_nor * 0.5), 0.0)).xyz;
	}
}
