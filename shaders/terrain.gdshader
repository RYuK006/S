shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D tex_grass_diff : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D tex_grass_nor : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D tex_grass_rough : hint_default_white, filter_linear_mipmap, repeat_enable;

uniform sampler2D tex_sand_diff : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D tex_sand_nor : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D tex_sand_rough : hint_default_white, filter_linear_mipmap, repeat_enable;

uniform sampler2D tex_snow_diff : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D tex_snow_nor : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D tex_snow_rough : hint_default_white, filter_linear_mipmap, repeat_enable;

uniform sampler2D tex_volcano_diff : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D tex_volcano_nor : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D tex_volcano_rough : hint_default_white, filter_linear_mipmap, repeat_enable;

uniform sampler2D tex_cliff_diff : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D tex_cliff_nor : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D tex_cliff_rough : hint_default_white, filter_linear_mipmap, repeat_enable;

uniform sampler2D tex_gravel_diff : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D tex_gravel_nor : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D tex_gravel_rough : hint_default_white, filter_linear_mipmap, repeat_enable;

uniform float uv_scale : hint_range(0.01, 0.5) = 0.065;
uniform float micro_uv_scale : hint_range(0.1, 2.0) = 0.55;

vec3 sample_antitile(sampler2D t, vec2 uv_m, vec2 uv_s, vec2 uv_r, float b) {
	return mix(texture(t, uv_m).rgb, mix(texture(t, uv_s).rgb, texture(t, uv_r).rgb, b * 0.55), 0.44);
}

void fragment() {
	vec3 world_pos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 world_norm = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);

	vec2 uv_macro = world_pos.xz * uv_scale;
	vec2 uv_micro = world_pos.xz * micro_uv_scale;
	vec2 uv_rot = vec2(uv_macro.x * 0.707 - uv_macro.y * 0.707, uv_macro.x * 0.707 + uv_macro.y * 0.707) + vec2(0.37, 0.71);
	float blend_t = 0.5 + 0.5 * sin(world_pos.x * 0.013 + cos(world_pos.z * 0.011) * 1.4) * cos(world_pos.z * 0.014);

	float dist_center = length(world_pos.xz);
	float w_hub = 1.0 - smoothstep(190.0, 520.0, dist_center);

	float w_east = smoothstep(-280.0, 280.0, world_pos.x);
	float w_south = smoothstep(-280.0, 280.0, world_pos.z);

	float w_snow = (1.0 - w_east) * (1.0 - w_south) * (1.0 - w_hub);
	float w_volcano = w_east * (1.0 - w_south) * (1.0 - w_hub);
	float w_sand = (1.0 - w_east) * w_south * (1.0 - w_hub);
	float w_coast = w_east * w_south * (1.0 - w_hub);

	// Lush FH5 Central Festival meadows & tropical coastal grass
	float w_grass = w_hub + w_coast * smoothstep(2.4, 7.5, world_pos.y);
	// Golden wet sandy cove beaches in Neon Coast below y=5m
	float w_coast_sand = w_coast * (1.0 - smoothstep(1.8, 5.6, world_pos.y));
	w_sand += w_coast_sand;

	// Natural Alpine snowline: lush green pine valleys below 74m, deep snow peaks above 112m
	float slope = 1.0 - clamp(world_norm.y, 0.0, 1.0);
	float snowline = smoothstep(74.0, 112.0, world_pos.y) * (1.0 - smoothstep(0.20, 0.44, slope));
	float low_snow = w_snow * (1.0 - snowline);
	w_snow *= snowline;
	w_grass += low_snow * 0.55;
	w_volcano += low_snow * 0.45; // Expose dark granite gravel under steep lower alpine faces

	vec3 diff_grass = vec3(0.0);
	vec3 nor_grass = vec3(0.5, 0.5, 1.0);
	float r_grass = 0.85;
	if (w_grass > 0.004) {
		diff_grass = sample_antitile(tex_grass_diff, uv_macro, uv_micro, uv_rot, blend_t) * vec3(0.62, 0.80, 0.44);
		nor_grass = mix(texture(tex_grass_nor, uv_macro).rgb, texture(tex_grass_nor, uv_micro).rgb, 0.45);
		r_grass = mix(texture(tex_grass_rough, uv_macro).r, texture(tex_grass_rough, uv_micro).r, 0.4);
	}

	vec3 diff_sand = vec3(0.0);
	vec3 nor_sand = vec3(0.5, 0.5, 1.0);
	float r_sand = 0.85;
	if (w_sand > 0.004) {
		diff_sand = sample_antitile(tex_sand_diff, uv_macro, uv_micro, uv_rot, blend_t) * vec3(1.12, 0.82, 0.56);
		nor_sand = mix(texture(tex_sand_nor, uv_macro).rgb, texture(tex_sand_nor, uv_micro).rgb, 0.45);
		r_sand = mix(texture(tex_sand_rough, uv_macro).r, texture(tex_sand_rough, uv_micro).r, 0.4);
	}

	vec3 diff_snow = vec3(0.0);
	vec3 nor_snow = vec3(0.5, 0.5, 1.0);
	float r_snow = 0.72;
	if (w_snow > 0.004) {
		diff_snow = mix(texture(tex_snow_diff, uv_macro).rgb, texture(tex_snow_diff, uv_micro).rgb, 0.35) * vec3(0.95, 0.97, 1.02);
		nor_snow = mix(texture(tex_snow_nor, uv_macro).rgb, texture(tex_snow_nor, uv_micro).rgb, 0.35);
		r_snow = mix(texture(tex_snow_rough, uv_macro).r, texture(tex_snow_rough, uv_micro).r, 0.4);
	}

	vec3 diff_volcano = vec3(0.0);
	vec3 nor_volcano = vec3(0.5, 0.5, 1.0);
	float r_volcano = 0.88;
	if (w_volcano > 0.004) {
		vec3 vol_raw = sample_antitile(tex_volcano_diff, uv_macro, uv_micro, uv_rot, blend_t);
		float vol_lum = dot(vol_raw, vec3(0.299, 0.587, 0.114));
		diff_volcano = mix(vec3(vol_lum), vol_raw, 0.20) * vec3(0.16, 0.165, 0.19);
		nor_volcano = mix(texture(tex_volcano_nor, uv_macro).rgb, texture(tex_volcano_nor, uv_micro).rgb, 0.45);
		r_volcano = mix(texture(tex_volcano_rough, uv_macro).r, texture(tex_volcano_rough, uv_micro).r, 0.4);
	}

	float w_sum = max(0.001, w_grass + w_sand + w_snow + w_volcano);
	vec3 base_diff = (diff_grass * w_grass + diff_sand * w_sand + diff_snow * w_snow + diff_volcano * w_volcano) / w_sum;
	vec3 base_nor = (nor_grass * w_grass + nor_sand * w_sand + nor_snow * w_snow + nor_volcano * w_volcano) / w_sum;
	float base_rough = (r_grass * w_grass + r_sand * w_sand + r_snow * w_snow + r_volcano * w_volcano) / w_sum;

	// Hydrological gully sediment + graded crushed gravel shoulders flanking roads (UV2.x = flow, UV2.y = road verge)
	float gully_w = smoothstep(0.32, 0.72, UV2.x) * (1.0 - w_snow * 0.7);
	float road_verge_w = smoothstep(0.05, 0.68, UV2.y);
	float gravel_blend = clamp(max(gully_w * 0.75, road_verge_w * 0.90), 0.0, 0.92);
	if (gravel_blend > 0.004) {
		vec3 diff_gravel = sample_antitile(tex_gravel_diff, uv_macro * 1.4, uv_micro * 1.6, uv_rot, blend_t) * vec3(0.80, 0.77, 0.72);
		vec3 nor_gravel = mix(texture(tex_gravel_nor, uv_macro * 1.4).rgb, texture(tex_gravel_nor, uv_micro * 1.6).rgb, 0.5);
		float r_gravel = mix(texture(tex_gravel_rough, uv_macro * 1.4).r, texture(tex_gravel_rough, uv_micro * 1.6).r, 0.45);
		vec3 gravel_tinted = mix(diff_gravel, diff_gravel * vec3(1.12, 0.88, 0.68), w_sand);
		gravel_tinted = mix(gravel_tinted, gravel_tinted * vec3(0.26, 0.25, 0.28), w_volcano);
		gravel_tinted = mix(gravel_tinted, gravel_tinted * vec3(0.55, 0.60, 0.66), clamp(w_snow * 1.4, 0.0, 1.0));
		base_diff = mix(base_diff, gravel_tinted, gravel_blend);
		base_nor = mix(base_nor, nor_gravel, gravel_blend);
		base_rough = mix(base_rough, r_gravel, gravel_blend);
	}

	// Wet beach darkening near sea level
	float wet_shore = 1.0 - smoothstep(0.8, 2.8, world_pos.y);
	base_diff = mix(base_diff, base_diff * 0.56, wet_shore * w_coast);
	base_rough = mix(base_rough, 0.22, wet_shore * w_coast);

	// True 3-Axis Triplanar Cliff Walls with Mexican Sandstone Strata
	float cliff_weight = smoothstep(0.24, 0.48, slope);
	vec3 final_albedo = base_diff;
	vec3 final_nor_tex = base_nor;
	float final_roughness = base_rough;
	if (cliff_weight > 0.004) {
		vec3 tri_w = pow(abs(world_norm), vec3(4.0));
		tri_w /= max(0.0001, tri_w.x + tri_w.y + tri_w.z);
		float c_scale = uv_scale * 0.72;
		vec2 uv_cx = world_pos.zy * c_scale;
		vec2 uv_cy = world_pos.xz * c_scale;
		vec2 uv_cz = world_pos.xy * c_scale;
		vec3 cliff_raw = texture(tex_cliff_diff, uv_cx).rgb * tri_w.x + texture(tex_cliff_diff, uv_cy).rgb * tri_w.y + texture(tex_cliff_diff, uv_cz).rgb * tri_w.z;
		float cliff_lum = dot(cliff_raw, vec3(0.299, 0.587, 0.114));
		vec3 cliff_basalt = mix(vec3(cliff_lum), cliff_raw, 0.18) * vec3(0.20, 0.205, 0.23);
		float strata = 0.88 + 0.14 * sin(world_pos.y * 0.62 + sin(world_pos.x * 0.025 + world_pos.z * 0.025) * 1.8);
		vec3 diff_cliff = mix(cliff_raw, cliff_basalt, clamp(w_volcano * 1.5, 0.0, 1.0));
		diff_cliff = mix(diff_cliff, cliff_raw * vec3(1.22, 0.76, 0.48) * strata, clamp(w_sand, 0.0, 1.0));
		diff_cliff = mix(diff_cliff, vec3(cliff_lum) * vec3(0.68, 0.72, 0.78), clamp(w_snow * 0.85, 0.0, 1.0));
		vec3 nor_cliff = texture(tex_cliff_nor, uv_cx).rgb * tri_w.x + texture(tex_cliff_nor, uv_cy).rgb * tri_w.y + texture(tex_cliff_nor, uv_cz).rgb * tri_w.z;
		float r_cliff = texture(tex_cliff_rough, uv_cx).r * tri_w.x + texture(tex_cliff_rough, uv_cy).r * tri_w.y + texture(tex_cliff_rough, uv_cz).r * tri_w.z;
		final_albedo = mix(base_diff, diff_cliff, cliff_weight);
		final_nor_tex = mix(base_nor, nor_cliff, cliff_weight);
		final_roughness = mix(base_rough, r_cliff, cliff_weight);
	}

	// Break distant horizon repetition with subtle geological color modulation
	float macro_var = sin(world_pos.x * 0.011 + 0.7) * cos(world_pos.z * 0.013) * 0.08 - UV2.x * 0.14;
	final_albedo = clamp(final_albedo * (1.02 + macro_var), vec3(0.0), vec3(1.0));

	// Per-pixel organic lava magma fissures & glowing molten lake inside Caldera (zero polygon diamonds!)
	float lava_heat = smoothstep(0.56, 0.94, COLOR.r) * (1.0 - smoothstep(0.18, 0.46, COLOR.b));
	if (lava_heat > 0.02) {
		float n1 = texture(tex_volcano_rough, world_pos.xz * 0.032).r;
		float n2 = texture(tex_cliff_rough, world_pos.xz * 0.095 + vec2(TIME * 0.004, -TIME * 0.003)).r;
		float rock_mask = smoothstep(0.24, 0.62, n1 * 0.62 + n2 * 0.38 - lava_heat * 0.38);
		float flow = clamp((lava_heat * 1.25) * (1.0 - rock_mask), 0.0, 1.0);
		float pulse = 0.85 + 0.22 * sin(TIME * 2.2 + n1 * 12.0);
		vec3 molten = mix(vec3(0.95, 0.14, 0.01), vec3(1.65, 0.58, 0.05), clamp(flow * 1.2, 0.0, 1.0)) * pulse;
		ALBEDO = mix(final_albedo * 0.42, molten, flow);
		EMISSION = molten * flow * 2.6;
		ROUGHNESS = mix(clamp(final_roughness, 0.55, 0.96), 0.28, flow);
		METALLIC = 0.04;
		SPECULAR = 0.36;
		NORMAL_MAP = clamp(final_nor_tex, vec3(0.0), vec3(1.0));
		NORMAL_MAP_DEPTH = 1.3;
	} else {
		ALBEDO = final_albedo;
		ROUGHNESS = clamp(final_roughness, 0.22, 0.95);
		SPECULAR = 0.28;
		METALLIC = 0.02;
		NORMAL_MAP = clamp(final_nor_tex, vec3(0.0), vec3(1.0));
		NORMAL_MAP_DEPTH = 1.25;
	}
}
