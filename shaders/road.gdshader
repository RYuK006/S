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

void fragment() {
	vec3 world_pos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// UV.x runs 0.0..1.0 across embankment shoulder + carriageway:
	//   [0.00..0.09] = Left crushed gravel embankment skirt
	//   [0.09..0.91] = Main asphalt roadway width
	//   [0.91..1.00] = Right crushed gravel embankment skirt
	vec2 uv_macro = vec2(UV.x * 1.6, UV.y * 1.1);
	vec2 uv_micro = vec2(UV.x * 11.0, UV.y * 8.5);
	vec2 uv_gravel = world_pos.xz * 0.24;

	vec3 asphalt_rgb = mix(texture(texture_albedo, uv_macro).rgb, texture(texture_albedo, uv_micro).rgb, 0.42);
	vec3 combined_normal_tex = mix(texture(texture_normal, uv_macro).rgb, texture(texture_normal, uv_micro).rgb, 0.50);
	float rough_tex = mix(texture(texture_roughness, uv_macro).r, texture(texture_roughness, uv_micro).r, 0.45);

	// Remap [0.09..0.91] -> [0.0..1.0] across drivable asphalt lanes
	float road_u = clamp((UV.x - 0.09) / 0.82, 0.0, 1.0);

	// Subtle asphalt aging patchiness & longitudinal tarmac cracks
	float patch_var = 0.90 + 0.14 * sin(world_pos.x * 0.031 + cos(world_pos.z * 0.027) * 1.8);
	float edge_dust = (1.0 - smoothstep(0.0, 0.14, road_u)) + smoothstep(0.86, 1.0, road_u);
	vec3 base_color = color_asphalt.rgb * asphalt_rgb * 1.38 * patch_var;
	base_color = mix(base_color, base_color * vec3(1.08, 0.96, 0.84), clamp(edge_dust * 0.55, 0.0, 0.55));
	float roughness_val = mix(0.46, 0.82, rough_tex);

	// 1. Dark rubberized tire grooves with warm specular sheen
	float dist_to_tires = min(
		min(abs(road_u - 0.21), abs(road_u - 0.37)),
		min(abs(road_u - 0.63), abs(road_u - 0.79))
	);
	float tire_wear = 1.0 - smoothstep(0.0, 0.068, dist_to_tires);
	base_color = mix(base_color, color_tiretrack.rgb * asphalt_rgb * 1.12, tire_wear * 0.48);
	roughness_val = mix(roughness_val, 0.30, tire_wear * 0.62);

	// 2. Weathered highway markings (micro-chipped paint modulated by aggregate mask)
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

	base_color = mix(base_color, color_whiteline.rgb * paint_wear, all_white * 0.88);
	roughness_val = mix(roughness_val, 0.40, all_white * 0.75);

	base_color = mix(base_color, color_centerline.rgb * paint_wear, double_yellow * 0.90);
	roughness_val = mix(roughness_val, 0.38, double_yellow * 0.75);

	// 3. Organic Crushed Gravel Shoulder Blending along outer embankment skirts (UV.x < 0.095 / > 0.905)
	float left_gravel = 1.0 - smoothstep(0.068, 0.112, UV.x);
	float right_gravel = smoothstep(0.888, 0.932, UV.x);
	float gravel_w = clamp(max(left_gravel, right_gravel), 0.0, 1.0);
	if (gravel_w > 0.005) {
		float w_east = smoothstep(-280.0, 280.0, world_pos.x);
		float w_south = smoothstep(-280.0, 280.0, world_pos.z);
		float sand_tint = (1.0 - w_east) * w_south;
		float volc_tint = w_east * (1.0 - w_south);
		float snow_tint = (1.0 - w_east) * (1.0 - w_south) * smoothstep(55.0, 90.0, world_pos.y);
		vec3 g_diff = texture(texture_gravel_diff, uv_gravel).rgb * vec3(0.82, 0.78, 0.73);
		g_diff = mix(g_diff, g_diff * vec3(1.12, 0.88, 0.68), sand_tint);
		g_diff = mix(g_diff, g_diff * vec3(0.26, 0.25, 0.28), volc_tint);
		g_diff = mix(g_diff, g_diff * vec3(0.54, 0.59, 0.65), snow_tint);
		vec3 g_nor = texture(texture_gravel_nor, uv_gravel).rgb;
		float g_rough = texture(texture_gravel_rough, uv_gravel).r;
		base_color = mix(base_color, g_diff, gravel_w);
		combined_normal_tex = mix(combined_normal_tex, g_nor, gravel_w);
		roughness_val = mix(roughness_val, g_rough, gravel_w);
	}

	ALBEDO = base_color;
	NORMAL_MAP = clamp(combined_normal_tex, vec3(0.0), vec3(1.0));
	NORMAL_MAP_DEPTH = 0.95;
	ROUGHNESS = clamp(roughness_val, 0.25, 0.95);
	METALLIC = 0.02;
	SPECULAR = 0.56;
}
