shader_type spatial;
render_mode depth_draw_opaque, cull_back, diffuse_lambert, specular_disabled;

uniform bool use_texture = false;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform float roughness : hint_range(0.0, 1.0) = 1.0;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform float vertex_snap : hint_range(32.0, 512.0) = 160.0;
uniform float color_steps : hint_range(2.0, 64.0) = 24.0;
uniform float posterize_strength : hint_range(0.0, 1.0) = 0.18;
uniform float affine_warp_strength : hint_range(0.0, 1.0) = 0.35;
uniform float uv_jitter : hint_range(0.0, 0.02) = 0.0015;
uniform vec2 uv_scale = vec2(1.0, 1.0);
uniform vec2 uv_offset = vec2(0.0, 0.0);
uniform bool jitter_depth_independent = true;
uniform bool jitter_z_coordinate = false;
uniform bool affine_texture_mapping = false;
uniform float affine_mapping_strength : hint_range(0.0, 1.0) = 0.0;
uniform float alpha_scissor_threshold : hint_range(0.0, 1.0) = 0.0;
uniform bool dithering_enabled = true;
uniform float color_dither_strength : hint_range(0.0, 2.0) = 1.0;
uniform int dither_resolution_scale : hint_range(1, 8) = 1;

global uniform sampler2D dither_texture : filter_nearest;
global uniform float dither_scale;
global uniform float dither_strength;
global uniform float dither_levels;

varying vec2 v_uv;
varying vec2 v_affine_uv;
varying float v_affine_depth;


void vertex() {
	vec4 view = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec4 clip = PROJECTION_MATRIX * view;
	float w = max(abs(clip.w), 0.0001);
	float snap = max(vertex_snap, 1.0);

	if (jitter_depth_independent) {
		vec2 ndc = clip.xy / w;
		ndc = floor(ndc * snap) / snap;
		clip.xy = ndc * w;

		if (jitter_z_coordinate) {
			float z_ndc = clip.z / w;
			z_ndc = floor(z_ndc * snap) / snap;
			clip.z = z_ndc * w;
		}
		POSITION = clip;
	} else {
		vec3 snapped_view = floor(view.xyz * snap) / snap;
		if (!jitter_z_coordinate) {
			snapped_view.z = view.z;
		}
		POSITION = PROJECTION_MATRIX * vec4(snapped_view, 1.0);
	}

	v_uv = UV;
	v_affine_depth = max(abs(view.z), 0.0001);
	v_affine_uv = UV * v_affine_depth;
}


void light() {
	float light_value = (dot(NORMAL, LIGHT) + 1.0) * 0.5;
	float scale = max(dither_scale, 0.001);
	vec2 ts = vec2(textureSize(dither_texture, 0)) * scale;
	ts = max(ts, vec2(1.0));
	vec2 uv = mod(FRAGCOORD.xy, ts) / ts;
	light_value += texture(dither_texture, uv).r * dither_strength;
	light_value = clamp(light_value, 0.0, 1.0);
	float levels = max(dither_levels, 1.0);
	light_value = floor(light_value * levels) / levels;
	DIFFUSE_LIGHT += (light_value * LIGHT_COLOR) * ATTENUATION;
}


vec3 quantize_color(vec3 color, float steps) {
	float s = max(steps, 2.0);
	return floor(color * s) / s;
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


vec3 quantize_color_dithered(vec3 color, float steps, ivec2 fragcoord, int resolution_scale, float strength) {
	float levels = max(steps, 2.0);
	float max_index = levels - 1.0;
	int dscale = resolution_scale;
	if (dscale < 1) {
		dscale = 1;
	}
	ivec2 p = ivec2(vec2(fragcoord) / float(dscale));
	float threshold = (bayer4x4(p) - 0.5) * clamp(strength, 0.0, 2.0);
	vec3 idx = floor(color * max_index + vec3(0.5 + threshold));
	idx = clamp(idx, vec3(0.0), vec3(max_index));
	return idx / max_index;
}


void fragment() {
	vec2 uv = v_uv;
	if (affine_texture_mapping) {
		vec2 affine_uv = v_affine_uv / max(v_affine_depth, 0.0001);
		float affine_mix = clamp(affine_mapping_strength, 0.0, 1.0);
		uv = mix(v_uv, affine_uv, affine_mix);
	}
	uv = uv * uv_scale + uv_offset;
	float warp = clamp(affine_warp_strength, 0.0, 1.0);
	if (warp > 0.0) {
		// Keep this in UV space so it is stable when the camera moves.
		vec2 centered = uv - 0.5;
		uv += centered * (warp * 0.02);
	}
	if (uv_jitter > 0.0) {
		// Stable UV quantization (no screen-space swim).
		float q = clamp(uv_jitter * 2000.0, 0.0, 1.0);
		vec2 snapped = floor(uv * 256.0) / 256.0;
		uv = mix(uv, snapped, q);
	}

	float alpha = albedo_color.a;
	vec3 base = albedo_color.rgb;
	if (use_texture) {
		vec4 texel = texture(albedo_tex, uv);
		base *= texel.rgb;
		alpha *= texel.a;
	}

	vec3 qbase = quantize_color(base, color_steps);
	if (dithering_enabled) {
		qbase = quantize_color_dithered(base, color_steps, ivec2(FRAGCOORD.xy), dither_resolution_scale, color_dither_strength);
	}

	float poster = clamp(posterize_strength, 0.0, 1.0);
	if (dithering_enabled) {
		poster = max(poster, clamp(0.55 * color_dither_strength, 0.0, 1.0));
	}
	base = mix(base, qbase, poster);
	ALBEDO = base;
	if (alpha_scissor_threshold > 0.0) {
		ALPHA = alpha;
		ALPHA_SCISSOR_THRESHOLD = alpha_scissor_threshold;
	}
	ROUGHNESS = roughness;
	METALLIC = metallic;
}
