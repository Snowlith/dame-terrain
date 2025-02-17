shader_type particles;

group_uniforms instancing;
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

group_uniforms steepness_definition;
uniform float max_spawn_steepness : hint_range(0, 1.0) = 0.85;

group_uniforms externally_assigned;
uniform sampler2D height_map: hint_default_white;
uniform vec2 height_map_offset = vec2(0.5);
uniform sampler2D steepness_map: hint_default_white;
uniform vec2 steepness_map_offset = vec2(0.5);
uniform sampler2D normal_map: hint_normal;
uniform vec2 normal_map_offset = vec2(0.5);
uniform sampler2D density_map;
uniform vec2 density_map_offset = vec2(0.5);
uniform float amplitude = 50.0;

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

float get_height(vec3 world_vertex){
	vec2 texture_position = (world_vertex.xz + vec2(0.5))/float(textureSize(height_map,0).x);

	// Bounds
	if (abs(texture_position.x) > 0.5 || abs(texture_position.y) > 0.5) {
		return 0.0;
	}

	float height_value = texture(height_map, texture_position + height_map_offset).r;
	return height_value * amplitude;
}

float get_density(vec3 world_vertex){
	vec2 texture_position = (world_vertex.xz + vec2(0.5))/float(textureSize(density_map,0).x);

	// Bounds
	if (abs(texture_position.x) > 0.5 || abs(texture_position.y) > 0.5) {
		return 0.0;
	}

	return texture(density_map, texture_position + density_map_offset).r;
}

vec3 get_normal(vec3 world_vertex){
	vec2 texture_position = (world_vertex.xz + vec2(0.5))/float(textureSize(normal_map,0).x);

	// Bounds
	if (abs(texture_position.x) > 0.5 || abs(texture_position.y) > 0.5) {
		return vec3(0, 0, 1);
	}

	return unpack_normal(texture(normal_map, texture_position + normal_map_offset).rgb);
}

float get_steepness(vec3 world_vertex){
	vec2 texture_position = (world_vertex.xz + vec2(0.5))/float(textureSize(height_map,0).x);

	// Bounds
	if (abs(texture_position.x) > 0.5 || abs(texture_position.y) > 0.5) {
		return 0.0;
	}
	
	float steepness_value = texture(steepness_map, texture_position + steepness_map_offset).r;
	return steepness_value;
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
	
	// map world space to heightmap space
	float pixel_size = 1.0 / float(textureSize(height_map, 0).x);
	vec2 half_pixel_offset = vec2(pixel_size, pixel_size) / 2.0;
	float heightmap_size = float(textureSize(height_map, 0).x);
	//vec2 world_map_uv = pos.xz * (1.0 / (heightmap_scale * heightmap_size)) + vec2(0.5) + half_pixel_offset;
	
	// set the height according to the heightmap data
	pos.y = get_height(pos);
	
	// hash the density using the density texture
	
	float steepness = get_steepness(pos);
	float density = get_density(pos);
	if (steepness > max_spawn_steepness || density * density_adjust > r.x) {
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