shader_type spatial;
render_mode shadows_disabled, cull_disabled, depth_draw_always;

//#define SSR
#define DISTANCE_FADE
#define SNELL

group_uniforms color;
uniform vec3 absorption_albedo : source_color = vec3(1.0, 0.35, 0.0);

uniform vec3 fresnel_albedo : source_color = vec3(0.0, 0.57, 0.72);
uniform float fresnel_radius : hint_range(0.0, 6.0, 0.01) = 2.0;

uniform float base_roughness : hint_range(0.0, 1.0, 0.01) = 0.15;
uniform float base_specular : hint_range(0.0, 1.0, 0.01) = 0.25;

uniform float depth_distance : hint_range(0.0, 50.0, 0.1) = 25.0;
uniform float beers_law : hint_range(0.0, 20.0, 0.1) = 4.5;

#ifdef DISTANCE_FADE
group_uniforms distance_fade;
uniform float near_fade_min = 1.0;
uniform float near_fade_max = 1.5;

uniform float far_fade_min = 500.0;
uniform float far_fade_max = 700.0;
#endif

group_uniforms waves;
uniform float base_height = 10.0;
uniform float wave_amplitude: hint_range(0.0, 100.0) = 2.0;
uniform vec2 wave_velocity = vec2(0.01);
uniform sampler2D wave_height_map: hint_default_white;
uniform sampler2D wave_normal_map: hint_normal;
uniform float wave_normal_map_strength: hint_range(0.0, 2.0, 0.01) = 1.0;

group_uniforms foam;
uniform vec3 foam_albedo: source_color = vec3(0.97);
uniform float foam_roughness = 1.0;
uniform float foam_specular: hint_range(0.0, 1.0, 0.01) = 0.25;
uniform vec2 foam_velocity = vec2(0.1);
uniform float foam_thickness : hint_range(0.0, 5.0, 0.001) = 0.1;
uniform float foam_bubble_thickness : hint_range(0.0, 5.0, 0.001) = 0.5;
uniform float foam_bubble_threshold: hint_range(0.0, 1.0, 0.01) = 0.8;
uniform float foam_bubble_smoothing: hint_range(0.0, 1.0, 0.01) = 0.3;
uniform sampler2D foam_bubble_noise: repeat_enable;
uniform vec2 foam_bubble_scale = vec2(0.4);

#ifdef SNELL
group_uniforms snell;
uniform vec3 snell_albedo: source_color;
uniform float snell_index : hint_range(0.0, 2.0) = 1.333;
uniform float snell_edge_refraction_factor: hint_range(0.0, 20.0) = 2.0;
#endif

#ifdef SSR
group_uniforms screen_space_reflections;
uniform float ssr_mix_strength : hint_range(0.0, 1.0, 0.01) = 0.65;
uniform float ssr_travel : hint_range(0.0, 300.0, 0.5) = 100.0;
uniform float ssr_resolution_near : hint_range(0.1, 10.0, 0.1) = 1.0;
uniform float ssr_resolution_far : hint_range(2.0, 20.0, 0.1) = 5.0;
uniform float ssr_tolerance : hint_range(0.0, 2.0, 0.01) = 1.0;
#endif

group_uniforms refraction;
uniform float refraction_strength : hint_range(0.0, 1.0, 0.01) = 0.1;

group_uniforms detail_normals;
uniform sampler2D detail_normal_map : hint_normal, filter_linear_mipmap;
uniform float normal_map_depth: hint_range(0.0, 4.0, 0.01) = 0.2;

uniform vec2 detail_sample_1_scale = vec2(0.1);
uniform vec2 detail_sample_1_velocity = vec2(0.1);
uniform float detail_sample_1_strength: hint_range(0.0, 10.0) = 1.0;
uniform float detail_sample_1_lod: hint_range(0.0, 20.0) = 2.0;

uniform vec2 detail_sample_2_scale = vec2(0.1);
uniform vec2 detail_sample_2_velocity = vec2(0.1);
uniform float detail_sample_2_strength: hint_range(0.0, 10.0) = 1.0;
uniform float detail_sample_2_lod: hint_range(0.0, 20.0) = 2.0;

global uniform float partition_size = 16.0;
global uniform int partition_lod_step = 1;
global uniform int partition_lod_zero_radius = 1;
global uniform vec3 terrain_position;
global uniform vec3 player_position;

uniform sampler2D screen_texture: hint_screen_texture, filter_linear_mipmap, repeat_disable;
uniform sampler2D depth_texture: hint_depth_texture, filter_linear_mipmap, repeat_disable;

varying vec3 global_position;

float fresnel(vec3 normal, vec3 view) {
	return pow((1.0 - clamp(dot(normalize(normal), normalize(view)), 0.0, 1.0 )), fresnel_radius);
}

float snells_window(vec3 normal, vec3 view, float ior) {
	float cos_theta = dot(normal, view);
	return step(sqrt(1.0 - cos_theta * cos_theta) * ior, 1.0);
}

vec2 get_uv_from_view_position(vec3 position_view_space, mat4 proj_m)
{
	vec4 position_clip_space = proj_m * vec4(position_view_space.xyz, 1.0);
	vec2 position_ndc = position_clip_space.xy / position_clip_space.w;
	return position_ndc.xy * 0.5 + 0.5;
}

vec3 get_view_position_from_uv(vec2 uv, float depth, mat4 inv_proj_m)
{
	vec4 position_ndc = vec4((uv * 2.0) - 1.0, depth, 1.0);
	vec4 view_position = inv_proj_m * position_ndc;
	return view_position.xyz /= view_position.w;
}

float get_height(vec3 position){
	vec2 uv = (position.xz + vec2(0.5)) / vec2(textureSize(wave_height_map,0));
	return base_height + textureLod(wave_height_map, uv + wave_velocity * TIME, 0.0).r * wave_amplitude;
}

vec3 get_normal(vec3 position){
	vec2 uv = (position.xz + vec2(0.5)) / vec2(textureSize(wave_normal_map,0));
	return textureLod(wave_normal_map, uv + wave_velocity * TIME, 0.0).rgb;
}

float true_round(float value){
	return ceil(value - 0.49999);
}

void vertex() {
	global_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;

	vec3 terrain_vertex = global_position - terrain_position;
	
	float lod = true_round(max(abs(terrain_vertex.x), abs(terrain_vertex.z))/partition_size) * float(partition_lod_step);
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
}

void fragment() {
	vec3 opposing_color = vec3(1.0) - absorption_albedo;
	float fresnel_value = fresnel(NORMAL, VIEW);
	
	vec3 base_unpacked = fma(get_normal(global_position), vec3(2.0), vec3(-1.0));
	
	vec2 detail_sample_1_uv = fma(global_position.xz, detail_sample_1_scale, detail_sample_1_velocity * TIME);
	vec2 detail_sample_2_uv = fma(global_position.xz, detail_sample_2_scale, detail_sample_2_velocity * TIME);
	vec3 detail_sample_1_unpacked = fma(textureLod(detail_normal_map, detail_sample_1_uv, detail_sample_1_lod).rgb, vec3(2.0), vec3(-1.0));
	vec3 detail_sample_2_unpacked = fma(textureLod(detail_normal_map, detail_sample_2_uv, detail_sample_2_lod).rgb, vec3(2.0), vec3(-1.0));
	
	vec3 combined = base_unpacked * wave_normal_map_strength + detail_sample_1_unpacked * detail_sample_1_strength + detail_sample_2_unpacked * detail_sample_2_strength;
	NORMAL_MAP = fma(combined, vec3(0.5), vec3(0.5));
	
	//NORMAL_MAP = textureLod(normal_map, normal_map_uv, normal_map_lod).rgb;
	NORMAL_MAP_DEPTH = normal_map_depth;
	
	vec2 refraction_uv_offset = combined.xy * refraction_strength;
	vec2 uv_refracted = SCREEN_UV - refraction_uv_offset;
	
	float depth = textureLod(depth_texture, SCREEN_UV, 0.0).r;
	float depth_refracted = textureLod(depth_texture, uv_refracted, 0.0).r;
	
	vec3 ndc = vec3(fma(SCREEN_UV, vec2(2.0), vec2(-1.0)), depth);
	vec3 ndc_refracted = vec3(fma(uv_refracted, vec2(2.0), vec2(-1.0)), depth_refracted);
	
	vec4 view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	view.xyz /= view.w;
	vec4 view_refracted = INV_PROJECTION_MATRIX * vec4(ndc_refracted, 1.0);
	view_refracted.xyz /= view_refracted.w;
	
	float linear_depth = -view.z + VERTEX.z;
	float linear_depth_refracted = -view_refracted.z + VERTEX.z;
	
	vec4 world;
	if (linear_depth_refracted > 0.00001) {
		world = INV_VIEW_MATRIX * INV_PROJECTION_MATRIX * vec4(ndc_refracted, 1.0);
	} else {
		world = INV_VIEW_MATRIX * INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	}
	
	world.xyz /= world.w;
	
	float vertex_y = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).y;
	float relative_depth = vertex_y - world.y;

	float depth_blend = clamp(relative_depth / depth_distance, 0.0, 1.0);
	depth_blend = fma(exp(-depth_blend * beers_law), -1.0, 1.0);
	
	vec3 screen;
	if (linear_depth_refracted > 0.00001) {
		screen = textureLod(screen_texture, uv_refracted, 0.0).rgb;
	} else {
		screen = textureLod(screen_texture, SCREEN_UV, 0.0).rgb;
	}
	
	float edge_depth = smoothstep(0.0, foam_thickness, linear_depth);
	float bubble_depth = smoothstep(0.0, foam_bubble_thickness, linear_depth - foam_thickness);
	
	float edge_mask = 1.0 - step(1.0, edge_depth);
	float bubble_blend = 1.0 - clamp(bubble_depth, 0.0, 1.0);
	
	vec2 bubble_uv = fma(global_position.xz, foam_bubble_scale, foam_velocity * TIME);
	float bubble_mask = 1.0 - texture(foam_bubble_noise, bubble_uv).r;
	bubble_mask = step(foam_bubble_threshold, bubble_blend * (bubble_mask + foam_bubble_smoothing));
	
	float foam_mask = clamp(edge_mask + bubble_mask, 0.0, 1.0);
	
	#ifdef DISTANCE_FADE
	float distance_from_camera = distance(CAMERA_POSITION_WORLD, global_position);
	ALPHA *= smoothstep(near_fade_min, near_fade_max, distance_from_camera);
	ALPHA *= smoothstep(far_fade_max, far_fade_min, distance_from_camera);
	#endif

	vec3 color = clamp(screen - absorption_albedo * depth_blend, vec3(0.0), vec3(1.0));
	color = mix(color, opposing_color, depth_blend * depth_blend);
	color = mix(color, fresnel_albedo, fresnel_value);
	
	#ifdef SNELL
	float snell_mask = 1.0;
	vec3 snell_normal = NORMAL - vec3(refraction_uv_offset, 0.0) * snell_edge_refraction_factor;
	if(!FRONT_FACING) {
		snell_mask = snells_window(snell_normal, VIEW, snell_index);
	}
	color = mix(snell_albedo, color, snell_mask);
	#endif
	
	#ifdef SSR
	vec3 view_normal_map = mat3(VIEW_MATRIX) * (vec3(NORMAL_MAP.x, 0.0, NORMAL_MAP.y) * 2.0 - 1.0);
	vec3 combined_normal = normalize(view_normal_map * (NORMAL_MAP_DEPTH * 0.15) + NORMAL);
	vec3 reflacted_path = reflect(-VIEW, combined_normal);
	
	vec2 current_screen_pos = vec2(0.0);
	vec3 current_view_pos = VERTEX;
	vec3 sampled_color = vec3(-1.0);
	float current_stepD = 0.0;
	float current_depth = 0.0;
	float alpha_hit = 0.0;
	for(float i = 0.01; i < ssr_travel; i++) {
		current_stepD = mix(ssr_resolution_near, ssr_resolution_far,float(i) / float(ssr_travel));
		current_view_pos += reflacted_path * current_stepD;
		current_screen_pos = get_uv_from_view_position(current_view_pos, PROJECTION_MATRIX);
		if (!in_bounds(current_screen_pos)) {break;}
		current_depth = get_view_position_from_uv(current_screen_pos, texture(depth_texture, current_screen_pos).x, INV_PROJECTION_MATRIX).z - current_view_pos.z;

		if (current_depth > -0.0001 && current_depth <= ssr_tolerance * current_stepD) {
			sampled_color = textureLod(screen_texture, current_screen_pos, 0.5).rgb;
			vec2 ruv = 1.0 - abs(current_screen_pos * 2.0 - 1.0);
			ruv = pow(ruv, vec2(0.5));
			alpha_hit = clamp(min(ruv.x, ruv.y), 0.0, 1.0);
			break;
		}
		i += current_stepD;
	}
	
	color = mix(color, sampled_color, alpha_hit * (1.0 - base_roughness) * ssr_mix_strength);
	#endif
	
	color = mix(color, foam_albedo, foam_mask);
	ALBEDO = color;
	ROUGHNESS = mix(base_roughness, foam_roughness, foam_mask);
	SPECULAR = mix(base_specular, foam_specular, foam_mask);
}