shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

// Textures
uniform sampler2D texture_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D texture_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D texture_roughness : hint_default_white, filter_linear_mipmap, repeat_enable;

// Road Marking Colors
uniform vec4 color_asphalt : source_color = vec4(0.18, 0.18, 0.20, 1.0);
uniform vec4 color_centerline : source_color = vec4(0.98, 0.78, 0.08, 1.0);
uniform vec4 color_whiteline : source_color = vec4(0.95, 0.95, 0.96, 1.0);
uniform vec4 color_tiretrack : source_color = vec4(0.11, 0.11, 0.12, 1.0);

// Parameters
uniform float road_uv_scale_y = 0.15;
uniform float asphalt_macro_scale = 1.0;
uniform float asphalt_micro_scale = 8.0;

void fragment() {
	// UV.x runs 0..1 across ~14m road width; UV.y runs at u_distance * 0.1 (10m per UV unit)
	// Match aspect ratio 1.4x on X so asphalt grain & aggregate are isotropic 1:1 (no smeared streaks)
	vec2 uv_macro = vec2(UV.x * asphalt_macro_scale * 1.4, UV.y * 1.0);
	vec2 uv_micro = vec2(UV.x * asphalt_micro_scale * 1.4, UV.y * 8.0);

	// Sample asphalt textures cleanly in tangent space (0..1 -> NORMAL_MAP)
	vec4 albedo_tex = texture(texture_albedo, uv_macro);
	vec4 albedo_micro = texture(texture_albedo, uv_micro);
	vec3 asphalt_rgb = mix(albedo_tex.rgb, albedo_micro.rgb, 0.35);
	vec3 norm_tex1 = texture(texture_normal, uv_macro).rgb;
	vec3 norm_tex2 = texture(texture_normal, uv_micro).rgb;
	vec3 combined_normal_tex = mix(norm_tex1, norm_tex2, 0.45);
	float rough_tex = mix(texture(texture_roughness, uv_macro).r, texture(texture_roughness, uv_micro).r, 0.4);

	// Base asphalt color + crisp organic edge vignette on outermost curbs
	vec3 base_color = color_asphalt.rgb * asphalt_rgb * 1.35;
	float shoulder_dirt = smoothstep(0.035, 0.0, UV.x) + smoothstep(0.965, 1.0, UV.x);
	base_color = mix(base_color, base_color * vec3(0.85, 0.80, 0.74), clamp(shoulder_dirt, 0.0, 0.7));
	float roughness_val = mix(0.42, 0.78, rough_tex);
	float metallic_val = 0.02;

	// 1. Tire track grooves (darker glossy rubber polish in wheel paths)
	float dist_to_tires = min(
		min(abs(UV.x - 0.22), abs(UV.x - 0.38)),
		min(abs(UV.x - 0.62), abs(UV.x - 0.78))
	);
	float tire_wear = 1.0 - smoothstep(0.0, 0.065, dist_to_tires);
	base_color = mix(base_color, color_tiretrack.rgb * asphalt_rgb * 1.1, tire_wear * 0.42);
	roughness_val = mix(roughness_val, 0.28, tire_wear * 0.55);

	// 2. White outer shoulder lines
	float left_shoulder = 1.0 - smoothstep(0.003, 0.007, abs(UV.x - 0.055));
	float right_shoulder = 1.0 - smoothstep(0.003, 0.007, abs(UV.x - 0.945));
	float shoulder_lines = max(left_shoulder, right_shoulder);

	// 3. Double Yellow Centerline
	float center_line_1 = 1.0 - smoothstep(0.002, 0.005, abs(UV.x - 0.488));
	float center_line_2 = 1.0 - smoothstep(0.002, 0.005, abs(UV.x - 0.512));
	float double_yellow = max(center_line_1, center_line_2);

	// 4. Dashed White Lane Divider Lines (every ~12.5m cleanly along UV.y)
	float dash_pattern = step(0.48, fract(UV.y * 0.8));
	float lane_div_left = (1.0 - smoothstep(0.002, 0.005, abs(UV.x - 0.28))) * dash_pattern;
	float lane_div_right = (1.0 - smoothstep(0.002, 0.005, abs(UV.x - 0.72))) * dash_pattern;
	float dashed_lines = max(lane_div_left, lane_div_right);

	float all_white = max(shoulder_lines, dashed_lines);
	base_color = mix(base_color, color_whiteline.rgb * (asphalt_rgb * 0.25 + 0.78), all_white);
	roughness_val = mix(roughness_val, 0.34, all_white);

	base_color = mix(base_color, color_centerline.rgb * (asphalt_rgb * 0.25 + 0.78), double_yellow);
	roughness_val = mix(roughness_val, 0.32, double_yellow);

	ALBEDO = base_color;
	NORMAL_MAP = combined_normal_tex;
	NORMAL_MAP_DEPTH = 0.85;
	ROUGHNESS = roughness_val;
	METALLIC = metallic_val;
	SPECULAR = 0.58;
}
