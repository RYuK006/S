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
	// UV.x runs across the road (0.0 = Left edge, 0.5 = Center, 1.0 = Right edge)
	// UV.y runs along the road distance
	vec2 uv_macro = vec2(UV.x * asphalt_macro_scale, UV.y * road_uv_scale_y);
	vec2 uv_micro = vec2(UV.x * asphalt_micro_scale, UV.y * road_uv_scale_y * asphalt_micro_scale);
	
	// Sample asphalt textures
	vec4 albedo_tex = texture(texture_albedo, uv_macro);
	vec3 norm_tex1 = texture(texture_normal, uv_macro).rgb * 2.0 - 1.0;
	vec3 norm_tex2 = texture(texture_normal, uv_micro).rgb * 2.0 - 1.0;
	vec3 combined_normal = normalize(norm_tex1 + norm_tex2 * 0.4);
	float rough_tex = texture(texture_roughness, uv_macro).r;
	
	// Base asphalt color
	vec3 base_color = color_asphalt.rgb * albedo_tex.rgb;
	float roughness_val = mix(0.65, 0.45, rough_tex);
	float metallic_val = 0.02;
	
	// 1. Tire track grooves (darker, slightly smoothed rubber polish)
	// Left lane tire tracks: ~0.20 and ~0.35; Right lane: ~0.65 and ~0.80
	float dist_to_tires = min(
		min(abs(UV.x - 0.22), abs(UV.x - 0.38)),
		min(abs(UV.x - 0.62), abs(UV.x - 0.78))
	);
	float tire_wear = 1.0 - smoothstep(0.0, 0.07, dist_to_tires);
	base_color = mix(base_color, color_tiretrack.rgb * albedo_tex.rgb * 0.9, tire_wear * 0.35);
	roughness_val = mix(roughness_val, 0.40, tire_wear * 0.4);
	
	// 2. White outer shoulder lines (UV.x near 0.04 and 0.96, width 0.015)
	float left_shoulder = 1.0 - smoothstep(0.003, 0.007, abs(UV.x - 0.045));
	float right_shoulder = 1.0 - smoothstep(0.003, 0.007, abs(UV.x - 0.955));
	float shoulder_lines = max(left_shoulder, right_shoulder);
	
	// 3. Double Yellow Centerline (UV.x at 0.488 and 0.512, width 0.008)
	float center_line_1 = 1.0 - smoothstep(0.002, 0.005, abs(UV.x - 0.488));
	float center_line_2 = 1.0 - smoothstep(0.002, 0.005, abs(UV.x - 0.512));
	float double_yellow = max(center_line_1, center_line_2);
	
	// 4. Dashed White Lane Divider Lines (for 4-lane corridors, dashed at UV.y)
	float dash_pattern = step(0.45, fract(UV.y * 0.8));
	float lane_div_left = (1.0 - smoothstep(0.002, 0.005, abs(UV.x - 0.28))) * dash_pattern;
	float lane_div_right = (1.0 - smoothstep(0.002, 0.005, abs(UV.x - 0.72))) * dash_pattern;
	float dashed_lines = max(lane_div_left, lane_div_right);
	
	// Blend Painted Markings with high PBR fidelity
	// White markings
	float all_white = max(shoulder_lines, dashed_lines);
	base_color = mix(base_color, color_whiteline.rgb * (albedo_tex.rgb * 0.3 + 0.75), all_white);
	roughness_val = mix(roughness_val, 0.32, all_white);
	
	// Yellow markings
	base_color = mix(base_color, color_centerline.rgb * (albedo_tex.rgb * 0.3 + 0.75), double_yellow);
	roughness_val = mix(roughness_val, 0.30, double_yellow);
	
	ALBEDO = base_color;
	NORMAL = (VIEW_MATRIX * vec4(combined_normal, 0.0)).xyz;
	ROUGHNESS = roughness_val;
	METALLIC = metallic_val;
	SPECULAR = 0.55;
}
