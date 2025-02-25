shader_type spatial;

//render_mode wireframe;
render_mode diffuse_toon, specular_schlick_ggx;

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
uniform float partition_size = 16.0;
uniform int partition_lod_step = 1;
uniform int partition_lod_zero_radius = 1;
uniform vec3 terrain_position;

uniform sampler2D height_map: hint_default_white;
uniform vec2 height_map_offset = vec2(0.5);
uniform sampler2D normal_map: hint_normal;
uniform vec2 normal_map_offset = vec2(0.5);
uniform sampler2D biome_map: hint_default_black;
uniform vec2 biome_map_offset = vec2(0.5);

varying vec3 world_vertex;

float true_round(float value){
	return floor(value + 0.5);
}

vec3 triplanarize(sampler2D sampler, vec4 projected_coords, vec3 normal_weights, float uv_scale) {
	vec3 x = texture(sampler, projected_coords.zy * uv_scale).rgb;
	vec3 y = texture(sampler, projected_coords.xz * uv_scale).rgb;
	vec3 z = texture(sampler, projected_coords.xy * uv_scale).rgb;
	return x * normal_weights.x + y * normal_weights.y + z * normal_weights.z;
}

vec4 sample_bounded(sampler2D sampler, vec3 world_pos, vec2 uv_offset, vec4 default_argument) {
	vec2 uv = (world_pos.xz + vec2(0.5)) / float(textureSize(sampler,0).x);

	if (abs(uv.x) > 0.5 || abs(uv.y) > 0.5) {
		return default_argument;
	}
	
	return texture(sampler, uv + uv_offset);
}

float get_height(vec3 world_pos){
	return sample_bounded(height_map, world_pos, height_map_offset, vec4(0.0)).r * amplitude;
}

vec3 get_biome(vec3 world_pos) {
	return sample_bounded(biome_map, world_pos, biome_map_offset, vec4(0.0, 0.0, 1.0, 0.0)).rgb;
}

vec3 get_normal(vec3 world_pos) {
	return sample_bounded(normal_map, world_pos, normal_map_offset, vec4(0.5, 0.5, 1.0, 0.0)).rgb;
}

void vertex(){
	world_vertex = VERTEX + MODEL_MATRIX[3].xyz;

	vec3 terrain_vertex = world_vertex - terrain_position;
	
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

	world_vertex.y = VERTEX.y;
}

void fragment() {
	//discard;
	vec4 projected_coords = INV_VIEW_MATRIX * vec4(VERTEX, 1.0);
	vec3 world_normal = abs(INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
	vec3 normal_weights = abs(world_normal) / (abs(world_normal.x) + abs(world_normal.y) + abs(world_normal.z));
	
	vec3 biome = get_biome(world_vertex);
	
	// albedo
	vec3 r_albedo = triplanarize(grass_albedo, projected_coords, normal_weights, grass_uv_scale * 0.01);
	vec3 g_albedo = triplanarize(cliff_albedo, projected_coords, normal_weights, cliff_uv_scale * 0.01);
	vec3 b_albedo = triplanarize(sand_albedo, projected_coords, normal_weights, sand_uv_scale * 0.01);
	
	ALBEDO = r_albedo * biome.r + g_albedo * biome.g + b_albedo * biome.b;

	// ARM: ambient occlusion, roughness, metallic
	vec3 r_arm = triplanarize(grass_arm, projected_coords, normal_weights, grass_uv_scale * 0.01);
	vec3 g_arm = triplanarize(cliff_arm, projected_coords, normal_weights, cliff_uv_scale * 0.01);
	vec3 b_arm = triplanarize(sand_arm, projected_coords, normal_weights, sand_uv_scale * 0.01);
	
	AO = r_arm[0] * biome.r + g_arm[0] * biome.g + b_arm[0] * biome.b;
	ROUGHNESS = r_arm[1] * biome.r + g_arm[1] * biome.g + b_arm[1] * biome.b;
	METALLIC = r_arm[2] * biome.r + g_arm[2] * biome.g + b_arm[2] * biome.b;
	
	// normal mapping
	vec3 r_normal = triplanarize(grass_normal, projected_coords, normal_weights, grass_uv_scale * 0.01);
	vec3 g_normal = triplanarize(cliff_normal, projected_coords, normal_weights, cliff_uv_scale * 0.01);
	vec3 b_normal = triplanarize(sand_normal, projected_coords, normal_weights, sand_uv_scale * 0.01);
	
	vec3 base_unpacked = get_normal(world_vertex) * 2.0 - 1.0;
	
	vec3 r_unpacked = (r_normal * 2.0 - 1.0) * biome.r;
	vec3 g_unpacked = (g_normal * 2.0 - 1.0) * biome.g;
	vec3 b_unpacked = (b_normal * 2.0 - 1.0) * biome.b;
	
	NORMAL_MAP = (base_unpacked + r_unpacked + g_unpacked + b_unpacked) * 0.5 + 0.5;
	
	// specular
	SPECULAR = grass_specular * biome.r + cliff_specular * biome.g + sand_specular * biome.b;
}