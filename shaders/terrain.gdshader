shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// Realistic Multi-Layer PBR Terrain Shader with Procedural Triplanar Cliffs, Normal Grain & Magma Pulse
uniform float macro_scale : hint_range(0.001, 0.05) = 0.008;
uniform float micro_scale : hint_range(0.1, 5.0) = 1.2;
uniform float normal_strength : hint_range(0.0, 3.0) = 1.5;

// Procedural pseudo-random 2D noise
float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise2d(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash2(i);
	float b = hash2(i + vec2(1.0, 0.0));
	float c = hash2(i + vec2(0.0, 1.0));
	float d = hash2(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Procedural normal perturbation
vec3 calculate_procedural_normal(vec2 world_xz, vec3 normal) {
	float eps = 0.15;
	float h0 = noise2d(world_xz * micro_scale);
	float hx = noise2d((world_xz + vec2(eps, 0.0)) * micro_scale);
	float hz = noise2d((world_xz + vec2(0.0, eps)) * micro_scale);
	vec3 grain = normalize(vec3((h0 - hx) * normal_strength, 1.0, (h0 - hz) * normal_strength));
	return normalize(normal + grain * 0.35);
}

void fragment() {
	vec3 world_pos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 world_norm = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	
	// Vertex color supplies regional biome albedo & slope tint
	vec4 v_col = COLOR;
	
	// Natural micro-grain normal variation
	vec3 perturbed_norm = calculate_procedural_normal(world_pos.xz, world_norm);
	NORMAL = (VIEW_MATRIX * vec4(perturbed_norm, 0.0)).xyz;
	
	// Slope detection (0 = flat plain, 1 = sheer cliff)
	float slope = 1.0 - clamp(world_norm.y, 0.0, 1.0);
	
	// Magma emission check: high-intensity orange vertex colors in Volcano Ridge emit light
	bool is_magma = (v_col.r > 1.1 && v_col.b < 0.2);
	if (is_magma) {
		float pulse = 0.85 + 0.15 * sin(TIME * 2.5 + world_pos.x * 0.05 + world_pos.z * 0.05);
		ALBEDO = v_col.rgb * pulse;
		EMISSION = v_col.rgb * pulse * 2.2;
		ROUGHNESS = 0.35;
		METALLIC = 0.1;
		SPECULAR = 0.5;
	} else {
		// PBR ground surface
		ALBEDO = v_col.rgb;
		
		// Snow vs sand vs asphalt roughness tuning based on color luminosity
		float lum = dot(v_col.rgb, vec3(0.299, 0.587, 0.114));
		if (lum > 0.82) {
			// Alpine snow: crystalline crust with subtle sun specular sparkle
			ROUGHNESS = mix(0.55, 0.82, slope);
			SPECULAR = 0.45;
			METALLIC = 0.02;
		} else if (lum < 0.25) {
			// Volcanic rock / asphalt: dark aggregate with chiseled rock facets
			ROUGHNESS = mix(0.85, 0.95, slope);
			SPECULAR = 0.18;
			METALLIC = 0.06;
		} else {
			// Desert sand & sandstone: matte granular roughness
			ROUGHNESS = mix(0.88, 0.96, slope);
			SPECULAR = 0.12;
			METALLIC = 0.01;
		}
	}
}
