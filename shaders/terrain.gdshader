shader_type spatial;

//render_mode wireframe;
render_mode diffuse_burley, specular_schlick_ggx;

// TODO: make LODs circular?

//uniform sampler2D debug_lod_texture: hint_default_black;
//uniform vec2 debug_lod_grid_size = vec2(4.0, 4.0);

group_uniforms shading;
uniform float normal_depth: hint_range(0.0, 10.0) = 1.0;
uniform float triplanar_blend_sharpness : hint_range(0.001, 150.0) = 5.0;

group_uniforms grass;
uniform vec3 grass_albedo: source_color = vec3(1.0);
uniform sampler2D grass_texture_albedo : hint_default_white;
uniform sampler2D grass_normal : hint_normal;
uniform sampler2D grass_arm : hint_default_white;
uniform float grass_specular: hint_range(0, 1) = 0;
uniform vec3 grass_uv_scale = vec3(0.04);
uniform vec3 grass_uv_offset;

group_uniforms cliff;
uniform vec3 cliff_albedo: source_color = vec3(1.0);
uniform sampler2D cliff_texture_albedo : hint_default_white;
uniform sampler2D cliff_normal : hint_normal;
uniform sampler2D cliff_arm : hint_default_white;
uniform float cliff_specular: hint_range(0, 1) = 0;
uniform vec3 cliff_uv_scale = vec3(0.04);
uniform vec3 cliff_uv_offset;

group_uniforms sand;
uniform vec3 sand_albedo: source_color = vec3(1.0);
uniform sampler2D sand_texture_albedo : hint_default_white;
uniform sampler2D sand_normal : hint_normal;
uniform sampler2D sand_arm : hint_default_white;
uniform float sand_specular: hint_range(0, 1) = 0;
uniform vec3 sand_uv_scale = vec3(0.04);
uniform vec3 sand_uv_offset;

global uniform float partition_size;
global uniform int partition_lod_step;
global uniform int partition_lod_zero_radius;
global uniform vec3 terrain_position;

global uniform sampler2D height_map: hint_default_white, repeat_disable;
global uniform float height_map_amplitude;
global uniform sampler2D normal_map: hint_normal, repeat_disable;
global uniform sampler2D biome_map: hint_default_black, repeat_disable;

varying vec3 global_position;
varying vec3 triplanar_weights;

//varying vec3 vertex_normal;
//varying float debug_lod;

float true_round(float value){
	return ceil(value - 0.49999);
}

vec3 unpack_normal_map(vec3 rgb) {
	vec3 n = rgb.xzy * 2.0 - vec3(1.0);
	n.z *= -1.0;
	return n;
}

vec3 triplanarize(sampler2D sampler, vec3 weights, vec3 triplanar_pos) {
	vec3 sample = vec3(0.0);
	sample += texture(sampler, triplanar_pos.xy).rgb * weights.z;
	sample += texture(sampler, triplanar_pos.xz).rgb * weights.y;
	sample += texture(sampler, triplanar_pos.zy * vec2(-1.0, 1.0)).rgb * weights.x;
	return sample;
}

vec4 sample_centered(sampler2D sampler, vec3 position, float lod) {
	vec2 uv = (position.xz + vec2(0.5)) / vec2(textureSize(sampler,0));
	
	return textureLod(sampler, uv + vec2(0.5), lod);
}

float get_height(vec3 position){
	return sample_centered(height_map, position, 0.0).r * height_map_amplitude;
}

vec3 get_biome(vec3 position) {
	return sample_centered(biome_map, position, 0.0).rgb;
}

vec3 get_normal(vec3 position) {
	return sample_centered(normal_map, position, 0.0).rgb;
}

//vec3 get_debug_lod_albedo(vec3 position, int lod) {
	//switch (lod) {
		//case 0:
			//return vec3(0.6, 0.0, 0.0);
		//case 1:
			//return vec3(0.0, 0.6, 0.0);
		//case 2:
			//return vec3(0.0, 0.0, 0.6);
		//default:
			//return vec3(0.0);
	//}
	//float x = mod(lod, debug_lod_grid_size.x);
	//float y = floor(lod / debug_lod_grid_size.x);;
	//vec2 grid_tile_size = vec2(1.0) / debug_lod_grid_size;
	//vec2 grid_offset = vec2(x, y) * grid_tile_size;
	//vec2 position_offset = mod(position.xz / partition_size, vec2(1.0)) * grid_tile_size;
	//
	//return texture(debug_lod_texture, grid_offset + position_offset).rgb;
//}

void vertex() {
	global_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;

	vec3 terrain_vertex = global_position - terrain_position;
	
	float lod = true_round(max(abs(terrain_vertex.x), abs(terrain_vertex.z)) / partition_size) * float(partition_lod_step);
	lod = max(0.0, lod - float(partition_lod_zero_radius * partition_lod_step));
	
	float subdivision_size = min(pow(2, lod), partition_size);

	vec3 fraction = fract((VERTEX + partition_size / 2.0) / subdivision_size);

	VERTEX.y = mix(
		mix(
			get_height(global_position - vec3(fraction.x * subdivision_size, 0, 0)), 
			get_height(global_position + vec3((1.0-fraction.x) * subdivision_size, 0, 0)), 
			fraction.x
		), 
		mix(
			get_height(global_position - vec3(0, 0, fraction.z * subdivision_size)), 
			get_height(global_position + vec3(0, 0, (1.0-fraction.z) * subdivision_size)), 
			fraction.z
		), 
		ceil(fraction.z)
	);

	global_position.y = VERTEX.y;
	
	// vertex normals
	NORMAL = unpack_normal_map(get_normal(global_position));
	
	triplanar_weights = pow(abs(NORMAL), vec3(triplanar_blend_sharpness));
	triplanar_weights /= dot(triplanar_weights, vec3(1.0));
}

void fragment() {
	//discard;
	//vec3 triplanar_position = vec4(INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	//
	vec3 r_position = fma(global_position, grass_uv_scale, grass_uv_offset);
	vec3 g_position = fma(global_position, cliff_uv_scale, cliff_uv_offset);
	vec3 b_position = fma(global_position, sand_uv_scale, sand_uv_offset);

	vec3 biome = get_biome(global_position);
	
	// albedo
	//vec3 r_albedo = grass_albedo * triplanarize(grass_texture_albedo, triplanar_weights, r_position);
	//vec3 g_albedo = cliff_albedo * triplanarize(cliff_texture_albedo, triplanar_weights, g_position);
	//vec3 b_albedo = sand_albedo * triplanarize(sand_texture_albedo, triplanar_weights, b_position);
	vec3 r_albedo = grass_albedo * texture(grass_texture_albedo, r_position.xz).rgb;
	vec3 g_albedo = cliff_albedo * triplanarize(cliff_texture_albedo, triplanar_weights, g_position);
	vec3 b_albedo = sand_albedo * texture(sand_texture_albedo, b_position.xz).rgb;
	
	ALBEDO = r_albedo * biome.r + g_albedo * biome.g + b_albedo * biome.b;

	// ARM: ambient occlusion, roughness, metallic
	//vec3 r_arm = triplanarize(grass_arm, triplanar_weights, r_position);
	//vec3 g_arm = triplanarize(cliff_arm, triplanar_weights, g_position);
	//vec3 b_arm = triplanarize(sand_arm, triplanar_weights, b_position);
	vec3 r_arm = texture(grass_arm, r_position.xz).rgb;
	vec3 g_arm = triplanarize(cliff_arm, triplanar_weights, g_position);
	vec3 b_arm = texture(sand_arm, b_position.xz).rgb;
	
	AO = r_arm[0] * biome.r + g_arm[0] * biome.g + b_arm[0] * biome.b;
	ROUGHNESS = r_arm[1] * biome.r + g_arm[1] * biome.g + b_arm[1] * biome.b;
	METALLIC = r_arm[2] * biome.r + g_arm[2] * biome.g + b_arm[2] * biome.b;

	// normal mapping
	//vec3 r_normal = triplanarize(grass_normal, triplanar_weights, r_position);
	//vec3 g_normal = triplanarize(cliff_normal, triplanar_weights, g_position);
	//vec3 b_normal = triplanarize(sand_normal, triplanar_weights, b_position);
	vec3 r_normal = texture(grass_normal, r_position.xz).rgb;
	vec3 g_normal = triplanarize(cliff_normal, triplanar_weights, g_position);
	vec3 b_normal = texture(sand_normal, b_position.xz).rgb;
	
	vec3 base_unpacked = fma(get_normal(global_position), vec3(2.0), vec3(-1.0));
	vec3 r_unpacked = fma(r_normal, vec3(2.0), vec3(-1.0)) * biome.r;
	vec3 g_unpacked = fma(g_normal, vec3(2.0), vec3(-1.0)) * biome.g;
	vec3 b_unpacked = fma(b_normal, vec3(2.0), vec3(-1.0)) * biome.b;
	
	NORMAL_MAP = fma(base_unpacked + r_unpacked + g_unpacked + b_unpacked, vec3(0.5), vec3(0.5));
	//NORMAL_MAP = (base_unpacked) * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = normal_depth;
	
	// specular
	SPECULAR = grass_specular * biome.r + cliff_specular * biome.g + sand_specular * biome.b;
}