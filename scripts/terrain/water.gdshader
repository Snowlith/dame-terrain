shader_type spatial;
render_mode specular_schlick_ggx;

const float SMOOTHSTEP_AA = 0.01;

uniform sampler2D depth_texture : hint_depth_texture, filter_linear_mipmap;
uniform sampler2D screen_texture : hint_screen_texture, source_color, repeat_disable;

group_uniforms waves;
uniform float base_height = 10.0;
uniform float wave_amplitude: hint_range(0.0, 100.0) = 2.0;
uniform vec2 wave_velocity = vec2(1.0, 0.0);
uniform sampler2D wave_height_map: hint_default_white;
uniform sampler2D wave_normal_map: hint_normal;

group_uniforms foam;
uniform sampler2D foam_albedo: hint_default_white;
uniform vec2 foam_tiling = vec2(0.1, 0.1);
uniform vec2 foam_velocity = vec2(0.03, 0.03);

uniform sampler2D foam_distortion: hint_default_white;
uniform vec2 foam_distortion_tiling = vec2(0.1, 0.1);
uniform vec2 foam_distortion_velocity = vec2(-0.003, 0.003);
uniform float foam_distortion_strength: hint_range(0.0, 10.0);

group_uniforms edge_foam;
uniform float foam_max_distance = 0.4;
uniform float foam_min_distance = 0.04;
uniform vec4 foam_color: source_color  = vec4(1.0);

uniform float beer_factor = 0.8;

uniform float surface_noise_cutoff: hint_range(0, 1) = 0.777;

uniform vec4 shallow_color: source_color = vec4(0.325, 0.807, 0.971, 0.725);
uniform vec4 deep_color: source_color = vec4(0.086, 0.407, 1, 0.749);
uniform float depth_threshold: hint_range(0, 1) = 1.0;
uniform float depth_bias = 1.0;

varying vec3 view_normal;


// Water Noise
//
//uniform sampler2D foam_albedo: hint_default_white;


group_uniforms externally_assigned;
uniform float amplitude = 1.0;
uniform float partition_size = 16.0;
uniform int partition_lod_step = 1;
uniform int partition_lod_zero_radius = 1;
uniform vec3 terrain_position;

// Varying variables
varying vec3 world_vertex;

//varying vec2 wave_offset;


vec4 alphaBlend(vec4 top, vec4 bottom) {
	vec3 color = (top.rgb * top.a) + (bottom.rgb * (1.0 - top.a));
	float alpha = top.a + bottom.a * (1.0 - top.a);
	
	return vec4(color, alpha);
}

//float snells_window(vec3 normal, vec3 view, float ior) {
	//float cos_theta = dot(normal, view);
	//return step(sqrt(1.0 - cos_theta * cos_theta) * ior, 1.0);
//}


float get_height(vec3 world_position){
	vec2 uv = (world_position.xz + vec2(0.5)) / float(textureSize(wave_height_map,0).x);
	return base_height + texture(wave_height_map, uv + wave_velocity * TIME).r * wave_amplitude;
}

vec3 get_normal(vec3 world_position){
	vec2 uv = (world_position.xz + vec2(0.5)) / float(textureSize(wave_height_map,0).x);
	return texture(wave_normal_map, uv).rgb;
}

float true_round(float value){
	return floor(value + 0.5);
}

void vertex() {
	//wave_offset = wave_direction * TIME;
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
	
	view_normal = (MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
}

void fragment() {
	discard;
	float depth_value = texture(depth_texture, SCREEN_UV).r;
	float depth = PROJECTION_MATRIX[3][2] / (depth_value + PROJECTION_MATRIX[2][2]);
	depth = depth + VERTEX.z;
	depth = exp(-depth * beer_factor);
	depth = 1.0 - depth;
	
    vec4 view_pos = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth_value, 1.0);
    view_pos /= view_pos.w;
    vec3 existing_normal = normalize(cross( dFdx(view_pos.xyz), dFdy(view_pos.xyz)));

	float normalDot = clamp(dot(existing_normal, view_normal), 0.0, 1.0);
	float foamDistance = mix(foam_min_distance, foam_max_distance, normalDot);
	
	float foamDepth = clamp(depth / foamDistance, 0.0, 1.0);
	float surfaceNoiseCutoff = foamDepth * surface_noise_cutoff;
	
	vec2 foam_distortion_offset = vec2(TIME * foam_distortion_velocity);
	vec2 foam_distortion_sample = texture(foam_distortion, world_vertex.xz / foam_distortion_tiling + foam_distortion_offset).xy;
	vec2 foam_distortion_scaled = (foam_distortion_sample * 2.0 - 1.0) * foam_distortion_strength;
	
	vec2 foam_offset = vec2(TIME * foam_velocity + foam_distortion_scaled);
	float surfaceNoiseSample = texture(foam_albedo, world_vertex.xz / foam_tiling + foam_offset).r;
	float surfaceNoiseAmount = smoothstep(surfaceNoiseCutoff - SMOOTHSTEP_AA, surfaceNoiseCutoff + SMOOTHSTEP_AA, surfaceNoiseSample);
	
	float waterDepth = clamp(depth / depth_threshold, 0.0, 1.0) * depth_bias;
	vec4 waterColor = mix(shallow_color, deep_color, waterDepth);

	vec4 surfaceNoiseColor = foam_color;
    surfaceNoiseColor.a *= surfaceNoiseAmount;
	vec4 color = alphaBlend(surfaceNoiseColor, waterColor);
	
    ALBEDO = color.rgb;
	ALPHA = color.a;
	
	
}