shader_type canvas_item;

uniform int mode: hint_range(0, 3) = 0;
uniform bool cycle_mode = true;

group_uniforms scalars;
uniform float amplitude: hint_range(0, 1000) = 25;
uniform float normal_sampling_distance = 4.0;
uniform float steepness_sampling_distance = 4.0;
uniform float biome_sampling_distance = 4.0;

group_uniforms textures;
uniform sampler2D noise_map: hint_default_white;
uniform sampler2D falloff_map: hint_default_white;

group_uniforms grass_definition;
uniform float max_grass_steepness: hint_range(0, 1.0) = 0.6;
uniform float grass_edge_smoothing: hint_range(0, 1.0) = 0.03;
uniform sampler2D grass_edge_noise: hint_default_white;
uniform float grass_edge_noise_intensity: hint_range(0, 1.0) = 0.5;

group_uniforms sand_definition;
uniform float max_sand_height: hint_range(0, 1.0) = 0.15;
uniform float sand_edge_smoothing: hint_range(0, 1.0) = 0.03;
uniform sampler2D sand_edge_noise: hint_default_white;
uniform float sand_edge_noise_intensity: hint_range(0, 1.0) = 0.5;

float bilinear_sample(sampler2D tex, vec2 uv, vec2 tex_size) {
    vec2 pixel = uv * tex_size - 0.5;
    vec2 base_uv = floor(pixel) / tex_size;
    vec2 f = fract(pixel);

    float tl = texture(tex, base_uv).r;
    float tr = texture(tex, base_uv + vec2(1.0 / tex_size.x, 0.0)).r;
    float bl = texture(tex, base_uv + vec2(0.0, 1.0 / tex_size.y)).r;
    float br = texture(tex, base_uv + vec2(1.0 / tex_size.x, 1.0 / tex_size.y)).r;

    float t = mix(tl, tr, f.x);
    float b = mix(bl, br, f.x);
    return mix(t, b, f.y);
}

//vec4 texturePointSmooth(sampler2D smp, vec2 uv, vec2 pixel_size)
//{
	//vec2 ddx = dFdx(uv);
	//vec2 ddy = dFdy(uv);
	//vec2 lxy = sqrt(ddx * ddx + ddy * ddy);
	//
	//vec2 uv_pixels = uv / pixel_size;
	//
	//vec2 uv_pixels_floor = round(uv_pixels) - vec2(0.5f);
	//vec2 uv_dxy_pixels = uv_pixels - uv_pixels_floor;
	//
	//uv_dxy_pixels = clamp((uv_dxy_pixels - vec2(0.5f)) * pixel_size / lxy + vec2(0.5f), 0.0f, 1.0f);
	//
	//uv = uv_pixels_floor * pixel_size;
	//
	//return textureGrad(smp, uv + uv_dxy_pixels * pixel_size, ddx, ddy);
//}
//
//vec3 encode_height(float height) {
	//float r = floor(height * 255.0) / 255.0;
	//float g = floor(fract(height * 255.0) * 255.0) / 255.0;
	//float b = fract(height * 255.0 * 255.0);
	//return vec3(r + g + b, 0.0, 0.0);
//}

float get_height_smooth(vec2 pos) {
	vec2 tex_size = vec2(textureSize(noise_map, 0));
    float noise = bilinear_sample(noise_map, pos, tex_size);
	//noise = texture(noise_map, pos).r;
    float falloff = bilinear_sample(falloff_map, pos, tex_size);
	//falloff = texture(falloff_map, pos).r;
    return noise * falloff;
}

float get_height(vec2 pos) {
	return texture(noise_map, pos).r * texture(falloff_map, pos).r;
}

vec3 get_normal(vec2 pos, float sampling_distance) {
	vec2 pixel_size = 1.0 / vec2(textureSize(noise_map, 0));
	vec2 offset = pixel_size * sampling_distance;
	
	float left = get_height_smooth(pos - vec2(offset.x, 0.0)) * amplitude;
	float right = get_height_smooth(pos + vec2(offset.x, 0.0)) * amplitude;
	float up = get_height_smooth(pos - vec2(0.0, offset.y)) * amplitude;
	float down = get_height_smooth(pos + vec2(0.0, offset.y)) * amplitude;

	vec3 normal = normalize(vec3(left - right, down - up, 2.0 * sampling_distance));
	//return vec3(0.5, 0.5, 1.0);
	return normal * 0.5 + 0.5;
}

float get_steepness(vec2 pos, float sampling_distance) {
	return acos(get_normal(pos, sampling_distance).z);
}

vec3 get_biome(vec2 pos, float sampling_distance) {
	float height = get_height_smooth(pos);
	float steepness = get_steepness(pos, sampling_distance);
	
	float grass_noise = mix(1.0, texture(grass_edge_noise, pos).r * 2.0, grass_edge_noise_intensity);
	float sand_noise = mix(1.0, texture(sand_edge_noise, pos).r * 2.0, sand_edge_noise_intensity);
	
	// TODO: make the smoothing terms relative to the value
	
	float height_transition = 1.0 - smoothstep(max_sand_height - sand_edge_smoothing / 2.0, max_sand_height + sand_edge_smoothing / 2.0, height * sand_noise);
	float steepness_transition = 1.0 - smoothstep(max_grass_steepness - grass_edge_smoothing / 2.0, max_grass_steepness + grass_edge_smoothing / 2.0, steepness * grass_noise);
	
	float priority = 1.0;
	float sand_factor = height_transition;
	priority -= sand_factor;
	float grass_factor = min(priority, steepness_transition);
	priority -= grass_factor;
	float cliff_factor = min(priority, 1.0 - grass_factor);
	
	return vec3(grass_factor, cliff_factor, sand_factor);
}
//
//vec3 get_biome(vec2 pos, float sampling_distance) {
	//float height = get_height_smooth(pos);
	//float steepness = get_steepness(pos, sampling_distance);
	//
	//float grass_noise = mix(1.0, texture(grass_edge_noise, pos).r, grass_edge_noise_intensity);
	//float sand_noise = mix(1.0, texture(sand_edge_noise, pos).r, sand_edge_noise_intensity);
	//
	//float cliff_factor = smoothstep(max_grass_steepness - grass_edge_smoothing, max_grass_steepness, steepness * grass_noise);
	//float sand_factor = 1.0 - smoothstep(max_sand_height - sand_edge_smoothing, max_sand_height, height * sand_noise);
	//float grass_factor = (1.0 - cliff_factor) * (1.0 - sand_factor);
	//return vec3(grass_factor, cliff_factor * (1.0 - sand_factor), sand_factor);
	////return normalize(vec3(grass_factor, cliff_factor * (1.0 - sand_factor), sand_factor));
//}

void fragment() {
	int current_mode = int(mod(TIME, 4.0));
	if (!cycle_mode) {
		current_mode = mode;
	}
	
	if (current_mode == 0) {
		float height = get_height_smooth(UV);
		COLOR = vec4(height, height, height, 1.0);
	} else if (current_mode == 1) {
		vec3 normal = get_normal(UV, normal_sampling_distance);
		COLOR = vec4(normal, 1.0);
	} else if (current_mode == 2) {
		float steepness = get_steepness(UV, steepness_sampling_distance);
		COLOR = vec4(steepness, steepness, steepness, 1.0);
	} else if (current_mode == 3) {
		vec3 biome = get_biome(UV, biome_sampling_distance);
		COLOR = vec4(biome, 1.0);
	}
}