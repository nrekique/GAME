#define USE_CAUSTICS 1
#define USE_REFRACTION 1
#define USE_DISPLACEMENT 1
#define USE_STYLIZED_LIGHTING 0
#define USE_UNSHADED 0

shader_type spatial;
#if USE_UNSHADED
render_mode unshaded, depth_draw_never;
#else
render_mode depth_draw_never;
#endif

uniform sampler2D DEPTH_TEXTURE : hint_depth_texture;

group_uniforms Color;
uniform vec4 surface_color : source_color = vec4(0.72, 0.58, 0.34, 1.0);
uniform vec4 depth_color : source_color = vec4(0.36, 0.24, 0.12, 1.0);
uniform vec4 foam_color : source_color = vec4(0.88, 0.78, 0.58, 1.0);
uniform float depth_size = 10.0;
uniform float screen_color_mix : hint_range(0.0, 1.0, 0.01) = 0.12;
uniform float foam_strength : hint_range(0.0, 1.0, 0.01) = 0.35;

group_uniforms Roughness;
uniform float surface_roughness : hint_range(0.0, 1.0, 0.01) = 0.9;
uniform float foam_roughness : hint_range(0.0, 1.0, 0.01) = 0.95;

#if USE_CAUSTICS
group_uniforms Caustics;
uniform sampler2D caustics_texture;
uniform float caustics_strength = 0.9;
uniform vec2 caustics_scale = vec2(0.7);
#endif

group_uniforms Wave;
uniform sampler2D wave_texture;
#if !USE_UNSHADED
uniform sampler2D wave_normal_texture;
#endif
uniform float wave_softness : hint_range(0.0, 10.0, 0.1) = 2.2;
uniform vec2 wave_scale = vec2(0.12);
uniform vec2 wave_layer_scale = vec2(1.4);
uniform float wave_highlight : hint_range(0.0, 1.0, 0.05) = 0.15;

group_uniforms WaveMotion;
uniform vec2 wave_velocity = vec2(0.04, 0.01);

group_uniforms Foam;
uniform sampler2D foam_texture;
uniform float edge_foam_depth_size = 0.5;
uniform float wave_foam_amount : hint_range(0.0, 1.0, 0.01) = 0.25;
uniform float foam_start : hint_range(0.0, 1.0, 0.05) = 0.45;
uniform float foam_end : hint_range(0.0, 1.0, 0.05) = 0.9;
uniform float foam_exponent = 2.4;

#if USE_REFRACTION
group_uniforms Refraction;
uniform float refraction_amount = 0.06;
uniform float refraction_exponent = 0.8;
#endif

#if USE_DISPLACEMENT
group_uniforms Displacement;
uniform float displacement_amount = 0.03;
#endif

#if USE_STYLIZED_LIGHTING && !USE_UNSHADED
group_uniforms Lighting;
uniform float diffuse_steps = 12.0;
uniform float diffuse_smoothness : hint_range(0.0, 1.0, 0.01) = 0.2;
uniform float specular_steps = 12.0;
uniform float specular_smoothness : hint_range(0.0, 1.0, 0.01) = 0.2;
#endif

uniform sampler2D screen_texture : hint_screen_texture;
varying vec3 world_pos;

#if USE_CAUSTICS
vec3 sample_caustics(vec2 uv) {
	vec2 caustics_uv = uv * caustics_scale;
	return vec3(
		texture(caustics_texture, caustics_uv).r,
		texture(caustics_texture, caustics_uv + vec2(0.02, 0.02)).r,
		texture(caustics_texture, caustics_uv + vec2(0.03, 0.01)).r
	);
}
#endif

vec4 sample_world_dpos(vec2 screen_uv, mat4 inv_proj_mat, mat4 inv_view_mat) {
	vec4 clip_pos = vec4(screen_uv * 2.0 - 1.0, texture(DEPTH_TEXTURE, screen_uv).r, 1.0);
	vec4 view_pos = inv_proj_mat * clip_pos;
	view_pos /= view_pos.w;
	vec4 world_dpos = inv_view_mat * view_pos;
	return world_dpos;
}

vec4 sample_wave(sampler2D tex, vec2 uv, vec2 velocity, float lod) {
	vec2 base_uv = uv * wave_scale;
	vec2 wave_uv1 = (base_uv * wave_layer_scale) + (TIME * -velocity);
	float wave1 = textureLod(tex, wave_uv1, lod).r;

	vec2 wave_uv2 = base_uv + (TIME * velocity);
	vec4 wave2 = textureLod(tex, wave_uv2 - (wave1 * 0.1), lod);
	return wave2;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;

	#if USE_DISPLACEMENT
	float wave = sample_wave(wave_texture, world_pos.xz, wave_velocity, wave_softness).r;
	VERTEX.y += wave * displacement_amount;
	#endif
}

void fragment() {
	float wave = sample_wave(wave_texture, world_pos.xz, wave_velocity, wave_softness).r;
	wave = smoothstep(0.0, 1.0, wave);

	vec2 screen_uv = SCREEN_UV;
	#if USE_REFRACTION
	screen_uv += ((pow(wave, refraction_exponent) * 2.0 - 0.5) * 0.01 * refraction_amount);
	vec4 world_dpos = sample_world_dpos(screen_uv, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX);
	float pre_depth = pow(clamp((world_dpos.y - world_pos.y + depth_size) / depth_size, 0.0, 1.0), 4.0);
	screen_uv = mix(screen_uv, SCREEN_UV, pre_depth);
	if (world_dpos.y - world_pos.y > 0.0) {
		screen_uv = SCREEN_UV;
	}
	#else
	vec4 world_dpos = sample_world_dpos(screen_uv, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX);
	#endif

	world_dpos = sample_world_dpos(screen_uv, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX);
	vec2 surface_uv = world_dpos.xz * 0.2;
	float depth = pow(clamp((world_dpos.y - world_pos.y + depth_size) / depth_size, 0.0, 1.0), 4.0);

	#if USE_CAUSTICS
	vec3 caustics1 = sample_caustics(surface_uv + (TIME * -wave_velocity));
	vec3 caustics2 = sample_caustics((surface_uv + (caustics1.r * 0.05)) + (TIME * (wave_velocity * 0.5)));
	vec3 caustics = pow(max(caustics2, vec3(0.0)), vec3(2.0)) * (1.0 - depth);
	#endif

	float edge_foam_depth = clamp((world_dpos.y - world_pos.y + edge_foam_depth_size) / edge_foam_depth_size, 0.0, 1.0);
	float wave_foam = wave;
	float foam = max(edge_foam_depth, wave_foam * wave_foam_amount);

	float foam_shape = 1.0 - texture(foam_texture, world_pos.xz * 0.5).r;
	foam = clamp((foam - foam_start) / (foam_end - foam_start), 0.0, 1.0);
	foam = clamp((foam - foam_shape) / (1.0 - foam_shape), 0.0, 1.0);
	foam = pow(foam, foam_exponent);

	vec3 flat_color = mix(depth_color, surface_color, depth).rgb;
	vec4 screen = texture(screen_texture, screen_uv);
	vec3 color = screen.rgb;
	#if USE_CAUSTICS
	color += caustics * caustics_strength * 0.18;
	#endif
	color = mix(flat_color, color, screen_color_mix * depth);
	color = mix(color, surface_color.rgb, wave * wave_highlight);
	color = mix(color, foam_color.rgb, foam * foam_strength);

	#if !USE_UNSHADED
	vec3 wave_normal_map = sample_wave(wave_normal_texture, world_pos.xz, wave_velocity, wave_softness).rgb;
	NORMAL_MAP = wave_normal_map;
	#endif

	ROUGHNESS = mix(surface_roughness, foam_roughness, foam);
	ALBEDO = color;
}

#if USE_STYLIZED_LIGHTING && !USE_UNSHADED
void light() {
	float ndotl = dot(NORMAL, LIGHT) * ATTENUATION;
	float diffuse_light = ndotl;
	float light_mult = diffuse_light * diffuse_steps;
	float light_step_base = floor(light_mult);
	float light_factor = light_mult - light_step_base;
	light_factor = smoothstep(0.5 - diffuse_smoothness * 0.5, 0.5 + diffuse_smoothness * 0.5, light_factor);
	diffuse_light = (light_step_base + light_factor) / diffuse_steps;
	DIFFUSE_LIGHT += (LIGHT_COLOR + ALBEDO) * diffuse_light / PI;

	float roughness = mix(0.01, 0.99, ROUGHNESS);
	vec3 h = normalize(VIEW + LIGHT);
	float ndoth = clamp(dot(NORMAL, h), 0.0, 1.0) * ATTENUATION;
	float specular = clamp(pow(ndoth, 16.0 / roughness), 0.1, 0.99);
	specular = mix(pow(specular, 2.0 - roughness), 0.0, pow(roughness, 0.1));
	float specular_mult = specular * specular_steps;
	float specular_step_base = floor(specular_mult);
	float specular_factor = specular_mult - specular_step_base;
	specular_factor = smoothstep(0.5 - specular_smoothness * 0.5, 0.5 + specular_smoothness * 0.5, specular_factor);
	specular = (specular_step_base + specular_factor) / specular_steps;
	SPECULAR_LIGHT += (LIGHT_COLOR + ALBEDO) * specular;
}
#endif
