shader_type canvas_item;

uniform sampler2D screen_texture: hint_screen_texture, filter_linear_mipmap;

uniform sampler2D distortion_map: hint_normal, repeat_enable;
uniform vec2 distortion_velocity = vec2(0.01, 0.01);
uniform float distortion_strength = 1.0;
uniform vec2 distortion_scale = vec2(1.0);
uniform vec2 distortion_offset = vec2(0.0);
uniform float distortion_lod = 0.0;
uniform float screen_sampling_lod = 2.0;

void fragment() {
    vec2 uv = SCREEN_UV;

	vec2 distortion_uv = fma(uv, distortion_scale, distortion_offset + distortion_velocity * TIME);
	vec2 distortion_sample = textureLod(distortion_map, distortion_uv, distortion_lod).xy * 2.0 - 1.0;
	vec2 distortion_uv_offset = distortion_sample * distortion_strength;
	vec2 uv_distorted = uv - distortion_uv_offset;

	COLOR = textureLod(screen_texture, uv_distorted, screen_sampling_lod);
}
