shader_type spatial;

uniform sampler2D tiling_texture;
uniform float tiling_scale = 1.0;
uniform float roughness : hint_range(0.0, 1.0, 0.01) = 0.9;
uniform float metallic : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform bool use_texture_alpha = false;
uniform bool use_alpha_cutout = false;
uniform float alpha_cutoff : hint_range(0.0, 1.0, 0.01) = 0.5;

const float DEFAULT_SCALE = 256.0;

void fragment() {
	vec2 uv = FRAGCOORD.xy;
	vec2 tiling_uv = uv / (DEFAULT_SCALE * max(tiling_scale, 0.001) * -1.0);
	vec4 texture_result = texture(tiling_texture, tiling_uv);
	ALBEDO = texture_result.rgb;
	ALPHA = use_texture_alpha ? texture_result.a : 1.0;
	if (use_alpha_cutout) {
		ALPHA_SCISSOR_THRESHOLD = alpha_cutoff;
	}
	ROUGHNESS = roughness;
	METALLIC = metallic;
}
