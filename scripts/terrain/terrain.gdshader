shader_type spatial;

//render_mode wireframe;
//render_mode diffuse_lambert, specular_toon;

group_uniforms settings;
uniform float partition_size = 16.0;
uniform int partition_lod_step = 1;
uniform int partition_lod_zero_radius = 1;
uniform float normal_sampling_lod = 1.0;

group_uniforms textures;
uniform sampler2D grass_albedo : hint_default_white;
uniform sampler2D grass_normal : hint_normal;
uniform sampler2D grass_arm : hint_default_white;
uniform float grass_specular: hint_range(0, 1) = 0;
uniform float grass_uv_scale = 1.0;

uniform sampler2D cliff_albedo : hint_default_white;
uniform sampler2D cliff_normal : hint_normal;
uniform sampler2D cliff_arm : hint_default_white;
uniform float cliff_specular: hint_range(0, 1) = 0;
uniform float cliff_uv_scale = 1.0;

uniform sampler2D sand_albedo : hint_default_white;
uniform sampler2D sand_normal : hint_normal;
uniform sampler2D sand_arm : hint_default_white;
uniform float sand_specular: hint_range(0, 1) = 0;
uniform float sand_uv_scale = 1.0;

group_uniforms externally_assigned;
uniform float amplitude = 1.0;
uniform vec3 terrain_position;

uniform sampler2D height_map: hint_default_white;
uniform vec2 height_map_offset = vec2(0.5);

uniform sampler2D normal_map: hint_normal;
uniform vec2 normal_map_offset = vec2(0.5);

uniform sampler2D biome_map: hint_default_black;
uniform vec2 biome_map_offset = vec2(0.5);

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

vec3 get_biome(vec3 world_vertex){
	vec2 texture_position = (world_vertex.xz + vec2(0.5))/float(textureSize(biome_map,0).x);

	// if out of bounds, use sand
	if (abs(texture_position.x) > 0.5 || abs(texture_position.y) > 0.5) {
		return vec3(0, 0, 1);
	}
	
	return texture(biome_map, texture_position + biome_map_offset).rgb;
}

vec3 get_normal(vec3 world_vertex){
	vec2 texture_position = (world_vertex.xz + vec2(0.5))/float(textureSize(normal_map,0).x);

	// if out of bounds, use sand
	if (abs(texture_position.x) > 0.5 || abs(texture_position.y) > 0.5) {
		return vec3(0, 0, 1);
	}
	
	return texture(normal_map, texture_position + normal_map_offset).rgb;
}

vec3 get_normal_lod(vec3 world_vertex){
	vec2 texture_position = (world_vertex.xz + vec2(0.5))/float(textureSize(normal_map,0).x);

	// if out of bounds, use sand
	if (abs(texture_position.x) > 0.5 || abs(texture_position.y) > 0.5) {
		return vec3(0, 0, 1);
	}
	
	return textureLod(normal_map, texture_position + normal_map_offset, normal_sampling_lod).rgb;
}

vec3 to_normal_map(vec3 n){
	n *= vec3(1.0, 1.0, -1.0);
	n = n / 2.0 + 0.5;
	n = vec3(n.x, n.z, n.y);
	return n;
}

vec3 unpack_normal_map(vec3 rgb) {
	vec3 n = rgb.xzy * 2.0 - vec3(1.0);
	n.z *= -1.0;
	return n;
}

// reoriented normal mapping
vec3 rnm_blend(vec3 base_normal, vec3 detail_normal){
	base_normal = base_normal * 2.0 + vec3(-1, -1, 0);
	detail_normal = detail_normal * vec3(-2, -2, 2) - vec3(1, 1, -1);
	vec3 r = base_normal * dot(base_normal, detail_normal) / base_normal.z - detail_normal;
	return normalize(r) * 0.5 + 0.5;
}


void vertex(){
	vec3 world_vertex = VERTEX + MODEL_MATRIX[3].xyz;

	vec3 terrain_vertex = world_vertex - terrain_position;
	
	vec2 partition_distance = vec2(
		abs(true_round((terrain_vertex.x - terrain_position.x) / partition_size)),
		abs(true_round((terrain_vertex.z - terrain_position.z) / partition_size))
	);
	
	float lod = true_round(max(abs(terrain_vertex.x), abs(terrain_vertex.z))/partition_size) * float(partition_lod_step);
	lod = max(0.0, lod - float(partition_lod_zero_radius * partition_lod_step));
	
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
	world_vertex.y = VERTEX.y;
	vert = world_vertex;
	//NORMAL = calculate_normal(vert, normal_sampling_distance);
}

void fragment() {
	// Normal calculations
	vec3 interpolated_vert = vert;
	interpolated_vert.y = get_height(vert);

	// Albedo calculations
	vec4 projected_coords = INV_VIEW_MATRIX * vec4(VERTEX, 1.0);
	vec3 world_normal = abs(INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
	vec3 normal_weights = abs(world_normal) / (abs(world_normal.x) + abs(world_normal.y) + abs(world_normal.z));
	
	vec3 biome = get_biome(vert);

	vec3 tp_grass_albedo = get_triplanarized_map(grass_albedo, projected_coords, normal_weights, grass_uv_scale * 0.01);
	vec3 tp_grass_normal = get_triplanarized_map(grass_normal, projected_coords, normal_weights, grass_uv_scale * 0.01);
	vec3 tp_grass_arm = get_triplanarized_map(grass_arm, projected_coords, normal_weights, grass_uv_scale * 0.01);
		
	vec3 tp_cliff_albedo = get_triplanarized_map(cliff_albedo, projected_coords, normal_weights, cliff_uv_scale * 0.01);
	vec3 tp_cliff_normal = get_triplanarized_map(cliff_normal, projected_coords, normal_weights, cliff_uv_scale * 0.01);
	vec3 tp_cliff_arm = get_triplanarized_map(cliff_arm, projected_coords, normal_weights, cliff_uv_scale * 0.01);
	
	vec3 tp_sand_albedo = get_triplanarized_map(sand_albedo, projected_coords, normal_weights, sand_uv_scale * 0.01);
	vec3 tp_sand_normal = get_triplanarized_map(sand_normal, projected_coords, normal_weights, sand_uv_scale * 0.01);
	vec3 tp_sand_arm = get_triplanarized_map(sand_arm, projected_coords, normal_weights, sand_uv_scale * 0.01);
	
	ALBEDO = tp_grass_albedo * biome.r + tp_cliff_albedo * biome.g + tp_sand_albedo * biome.b;
	
	vec3 base_normal = get_normal_lod(vert);
	
	// THIS IS NOT CORRECT; THIS CAN BE ABOVE 1
	vec3 detail_normal = tp_grass_normal * biome.r + tp_cliff_normal * biome.g + tp_sand_normal * biome.b;
	
	//vec3 base_normal = get_normal_lod(vert);
	//ALBEDO = normal_2;
	//NORMAL_MAP = base_normal;
	NORMAL_MAP = mix(base_normal, detail_normal, 0.5);
	//NORMAL_MAP = detail_normal;
	
	AO = tp_grass_arm.r * biome.r + tp_cliff_arm.r * biome.g + tp_sand_arm.r * biome.b;
	ROUGHNESS = tp_grass_arm.g * biome.r + tp_cliff_arm.g * biome.g + tp_sand_arm.g * biome.b;
	METALLIC = tp_grass_arm.b * biome.r + tp_cliff_arm.b * biome.g + tp_sand_arm.b * biome.b;
	
	SPECULAR = grass_specular * biome.r + cliff_specular * biome.g + sand_specular * biome.b;
}