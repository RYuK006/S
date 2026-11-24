shader_type sky;

// Physical Atmospheric Sky Shader with Rayleigh/Mie Scattering and Sun Corona
uniform vec4 sky_zenith_color : source_color = vec4(0.18, 0.42, 0.82, 1.0);
uniform vec4 sky_horizon_color : source_color = vec4(0.72, 0.78, 0.88, 1.0);
uniform vec4 ground_color : source_color = vec4(0.18, 0.15, 0.12, 1.0);
uniform vec4 sun_color : source_color = vec4(1.0, 0.95, 0.85, 1.0);
uniform float sun_disk_size : hint_range(0.01, 0.15) = 0.045;
uniform float sun_corona_size : hint_range(0.05, 0.6) = 0.28;
uniform float exposure : hint_range(0.5, 3.0) = 1.15;

void sky() {
	vec3 ray = EYEDIR;
	float elevation = ray.y;
	
	// Sun direction (LIGHT0_DIRECTION points towards sun)
	vec3 sun_dir = LIGHT0_DIRECTION;
	float sun_dot = max(0.0, dot(ray, sun_dir));
	
	// Two-tone Rayleigh atmosphere gradient
	vec3 sky_color = mix(sky_horizon_color.rgb, sky_zenith_color.rgb, clamp(pow(max(0.0, elevation), 0.55), 0.0, 1.0));
	
	// Below horizon ground tone
	if (elevation < 0.0) {
		sky_color = mix(sky_horizon_color.rgb, ground_color.rgb, clamp(-elevation * 3.0, 0.0, 1.0));
	}
	
	// Mie scattering sun corona and sharp sun disk
	float corona = pow(sun_dot, 1.0 / sun_corona_size) * 0.45;
	float sun_disk = smoothstep(1.0 - sun_disk_size * 0.02, 1.0, sun_dot) * 12.0;
	
	vec3 final_color = (sky_color + (sun_color.rgb * (corona + sun_disk))) * exposure;
	COLOR = final_color;
}
