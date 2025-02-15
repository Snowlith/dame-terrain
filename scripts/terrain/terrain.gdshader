shader_type spatial;

//render_mode wireframe;
render_mode diffuse_lambert, specular_toon;

group_uniforms settings;
uniform float amplitude = 50.0;
uniform float partition_size = 16.0;
uniform float partition_lod_step = 1.0;
uniform int partition_lod_zero_radius = 1;
uniform float normal_sampling_distance = 4.0;
uniform float normal_sampling_lod = 1.0;
uniform float steepness_sampling_lod = 2.0;

group_uniforms steepness_definition;
uniform float max_flat_steepness : hint_range(0, 1.0) = 0.85;
uniform float steepness_smoothing : hint_range(0, 1.0) = 0.1;
uniform sampler2D steepness_edge_noise;
uniform float steepness_edge_noise_intensity : hint_range(0.0, 1.0);

group_uniforms textures;
uniform sampler2D grass_albedo : hint_default_white;
uniform float grass_uv_scale = 1.0;
uniform sampler2D cliff_albedo : hint_default_white;
uniform float cliff_uv_scale = 1.0;

group_uniforms material_properties;
uniform float grass_specular : hint_range(0.0, 1.0);
uniform float grass_roughness : hint_range(0.0, 1.0);
uniform float grass_metallic : hint_range(0.0, 1.0);
uniform float cliff_specular : hint_range(0.0, 1.0);
uniform float cliff_roughness : hint_range(0.0, 1.0);
uniform float cliff_metallic : hint_range(0.0, 1.0);

group_uniforms externally_assigned;
uniform vec3 terrain_position;
uniform sampler2D height_map: hint_default_white;
uniform vec2 height_map_offset = vec2(0.5);
uniform sampler2D steepness_map: hint_default_white;
uniform vec2 steepness_map_offset = vec2(0.5);

varying vec2 world_position;

varying vec3 vert;

float true_round(float value){
	return floor(value + 0.5);
}

vec3 get_triplanarized_map(sampler2D sampler, vec4 projected_coords, vec3 normal_weights, float uv_scale) {
	vec3 texX = texture(sampler, projected_coords.zy * uv_scale).rgb;
	vec3 texY = texture(sampler, projected_coords.xz * uv_scale).rgb;
	vec3 texZ = texture(sampler, projected_coords.xy * uv_scale).rgb;
	return texX * normal_weights.x + texY * normal_weights.y + texZ * normal_weights.z;
}

float get_height(vec3 world_vertex){
	vec2 texture_position = (world_vertex.xz + vec2(0.5))/float(textureSize(height_map,0).x);

	// Bounds
	if (abs(texture_position.x) > 0.5 || abs(texture_position.y) > 0.5) {
		return 0.0;
	}

	float height_value = texture(height_map, texture_position + height_map_offset).r;
	return height_value * amplitude;
}

float get_height_lod(vec3 world_vertex){
	vec2 texture_position = (world_vertex.xz + vec2(0.5))/float(textureSize(height_map,0).x);

	// Bounds
	if (abs(texture_position.x) > 0.5 || abs(texture_position.y) > 0.5) {
		return 0.0;
	}

	float height_value = textureLod(height_map, texture_position + height_map_offset, normal_sampling_lod).r;
	return height_value * amplitude;
}

float get_steepness(vec3 world_vertex){
	vec2 texture_position = (world_vertex.xz + vec2(0.5))/float(textureSize(height_map,0).x);

	// Bounds
	if (abs(texture_position.x) > 0.5 || abs(texture_position.y) > 0.5) {
		return 0.0;
	}
	
	float steepness_value = textureLod(steepness_map, texture_position + steepness_map_offset, steepness_sampling_lod).r;
	float edge_noise_value = mix(1.0, texture(steepness_edge_noise, texture_position).r, steepness_edge_noise_intensity);
	return steepness_value * edge_noise_value;
}

//vec3 get_normal(vec3 vertex, float adjacent_distance){
	//vec3 west_vert = vertex + vec3(adjacent_distance, 0, 0);
	//west_vert.y = get_height(west_vert);
	//vec3 north_vert = vertex + vec3(0, 0, adjacent_distance);
	//north_vert.y = get_height(north_vert);
	//return normalize(cross(north_vert - vertex, west_vert - vertex));
//}

vec3 calculate_normal(vec3 vertex, float adjacent_distance) {
    //vec2 texelSize = 1.0 / vec2(textureSize(noise_map, 0));
	float left = get_height_lod(vertex + vec3(-adjacent_distance, 0, 0));
	float right = get_height_lod(vertex + vec3(adjacent_distance, 0, 0));
	float up = get_height_lod(vertex + vec3(0, 0, -adjacent_distance));
	float down = get_height_lod(vertex + vec3(0, 0, adjacent_distance));

	return normalize(vec3(left - right, 2.0 * adjacent_distance, up - down));
}

vec3 to_normal_map(vec3 n){
	n *= vec3(1.0, 1.0, -1.0);
	n = n / 2.0 + 0.5;
	n = vec3(n.x, n.z, n.y);
	return n;
}

void fragment() {
	// Normal calculations
	vec3 interpolated_vert = vert;
	interpolated_vert.y = get_height(vert);
	vec3 normal = calculate_normal(interpolated_vert, normal_sampling_distance);
	NORMAL_MAP = to_normal_map(normal);

	// Albedo calculations
	vec4 projected_coords = INV_VIEW_MATRIX * vec4(VERTEX, 1.0);
	vec3 world_normal = abs(INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
	vec3 normal_weights = abs(world_normal) / (abs(world_normal.x) + abs(world_normal.y) + abs(world_normal.z));

	vec3 triplanarized_grass_albedo = get_triplanarized_map(grass_albedo, projected_coords, normal_weights, grass_uv_scale * 0.01);
	vec3 triplanarized_cliff_albedo = get_triplanarized_map(cliff_albedo, projected_coords, normal_weights, cliff_uv_scale * 0.01);
	
	float steepness = get_steepness(vert);
	float steepness_mask = smoothstep(max_flat_steepness - steepness_smoothing, max_flat_steepness, steepness);

	ALBEDO = mix(triplanarized_grass_albedo, triplanarized_cliff_albedo, steepness_mask);

	SPECULAR = mix(grass_specular, cliff_specular, steepness);
	METALLIC = mix(grass_metallic, cliff_metallic, steepness);
	ROUGHNESS = mix(grass_roughness, cliff_roughness, steepness);
}

void vertex(){
	vec3 world_vertex = VERTEX + MODEL_MATRIX[3].xyz;

	vec3 terrain_vertex = world_vertex - terrain_position;
	
	vec2 partition_distance = vec2(
		abs(true_round((terrain_vertex.x - terrain_position.x) / partition_size)),
		abs(true_round((terrain_vertex.z - terrain_position.z) / partition_size))
	);
	float lod = true_round(max(abs(terrain_vertex.x), abs(terrain_vertex.z))/partition_size) * partition_lod_step;
	lod = max(0.0, lod - float(partition_lod_zero_radius));
	
	float subdivision_size = min(pow(2, lod), partition_size);

	vec3 fraction = fract((VERTEX + partition_size / 2.0) / subdivision_size);

	VERTEX.y = mix(
		mix(
			get_height(world_vertex - vec3(fraction.x * subdivision_size, 0, 0)),
			get_height(world_vertex + vec3((1.0-fraction.x) * subdivision_size, 0, 0)),
			fraction.x
		),
		mix(
			get_height(world_vertex - vec3(0, 0, fraction.z * subdivision_size)),
			get_height(world_vertex + vec3(0, 0, (1.0-fraction.z) * subdivision_size)),
			fraction.z
		),
		ceil(fraction.z)
	);
	if (fraction.z == 0.5){
		VERTEX.y = mix(
			get_height(world_vertex - vec3(0, 0, fraction.z * subdivision_size)),
			get_height(world_vertex + vec3(0, 0, (1.0-fraction.z) * subdivision_size)),
			fraction.z
		);
	}
	vert = world_vertex;
}
