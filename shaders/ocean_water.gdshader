shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, diffuse_burley, specular_schlick_ggx;

// Forza Horizon 5 Coastal Ocean Shader: Dynamic Waves, Specular Glint & Depth Absorption
uniform vec4 shallow_color : source_color = vec4(0.08, 0.42, 0.52, 0.88);
uniform vec4 deep_color : source_color = vec4(0.03, 0.14, 0.28, 0.96);
uniform float wave_speed : hint_range(0.01, 1.0) = 0.08;
uniform float wave_scale : hint_range(0.01, 0.5) = 0.06;
uniform float wave_height : hint_range(0.0, 2.0) = 0.35;

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float wave_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash2(i);
	float b = hash2(i + vec2(1.0, 0.0));
	float c = hash2(i + vec2(0.0, 1.0));
	float d = hash2(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void vertex() {
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float w1 = sin((world_pos.x * wave_scale) + (TIME * wave_speed * 2.0));
	float w2 = cos((world_pos.z * wave_scale * 1.3) + (TIME * wave_speed * 1.5));
	float w3 = wave_noise(world_pos.xz * wave_scale * 2.0 + vec2(TIME * wave_speed));
	VERTEX.y += (w1 + w2 + w3 * 0.5) * wave_height;
}

void fragment() {
	vec3 world_pos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	
	// Dual scrolling wave normals
	vec2 uv1 = world_pos.xz * wave_scale + vec2(TIME * wave_speed, TIME * wave_speed * 0.5);
	vec2 uv2 = world_pos.xz * (wave_scale * 1.8) - vec2(TIME * wave_speed * 0.7, TIME * wave_speed * 1.2);
	
	float n1 = wave_noise(uv1);
	float n2 = wave_noise(uv2);
	vec3 wave_normal = normalize(vec3((n1 - n2) * 0.6, 1.0, (n2 - n1) * 0.6));
	NORMAL = (VIEW_MATRIX * vec4(wave_normal, 0.0)).xyz;
	
	// Fresnel reflection for realistic water surface look
	vec3 view_dir = normalize(VIEW);
	float fresnel = pow(1.0 - max(0.0, dot(NORMAL, view_dir)), 4.0);
	
	// Blend shallow shoreline turquoise with deep oceanic navy
	vec3 water_rgb = mix(deep_color.rgb, shallow_color.rgb, clamp(fresnel * 0.8, 0.0, 1.0));
	
	// Foam crests on wave peaks
	float foam = smoothstep(0.72, 0.85, (n1 + n2) * 0.5);
	water_rgb = mix(water_rgb, vec3(0.95, 0.98, 1.0), foam * 0.7);
	
	ALBEDO = water_rgb;
	ROUGHNESS = mix(0.05, 0.25, foam);
	METALLIC = 0.15;
	SPECULAR = 0.75;
	CLEARCOAT = 1.0;
	CLEARCOAT_ROUGHNESS = 0.02;
}
