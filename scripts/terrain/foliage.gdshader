shader_type particles;

group_uniforms instancing;
uniform vec3 preferred_biome: source_color;
uniform float biome_threshold: hint_range(0.0, 1.0);
uniform int instance_rows;
uniform float instance_spacing;
uniform float density_adjust;
uniform bool orient_to_normal = true;
uniform bool orient_up_with_normal = true;

group_uniforms randomization;
//uniform float random_rotation;
uniform float random_spacing;
uniform vec3 min_scale = vec3(1.0);
uniform vec3 max_scale = vec3(1.0);

group_uniforms externally_assigned;
uniform sampler2D height_map: hint_default_white;
uniform vec2 height_map_offset = vec2(0.5);
uniform sampler2D normal_map: hint_normal;
uniform vec2 normal_map_offset = vec2(0.5);
uniform sampler2D biome_map: hint_default_black;
uniform vec2 biome_map_offset = vec2(0.5);
uniform sampler2D density_map;
uniform vec2 density_map_offset = vec2(0.5);
uniform float amplitude = 1.0;

render_mode disable_velocity, disable_force;

vec3 unpack_normal(vec3 rgb) {
	vec3 n = rgb.xzy * 2.0 - vec3(1.0);
	n.z *= -1.0;
	return normalize(n);
}

float random (vec2 uv) {
    float rf = fract(sin(dot(uv.xy,
        vec2(12.9898,78.233))) * 43758.5453123);
	
	return rf;
}

mat4 rotate_y(float theta) {
    return mat4(vec4(cos(theta), 0, -sin(theta), 0), vec4(0, 1, 0, 0), vec4(sin(theta), 0, cos(theta), 0), vec4(0, 0, 0, 1));
}

vec4 sample_bounded(sampler2D sampler, vec3 world_vertex, vec2 uv_offset, vec4 default_argument) {
	vec2 uv = (world_vertex.xz + vec2(0.5)) / float(textureSize(sampler,0).x);

	if (abs(uv.x) > 0.5 || abs(uv.y) > 0.5) {
		return default_argument;
	}
	
	return texture(sampler, uv + uv_offset);
}

float get_height(vec3 world_vertex){
	return sample_bounded(height_map, world_vertex, height_map_offset, vec4(0.0)).r * amplitude;
}

vec3 get_biome(vec3 world_vertex) {
	return sample_bounded(biome_map, world_vertex, biome_map_offset, vec4(0.0, 0.0, 1.0, 0.0)).rgb;
}

vec3 get_normal(vec3 world_vertex) {
	return sample_bounded(normal_map, world_vertex, normal_map_offset, vec4(0.5, 0.5, 1.0, 0.0)).rgb;
}

float get_density(vec3 world_vertex) {
	return sample_bounded(density_map, world_vertex, density_map_offset, vec4(0.0)).r;
}

void start() {
	//create a grid
	vec3 pos = vec3(0.0, 0.0, 0.0);
	pos.z = float(INDEX);
	pos.x = mod(pos.z, float(instance_rows));
	pos.z = (pos.z - pos.x) / float(instance_rows);
	
	// center the grid on the emitter
	pos.x -= float(instance_rows) * 0.5;
	pos.z -= float(instance_rows) * 0.5;
	
	// widen the grid
	pos *= instance_spacing;
	
	// make the grid space local to the emitter space
	pos.x += EMISSION_TRANSFORM[3][0] - mod(EMISSION_TRANSFORM[3][0], instance_spacing);
	pos.z += EMISSION_TRANSFORM[3][2] - mod(EMISSION_TRANSFORM[3][2], instance_spacing);
	
	//create a random value per-instance
	vec3 r = vec3(random(pos.xz), random(pos.xz + vec2(0.5)), random(pos.xz - vec2(0.5)));
	
	//add some randomness to the instance spacing
	pos.x += ((r.x * 2.0) - 1.0) * random_spacing;
	pos.z += ((r.y * 2.0) - 1.0) * random_spacing;
	
	// set the height according to the heightmap data
	pos.y = get_height(pos);
	
	// hash the density using the density texture
	
	vec3 biome = get_biome(pos);
	float density = get_density(pos);
	if (max(0, dot(biome, preferred_biome)) < biome_threshold || density * density_adjust > r.x) {
		pos.y = -10000.0;
	}
	
	// set the base transform (no rotation, facing up)
	TRANSFORM[0].xyz = vec3(1.0, 0.0, 0.0);
	TRANSFORM[1].xyz = vec3(0.0, 1.0, 0.0);
	TRANSFORM[2].xyz = vec3(0.0, 0.0, 1.0);
	
	// figure a random rotation around the global y axis
	vec3 rotation_x = vec3(1.0);
	vec3 rotation_z = vec3(1.0);
	rotation_x.x = cos(r.x * TAU);
	rotation_x.z = -sin(r.x * TAU);
	rotation_z.x = sin(r.x * TAU);
	rotation_z.z = cos(r.x * TAU);
	
	// figure out the terrain normal on the spot
	vec3 normal_dir = get_normal(pos);
	vec3 normal_align_y = normalize(normal_dir);
	vec3 normal_align_z = normalize(cross(normal_align_y, vec3(0.0, 1.0, 0.0)));
	vec3 normal_align_x = normalize(cross(normal_dir, normal_align_z));
	
	mat3 normal_align_matrix = mat3(normal_align_x, normal_align_y, normal_align_z);
	
	if (orient_to_normal) {
		TRANSFORM[0].xyz = normal_align_matrix[0];
		TRANSFORM[1].xyz = normal_align_matrix[1];
		TRANSFORM[2].xyz = normal_align_matrix[2];
		
		if (orient_up_with_normal) {
			TRANSFORM[1].xyz = vec3(0.0, 1.0, 0.0);
		}
	}
	else {
		TRANSFORM[0].x = rotation_x.x;
		TRANSFORM[0].z = rotation_x.z;
		TRANSFORM[2].x = rotation_z.x;
		TRANSFORM[2].z = rotation_z.z;
	}
	
	// calculate and apply the scale after rotating
	vec3 scale = vec3(mix(min_scale.x, max_scale.x, r.x), mix(min_scale.y, max_scale.y, r.y), mix(min_scale.z, max_scale.z, r.z));
	
	TRANSFORM[0] *= scale.x;
	TRANSFORM[1] *= scale.y;
	TRANSFORM[2] *= scale.z;
	
	// apply the position
	TRANSFORM[3].xyz = pos.xyz;
}