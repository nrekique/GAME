shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D noise_texture : filter_linear_mipmap, repeat_enable;

uniform vec4 storm_color : source_color = vec4(0.78, 0.62, 0.36, 1.0);
uniform float intensity : hint_range(0.0, 1.0, 0.01) = 0.65;
uniform float near_blend : hint_range(0.0, 1.0, 0.01) = 0.08;
uniform float far_blend : hint_range(0.0, 1.0, 0.01) = 0.58;
uniform float grain_strength : hint_range(0.0, 1.0, 0.01) = 0.22;
uniform vec2 wind_dir = vec2(1.0, 0.2);
uniform float wind_speed = 0.15;
uniform float noise_scale = 1.2;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec4 src = texture(screen_texture, uv);
	// Stable fallback for canvas_item: distance-like blend from screen center.
	float center_dist = length(uv - vec2(0.5));
	float dist_factor = smoothstep(0.05, 0.72, center_dist);
	float haze = mix(near_blend, far_blend, dist_factor) * intensity;

	vec2 w = normalize(max(abs(wind_dir.x) + abs(wind_dir.y), 0.001) * vec2(wind_dir.x, wind_dir.y));
	vec2 noise_uv = uv * noise_scale + w * (TIME * wind_speed);
	float n0 = texture(noise_texture, noise_uv).r;
	float n1 = texture(noise_texture, noise_uv * 1.9 - w * (TIME * wind_speed * 1.7)).r;
	float n = (n0 * 0.65 + n1 * 0.35);
	float dust = (n - 0.5) * 2.0 * grain_strength * intensity;

	vec3 tinted = mix(src.rgb, storm_color.rgb, haze);
	tinted = mix(tinted, storm_color.rgb, clamp(abs(dust) * 0.7, 0.0, 1.0));
	tinted += vec3(dust * 0.15);
	COLOR = vec4(clamp(tinted, 0.0, 1.0), 1.0);
}
