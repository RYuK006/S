shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, specular_schlick_ggx;

uniform vec3 shallow_color : source_color = vec3(0.03, 0.42, 0.48);
uniform vec3 deep_color : source_color = vec3(0.008, 0.055, 0.145);
uniform float metallic_amount : hint_range(0.0, 1.0) = 0.18;
uniform float roughness_amount : hint_range(0.0, 1.0) = 0.045;
uniform float wave_scale = 0.14;
uniform float wave_height = 0.11;
uniform float time_speed = 0.90;

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
	const float freqs[6] = float[6](0.18, 0.36, 0.75, 1.55, 2.85, 5.20);
	const float amps[6] = float[6](0.32, 0.21, 0.14, 0.09, 0.05, 0.028);
	const float spds[6] = float[6](1.05, 1.40, 1.85, 2.40, 3.05, 3.80);

	for (int i = 0; i < 6; i++) {
		float f = freqs[i] * wave_scale * 5.2;
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
	float swell = sin(wp.x * 0.055 + TIME * 0.85) * 0.03 + cos(wp.z * 0.068 - TIME * 0.70) * 0.025;
	VERTEX.y += swell;
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 w = calc_wave_height_and_grad(v_world_pos.xz, TIME);
	vec3 w_norm = normalize(vec3(-w.y * 2.4, 1.0, -w.z * 2.4));
	NORMAL = normalize((VIEW_MATRIX * vec4(w_norm, 0.0)).xyz);

	float ndotv = max(dot(NORMAL, VIEW), 0.0);
	float fresnel = pow(1.0 - ndotv, 4.2);

	// Analytical coastline shoreline proximity matching DEM beach curve
	float coast_curve_x = 2160.0 - 0.00014 * (v_world_pos.z - 200.0) * (v_world_pos.z - 200.0);
	float shore_x = coast_curve_x + 48.0 + sin(v_world_pos.z * 0.004) * 18.0;
	float dist_from_shore = max(0.0, v_world_pos.x - shore_x);

	float shallows = 1.0 - smoothstep(25.0, 260.0, dist_from_shore);
	vec3 water_tint = mix(deep_color, shallow_color, clamp(shallows * 0.88 + fresnel * 0.30, 0.0, 1.0));

	// White breaking surf bands lapping gently along coastal cove + crisp wave crests
	float surf_wave = sin(dist_from_shore * 0.24 - TIME * 2.2 + sin(v_world_pos.z * 0.03) * 2.5);
	float shore_foam = smoothstep(0.55, 0.92, surf_wave) * (1.0 - smoothstep(0.0, 95.0, dist_from_shore));
	float crest_foam = smoothstep(wave_height * 0.56, wave_height * 0.88, w.x);
	float total_foam = clamp(max(shore_foam * 0.85, crest_foam * 0.35), 0.0, 1.0);

	ALBEDO = mix(water_tint, vec3(0.90, 0.96, 0.99), total_foam * 0.72);
	METALLIC = metallic_amount;
	ROUGHNESS = mix(roughness_amount, 0.28, total_foam * 0.65);
	SPECULAR = 0.85;
}
