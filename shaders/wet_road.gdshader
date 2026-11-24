shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// High-Fidelity Wet Asphalt Road Shader with Screen Space Reflections & Procedural Puddles
uniform vec4 asphalt_color : source_color = vec4(0.20, 0.20, 0.22, 1.0);
uniform vec4 wet_color : source_color = vec4(0.08, 0.08, 0.09, 1.0);
uniform float wetness : hint_range(0.0, 1.0) = 0.65;
uniform float puddle_threshold : hint_range(0.1, 0.9) = 0.52;
uniform float puddle_scale : hint_range(1.0, 60.0) = 18.0;
uniform float roughness_dry : hint_range(0.0, 1.0) = 0.72;
uniform float roughness_puddle : hint_range(0.0, 1.0) = 0.02;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise2d(vec2 uv) {
	vec2 id = floor(uv);
	vec2 f = fract(uv);
	f = f * f * (3.0 - 2.0 * f);
	
	float bl = hash21(id);
	float br = hash21(id + vec2(1.0, 0.0));
	float tl = hash21(id + vec2(0.0, 1.0));
	float tr = hash21(id + vec2(1.0, 1.0));
	
	return mix(mix(bl, br, f.x), mix(tl, tr, f.x), f.y);
}

void fragment() {
	vec2 world_uv = UV * puddle_scale;
	float n = noise2d(world_uv) * 0.7 + noise2d(world_uv * 2.5) * 0.3;
	
	// Puddle mask: 1.0 where water accumulates in depressions
	float puddle_mask = smoothstep(puddle_threshold - 0.08, puddle_threshold + 0.08, n) * wetness;
	
	// Darken wet asphalt and blend into glassy puddle mirror
	vec3 base_rgb = mix(asphalt_color.rgb, wet_color.rgb, wetness * 0.6);
	vec3 final_rgb = mix(base_rgb, wet_color.rgb * 0.8, puddle_mask);
	
	// Mirror finish on puddles enables Forward+ SSR reflections
	float final_roughness = mix(roughness_dry, roughness_puddle, puddle_mask);
	
	ALBEDO = final_rgb;
	ROUGHNESS = final_roughness;
	METALLIC = mix(0.02, 0.12, puddle_mask);
	SPECULAR = mix(0.3, 0.95, puddle_mask);
	CLEARCOAT = puddle_mask;
	CLEARCOAT_ROUGHNESS = 0.02;
}
