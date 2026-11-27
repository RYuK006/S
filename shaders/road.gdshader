shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform sampler2D texture_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D texture_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D texture_roughness : hint_default_white, filter_linear_mipmap, repeat_enable;

uniform sampler2D texture_gravel_diff : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D texture_gravel_nor : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D texture_gravel_rough : hint_default_white, filter_linear_mipmap, repeat_enable;

uniform vec4 color_asphalt : source_color = vec4(0.16, 0.165, 0.18, 1.0);
uniform vec4 color_centerline : source_color = vec4(0.92, 0.72, 0.08, 1.0);
uniform vec4 color_whiteline : source_color = vec4(0.88, 0.89, 0.90, 1.0);
uniform vec4 color_tiretrack : source_color = vec4(0.10, 0.105, 0.115, 1.0);
uniform int road_surface_mode = 0; // 0 = Highway Asphalt, 1 = Town Street, 2 = Gravel/Dirt Rally

void fragment() {
	vec3 world_pos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 uv_macro = vec2(UV.x * 1.6, UV.y * 1.1);
	vec2 uv_micro = vec2(UV.x * 11.0, UV.y * 8.5);
	vec2 uv_gravel = world_pos.xz * 0.24;

	float w_east = smoothstep(-280.0, 280.0, world_pos.x);
	float w_south = smoothstep(-280.0, 280.0, world_pos.z);
	float w_hub = 1.0 - smoothstep(190.0, 520.0, length(world_pos.xz));
	float sand_tint = (1.0 - w_east) * w_south * (1.0 - w_hub);
	float volc_tint = w_east * (1.0 - w_south) * (1.0 - w_hub);
	float snow_tint = (1.0 - w_east) * (1.0 - w_south) * (1.0 - w_hub) * smoothstep(55.0, 95.0, world_pos.y);

	vec3 asphalt_rgb = mix(texture(texture_albedo, uv_macro).rgb, texture(texture_albedo, uv_micro).rgb, 0.42);
	vec3 combined_normal_tex = mix(texture(texture_normal, uv_macro).rgb, texture(texture_normal, uv_micro).rgb, 0.50);
	float rough_tex = mix(texture(texture_roughness, uv_macro).r, texture(texture_roughness, uv_micro).r, 0.45);

	float road_u = clamp((UV.x - 0.09) / 0.82, 0.0, 1.0);
	float patch_var = 0.92 + 0.12 * sin(world_pos.x * 0.031 + cos(world_pos.z * 0.027) * 1.8);
	float edge_dust = (1.0 - smoothstep(0.0, 0.16, road_u)) + smoothstep(0.84, 1.0, road_u);
	vec3 dust_col = mix(vec3(0.36, 0.34, 0.30), vec3(0.76, 0.58, 0.42), sand_tint);
	dust_col = mix(dust_col, vec3(0.24, 0.24, 0.26), volc_tint);
	dust_col = mix(dust_col, vec3(0.70, 0.74, 0.80), snow_tint * 0.7);

	vec3 base_color = color_asphalt.rgb * asphalt_rgb * 1.32 * patch_var;
	base_color = mix(base_color, dust_col * 0.65, clamp(edge_dust * 0.42, 0.0, 0.45));
	float roughness_val = mix(0.50, 0.84, rough_tex);

	float dist_to_tires = min(
		min(abs(road_u - 0.21), abs(road_u - 0.37)),
		min(abs(road_u - 0.63), abs(road_u - 0.79))
	);
	float tire_wear = 1.0 - smoothstep(0.0, 0.068, dist_to_tires);
	base_color = mix(base_color, color_tiretrack.rgb * asphalt_rgb * 1.12, tire_wear * 0.48);
	roughness_val = mix(roughness_val, 0.32, tire_wear * 0.60);

	if (road_surface_mode < 2) {
		float paint_wear = clamp(0.68 + asphalt_rgb.r * 0.52, 0.45, 1.0);
		float left_edge_line = 1.0 - smoothstep(0.004, 0.009, abs(road_u - 0.048));
		float right_edge_line = 1.0 - smoothstep(0.004, 0.009, abs(road_u - 0.952));
		float shoulder_lines = max(left_edge_line, right_edge_line);

		float center_1 = 1.0 - smoothstep(0.0025, 0.006, abs(road_u - 0.487));
		float center_2 = 1.0 - smoothstep(0.0025, 0.006, abs(road_u - 0.513));
		float double_yellow = max(center_1, center_2);

		float dash_pattern = step(0.50, fract(UV.y * 0.8));
		float lane_l = (1.0 - smoothstep(0.0025, 0.006, abs(road_u - 0.275))) * dash_pattern;
		float lane_r = (1.0 - smoothstep(0.0025, 0.006, abs(road_u - 0.725))) * dash_pattern;
		float all_white = max(shoulder_lines, max(lane_l, lane_r));
		if (road_surface_mode == 1) {
			double_yellow = (1.0 - smoothstep(0.003, 0.008, abs(road_u - 0.50))) * step(0.45, fract(UV.y * 0.65));
			all_white = shoulder_lines;
		}
		base_color = mix(base_color, color_whiteline.rgb * paint_wear, all_white * 0.84);
		roughness_val = mix(roughness_val, 0.44, all_white * 0.75);
		base_color = mix(base_color, color_centerline.rgb * paint_wear, double_yellow * 0.86);
		roughness_val = mix(roughness_val, 0.42, double_yellow * 0.75);
	}

	float left_gravel = 1.0 - smoothstep(0.068, 0.115, UV.x);
	float right_gravel = smoothstep(0.885, 0.932, UV.x);
	float gravel_w = clamp(max(left_gravel, right_gravel), 0.0, 1.0);
	if (road_surface_mode == 2) {
		gravel_w = 1.0;
	}
	if (gravel_w > 0.005) {
		vec3 g_diff = texture(texture_gravel_diff, uv_gravel).rgb * vec3(0.76, 0.72, 0.66);
		g_diff = mix(g_diff, g_diff * vec3(0.95, 0.75, 0.56), sand_tint);
		g_diff = mix(g_diff, g_diff * vec3(0.24, 0.23, 0.26), volc_tint);
		g_diff = mix(g_diff, g_diff * vec3(0.62, 0.66, 0.72), snow_tint);
		if (road_surface_mode == 2) {
			g_diff = mix(g_diff, g_diff * 0.72, tire_wear * 0.55);
		}
		vec3 g_nor = texture(texture_gravel_nor, uv_gravel).rgb;
		float g_rough = texture(texture_gravel_rough, uv_gravel).r;
		base_color = mix(base_color, g_diff, gravel_w);
		combined_normal_tex = mix(combined_normal_tex, g_nor, gravel_w);
		roughness_val = mix(roughness_val, g_rough, gravel_w);
	}

	ALBEDO = base_color;
	NORMAL_MAP = clamp(combined_normal_tex, vec3(0.0), vec3(1.0));
	NORMAL_MAP_DEPTH = 0.95;
	ROUGHNESS = clamp(roughness_val, 0.28, 0.95);
	METALLIC = 0.02;
	SPECULAR = 0.48;
}
