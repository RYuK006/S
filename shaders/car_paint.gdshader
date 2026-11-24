shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// Forza-tier Automotive Paint Shader: Clearcoat, Metallic Flake, and Pearl Shift
uniform vec4 base_color : source_color = vec4(0.85, 0.12, 0.08, 1.0);
uniform vec4 pearl_color : source_color = vec4(0.95, 0.65, 0.10, 1.0);
uniform float metallic : hint_range(0.0, 1.0) = 0.88;
uniform float roughness : hint_range(0.0, 1.0) = 0.12;
uniform float clearcoat : hint_range(0.0, 1.0) = 1.0;
uniform float clearcoat_roughness : hint_range(0.0, 1.0) = 0.04;
uniform float pearl_shift_power : hint_range(0.5, 6.0) = 2.5;
uniform float flake_intensity : hint_range(0.0, 1.0) = 0.35;
uniform float flake_scale : hint_range(10.0, 500.0) = 160.0;

// High-frequency pseudo-random noise for metallic flakes
float flake_noise(vec2 uv) {
	vec2 p = uv * flake_scale;
	vec2 i = floor(p);
	float n = sin(dot(i, vec2(12.9898, 78.233))) * 43758.5453;
	float flake = step(0.85, fract(n));
	return flake;
}

void fragment() {
	vec3 view_dir = normalize(VIEW);
	float fresnel = pow(1.0 - max(0.0, dot(NORMAL, view_dir)), pearl_shift_power);
	
	// Blend base metallic with pearl shift at glancing angles
	vec3 paint_rgb = mix(base_color.rgb, pearl_color.rgb, fresnel * 0.7);
	
	// Metal flake sparkle
	float flake = flake_noise(UV * 4.0);
	vec3 flake_color = vec3(flake * flake_intensity);
	paint_rgb += flake_color;
	
	ALBEDO = paint_rgb;
	METALLIC = metallic;
	ROUGHNESS = roughness;
	CLEARCOAT = clearcoat;
	CLEARCOAT_ROUGHNESS = clearcoat_roughness;
	SPECULAR = 0.6;
}
