shader_type canvas_item;

uniform int mode: hint_range(0, 3) = 0;
uniform bool cycle_mode = true;

group_uniforms scalars;
uniform float amplitude: hint_range(0, 500) = 25;

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

float get_height(vec2 pos) {
	return texture(noise_map, pos).r * texture(falloff_map, pos).r;
}

vec3 get_normal(vec2 pos) {
	vec2 pixel_size = 1.0 / vec2(textureSize(noise_map, 0));
	
	float height = get_height(pos);
	float right = get_height(vec2(min(1.0, pos.x + pixel_size.x), pos.y));
	float up = get_height(vec2(pos.x, min(1.0, pos.y + pixel_size.y)));
	
	float dx = abs(right - height) * amplitude;
	float dy = abs(up - height) * amplitude;
	
	vec3 normal = normalize(vec3(-dx, -dy, 1.0));
	return (normal + vec3(1.0)) * 0.5;
}

float get_steepness(vec2 pos) {
	vec2 pixel_size = 1.0 / vec2(textureSize(noise_map, 0));
	
	float height = get_height(pos);
	float right = get_height(vec2(min(1.0, pos.x + pixel_size.x), pos.y));
	float up = get_height(vec2(pos.x, min(1.0, pos.y + pixel_size.y)));
	
	float dx = abs(right - height) * amplitude;
	float dy = abs(up - height) * amplitude;
	
	return min(1.0, sqrt(dx * dx + dy * dy));
}

vec3 get_biome(vec2 pos) {
	float height = get_height(pos);
	float steepness = get_steepness(pos);
	
	float grass_noise = mix(1.0, texture(grass_edge_noise, pos).r, grass_edge_noise_intensity);
	float sand_noise = mix(1.0, texture(sand_edge_noise, pos).r, sand_edge_noise_intensity);
	
	float cliff_factor = smoothstep(max_grass_steepness - grass_edge_smoothing, max_grass_steepness, steepness * grass_noise);
	float sand_factor = 1.0 - smoothstep(max_sand_height - sand_edge_smoothing, max_sand_height, height * sand_noise);
	float grass_factor = (1.0 - cliff_factor) * (1.0 - sand_factor);
	
	return vec3(grass_factor, cliff_factor * (1.0 - sand_factor), sand_factor);
}

void fragment() {
	int current_mode = int(mod(TIME, 4.0));
	if (!cycle_mode) {
		current_mode = mode;
	}
	
	if (current_mode == 0) {
		float height = get_height(UV);
		COLOR = vec4(height, height, height, 1.0);
	} else if (current_mode == 1) {
		vec3 normal = get_normal(UV);
		COLOR = vec4(normal, 1.0);
	} else if (current_mode == 2) {
		float steepness = get_steepness(UV);
		COLOR = vec4(steepness, steepness, steepness, 1.0);
	} else if (current_mode == 3) {
		vec3 biome = get_biome(UV);
		COLOR = vec4(biome, 1.0);
	}
}