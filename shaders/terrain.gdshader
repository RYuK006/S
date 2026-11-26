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

	// Natural alpine snowline: lush green pine meadows below 48m, snowy mountain peaks above 74m
	float snowline = smoothstep(48.0, 74.0, world_pos.y);
	float low_snow = w_snow * (1.0 - snowline);
	w_snow *= snowline;
	w_grass += low_snow;
	
	// 2. Sample PBR Maps with Continuous Harmonic Anti-Tiling (zero square grid seams)
	float blend_t = 0.5 + 0.5 * sin(world_pos.x * 0.013 + cos(world_pos.z * 0.011) * 1.4) * cos(world_pos.z * 0.014);
	vec2 uv_rot = vec2(uv_macro.x * 0.707 - uv_macro.y * 0.707, uv_macro.x * 0.707 + uv_macro.y * 0.707) + vec2(0.37, 0.71);
	vec3 diff_grass = mix(texture(tex_grass_diff, uv_macro).rgb, mix(texture(tex_grass_diff, uv_micro).rgb, texture(tex_grass_diff, uv_rot).rgb, blend_t * 0.55), 0.45) * vec3(0.56, 0.76, 0.42);
	vec3 diff_sand = mix(texture(tex_sand_diff, uv_macro).rgb, mix(texture(tex_sand_diff, uv_micro).rgb, texture(tex_sand_diff, uv_rot).rgb, blend_t * 0.55), 0.42) * vec3(1.16, 0.84, 0.56);
	vec3 diff_snow = mix(texture(tex_snow_diff, uv_macro).rgb, texture(tex_snow_diff, uv_micro).rgb, 0.35);
	vec3 diff_volcano = mix(texture(tex_volcano_diff, uv_macro).rgb, texture(tex_volcano_diff, uv_rot).rgb, 0.42 * blend_t) * vec3(0.24, 0.22, 0.24);

	vec3 nor_grass = mix(texture(tex_grass_nor, uv_macro).rgb, texture(tex_grass_nor, uv_micro).rgb, 0.35);
	vec3 nor_sand = mix(texture(tex_sand_nor, uv_macro).rgb, texture(tex_sand_nor, uv_micro).rgb, 0.35);
	vec3 nor_snow = mix(texture(tex_snow_nor, uv_macro).rgb, texture(tex_snow_nor, uv_micro).rgb, 0.30);
	vec3 nor_volcano = mix(texture(tex_volcano_nor, uv_macro).rgb, texture(tex_volcano_nor, uv_micro).rgb, 0.40);

	float r_grass = mix(texture(tex_grass_rough, uv_macro).r, texture(tex_grass_rough, uv_micro).r, 0.35);
	float r_sand = mix(texture(tex_sand_rough, uv_macro).r, texture(tex_sand_rough, uv_micro).r, 0.35);
	float r_snow = mix(texture(tex_snow_rough, uv_macro).r, texture(tex_snow_rough, uv_micro).r, 0.35);
	float r_volcano = mix(texture(tex_volcano_rough, uv_macro).r, texture(tex_volcano_rough, uv_micro).r, 0.35);

	// Biome Blending
	vec3 base_diff = diff_grass * w_grass + diff_sand * w_sand + diff_snow * w_snow + diff_volcano * w_volcano;
	vec3 base_nor_tex = nor_grass * w_grass + nor_sand * w_sand + nor_snow * w_snow + nor_volcano * w_volcano;
	float base_rough = r_grass * w_grass + r_sand * w_sand + r_snow * w_snow + r_volcano * w_volcano;

	// 3. True 3-Axis World Triplanar Cliff Projection (crisp vertical mesas & volcano crags)
	float slope = 1.0 - clamp(world_norm.y, 0.0, 1.0);
	float cliff_weight = smoothstep(0.28, 0.52, slope);

	vec3 tri_w = pow(abs(world_norm), vec3(4.0));
	tri_w /= max(0.0001, tri_w.x + tri_w.y + tri_w.z);
	float c_scale = uv_scale * 0.65;
	vec2 uv_cx = world_pos.zy * c_scale;
	vec2 uv_cy = world_pos.xz * c_scale;
	vec2 uv_cz = world_pos.xy * c_scale;
	vec3 diff_cliff = texture(tex_cliff_diff, uv_cx).rgb * tri_w.x + texture(tex_cliff_diff, uv_cy).rgb * tri_w.y + texture(tex_cliff_diff, uv_cz).rgb * tri_w.z;
	diff_cliff = mix(diff_cliff, diff_cliff * vec3(0.30, 0.28, 0.30), clamp(w_volcano * 1.4, 0.0, 1.0));
	diff_cliff = mix(diff_cliff, diff_cliff * vec3(1.12, 0.86, 0.66), clamp(w_sand, 0.0, 1.0));
	vec3 nor_cliff_tex = texture(tex_cliff_nor, uv_cx).rgb * tri_w.x + texture(tex_cliff_nor, uv_cy).rgb * tri_w.y + texture(tex_cliff_nor, uv_cz).rgb * tri_w.z;
	float r_cliff = texture(tex_cliff_rough, uv_cx).r * tri_w.x + texture(tex_cliff_rough, uv_cy).r * tri_w.y + texture(tex_cliff_rough, uv_cz).r * tri_w.z;

	vec3 final_albedo = mix(base_diff, diff_cliff, cliff_weight);
	vec3 final_nor_tex = mix(base_nor_tex, nor_cliff_tex, cliff_weight);
	float final_roughness = mix(base_rough, r_cliff, cliff_weight);

	// Macro tint variation to break large landscape tiling
	float macro_var = sin(world_pos.x * 0.015) * cos(world_pos.z * 0.015) * 0.06;
	final_albedo = clamp(final_albedo * (1.02 + macro_var), vec3(0.0), vec3(1.0));

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
		ROUGHNESS = clamp(final_roughness, 0.52, 0.96);
		SPECULAR = 0.22;
		METALLIC = 0.02;
		NORMAL_MAP = clamp(final_nor_tex, vec3(0.0), vec3(1.0));
		NORMAL_MAP_DEPTH = 1.15;
	}
}
