shader_type spatial;
render_mode cull_disabled, unshaded, depth_draw_never;

uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;
uniform sampler2D screen_texture : source_color, hint_screen_texture, repeat_disable, filter_nearest;

uniform bool enable_fog = false;
uniform vec3 fog_color : source_color = vec3(0.72, 0.77, 0.83);
uniform vec3 noise_color : source_color = vec3(0.66, 0.70, 0.74);
uniform float fog_distance : hint_range(1.0, 6000.0) = 120.0;
uniform float fog_fade_range : hint_range(1.0, 6000.0) = 60.0;
uniform bool enable_noise = false;
uniform float noise_time_fac : hint_range(0.1, 10.0) = 4.0;
uniform bool enable_color_limitation = true;
uniform int color_levels : hint_range(2, 256) = 32;
uniform bool enable_dithering = true;
uniform float dither_strength : hint_range(0.0, 1.0) = 0.35;
uniform float effect_opacity : hint_range(0.0, 1.0) = 1.0;


float hash12(vec2 p) {
	float t = TIME / max(noise_time_fac, 0.001);
	return fract(sin(dot(p, vec2(12.9898, 78.233)) + t) * 43758.5453);
}


vec3 quantize_color(vec3 color, int levels) {
	float q = max(float(levels - 1), 1.0);
	return floor(color * q + 0.5) / q;
}


float bayer4x4(ivec2 fragcoord) {
	int x = fragcoord.x % 4;
	int y = fragcoord.y % 4;
	if (x < 0) {
		x += 4;
	}
	if (y < 0) {
		y += 4;
	}

	if (y == 0) {
		if (x == 0) { return 0.0 / 16.0; }
		if (x == 1) { return 8.0 / 16.0; }
		if (x == 2) { return 2.0 / 16.0; }
		return 10.0 / 16.0;
	}
	if (y == 1) {
		if (x == 0) { return 12.0 / 16.0; }
		if (x == 1) { return 4.0 / 16.0; }
		if (x == 2) { return 14.0 / 16.0; }
		return 6.0 / 16.0;
	}
	if (y == 2) {
		if (x == 0) { return 3.0 / 16.0; }
		if (x == 1) { return 11.0 / 16.0; }
		if (x == 2) { return 1.0 / 16.0; }
		return 9.0 / 16.0;
	}
	if (x == 0) { return 15.0 / 16.0; }
	if (x == 1) { return 7.0 / 16.0; }
	if (x == 2) { return 13.0 / 16.0; }
	return 5.0 / 16.0;
}


void vertex() {
	// Full-screen clip-space quad.
	POSITION = vec4(VERTEX.xy, 0.0, 1.0);
}


void fragment() {
	vec3 screen_color = texture(screen_texture, SCREEN_UV).rgb;
	vec3 final_color = screen_color;

	vec2 screen_coords = SCREEN_UV * 2.0 - 1.0;
	float depth = texture(depth_texture, SCREEN_UV).x;
	vec3 ndc = vec3(screen_coords, depth);
	vec4 view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	view.xyz /= max(view.w, 0.0001);
	float linear_depth = -view.z;
	float fog_end = max(fog_distance, 1.0);
	float fog_start = max(fog_end - max(fog_fade_range, 1.0), 0.0);
	float fog_factor = smoothstep(fog_start, fog_end, max(linear_depth, 0.0));

	if (enable_noise) {
		vec3 two_color_noise = mix(noise_color, fog_color, hash12(screen_coords));
		final_color = mix(final_color, two_color_noise, fog_factor);
	}
	if (enable_fog) {
		final_color = mix(final_color, fog_color, fog_factor);
	}
	if (enable_color_limitation) {
		final_color = quantize_color(final_color, color_levels);
	}
	if (enable_dithering && dither_strength > 0.0) {
		float threshold = bayer4x4(ivec2(FRAGCOORD.xy)) - 0.5;
		final_color += vec3(threshold * dither_strength / max(float(color_levels), 2.0));
		final_color = clamp(final_color, 0.0, 1.0);
	}

	ALBEDO = mix(screen_color, final_color, effect_opacity);
}
