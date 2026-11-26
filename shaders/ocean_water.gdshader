shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, specular_schlick_ggx;

uniform vec3 shallow_color : source_color = vec3(0.02, 0.30, 0.40);
uniform vec3 deep_color : source_color = vec3(0.008, 0.045, 0.12);
uniform float metallic_amount : hint_range(0.0, 1.0) = 0.24;
uniform float roughness_amount : hint_range(0.0, 1.0) = 0.055;
uniform float wave_scale = 0.11;
uniform float wave_height = 0.12;
uniform float time_speed = 0.85;

varying vec3 v_world_pos;

vec3 calc_wave_height_and_grad(vec2 xz, float t) {
	float h = 0.0;
	float gx = 0.0;
	float gz = 0.0;

	const vec2 dirs[6] = vec2[6](
		vec2(0.86, 0.51),
		vec2(-0.62, 0.78),
		vec2(0.31, -0.95),
		vec2(-0.92, -0.39),
		vec2(0.55, 0.83),
		vec2(-0.18, -0.98)
	);
	const float freqs[6] = float[6](0.16, 0.32, 0.68, 1.35, 2.40, 4.10);
	const float amps[6] = float[6](0.36, 0.22, 0.14, 0.085, 0.045, 0.022);
	const float spds[6] = float[6](1.1, 1.45, 1.9, 2.5, 3.1, 3.9);

	for (int i = 0; i < 6; i++) {
		float f = freqs[i] * wave_scale * 5.0;
		float a = amps[i] * wave_height;
		float ph = dot(xz, dirs[i]) * f + t * spds[i] * time_speed;
		h += sin(ph) * a;
		float c = cos(ph) * a * f;
		gx += dirs[i].x * c;
		gz += dirs[i].y * c;
	}
	return vec3(h, gx, gz);
}

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// Subtle vertical ripple so water never fights low sandy shoreline triangles
	float swell = sin(wp.x * 0.05 + TIME * 0.8) * 0.025 + cos(wp.z * 0.065 - TIME * 0.65) * 0.02;
	VERTEX.y += swell;
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 w = calc_wave_height_and_grad(v_world_pos.xz, TIME);
	vec3 w_norm = normalize(vec3(-w.y * 2.8, 1.0, -w.z * 2.8));
	NORMAL = normalize((VIEW_MATRIX * vec4(w_norm, 0.0)).xyz);

	float ndotv = max(dot(NORMAL, VIEW), 0.0);
	float fresnel = pow(1.0 - ndotv, 4.0);

	float d_bay = length(v_world_pos.xz - vec2(3050.0, 2600.0));
	float coast_prox = clamp(smoothstep(350.0, 960.0, d_bay), 0.0, 1.0);
	vec3 water_tint = mix(deep_color, shallow_color, clamp(coast_prox * 0.78 + fresnel * 0.35, 0.0, 1.0));

	float foam = smoothstep(wave_height * 0.50, wave_height * 0.82, w.x);

	ALBEDO = mix(water_tint, vec3(0.86, 0.94, 0.98), foam * 0.22);
	METALLIC = metallic_amount;
	ROUGHNESS = mix(roughness_amount, 0.22, foam * 0.35);
	SPECULAR = 0.82;
}
