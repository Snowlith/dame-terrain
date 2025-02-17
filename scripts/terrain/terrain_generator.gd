extends Component
class_name TerrainGenerator

# TODO: move amplitude and others here to centralize data

@export var noise_texture: NoiseTexture2D
@export var falloff_texture: CompressedTexture2D

@export_group("Grass Definition")
@export var max_grass_steepness: float = 0.6
@export var grass_edge_smoothing: float = 0.03
@export var grass_edge_noise: NoiseTexture2D
@export var grass_edge_noise_intensity: float

@export_group("Sand Definition")
@export var max_sand_height: float = 0.1
@export var sand_edge_smoothing: float = 0.03
@export var sand_edge_noise: NoiseTexture2D
@export var sand_edge_noise_intensity: float


@export_group("Node Setup")
@export var player_character: Node3D
@export var partition_container: Node3D
@export var physics_bodies: Array[PhysicsBody3D] = []
@export var foliage_particles: Array[GPUParticles3D]
@export var render_distance: int = 8

@export var partition_material: ShaderMaterial

const COLLIDER = preload("res://scripts/terrain/terrain_collider.tscn")
const PARTITION = preload("res://scripts/terrain/terrain_partition.tscn")

@onready var static_body: StaticBody3D = get_parent_entity().get_physics_body()

@onready var amplitude: float = partition_material.get_shader_parameter("amplitude")
@onready var partition_size: float = partition_material.get_shader_parameter("partition_size")
@onready var partition_lod_step: float = partition_material.get_shader_parameter("partition_lod_step")
@onready var partition_lod_zero_radius: float = partition_material.get_shader_parameter("partition_lod_zero_radius")

@onready var sprite_2d = $Sprite2D
@onready var sprite_2d_2 = $Sprite2D2

signal maps_calculated
# TODO: connect to this signal in grass 

var biome_image: Image
var biome_texture: ImageTexture

var height_texture: ImageTexture
var steepness_texture: ImageTexture
var normal_texture: ImageTexture

var height_image: Image
var steepness_image: Image
var normal_image: Image

func _ready():
	assert(static_body != null)
	precompute_maps()
	generate_colliders()
	generate_partitions()

func _physics_process(delta):
	partition_container.global_position = player_character.global_position.snapped(Vector3.ONE * partition_size) * Vector3(1, 0, 1)
	partition_material.set_shader_parameter("terrain_position", partition_container.global_position)

func precompute_maps():
	var noise_image = noise_texture.noise.get_image(noise_texture.get_width(), noise_texture.get_height())
	var falloff_image = falloff_texture.get_image()
	
	var size = noise_image.get_size()
	height_image = Image.create_empty(size.x, size.y, true, Image.FORMAT_R8)
	steepness_image = Image.create_empty(size.x, size.y, true, Image.FORMAT_R8)
	biome_image = Image.create_empty(size.x, size.y, true, Image.FORMAT_RGB8)
	normal_image = Image.create_empty(size.x, size.y, false, Image.FORMAT_RGB8)
	
	for y in size.y:
		for x in size.x:
			var noise_value = noise_image.get_pixel(x, y).r
			var falloff_value = falloff_image.get_pixel(x, y).r
			var height = noise_value * falloff_value
			height_image.set_pixel(x, y, Color(height, 0, 0))
			
	for y in size.y:
		for x in size.x:
			var height = height_image.get_pixel(x, y).r
			
			var left = height_image.get_pixel(max(0, x - 1), y).r
			var right = height_image.get_pixel(min(size.x-1, x + 1), y).r
			var down = height_image.get_pixel(x, max(0, y - 1)).r
			var up = height_image.get_pixel(x, min(size.y-1, y + 1)).r
			
			var dx = abs(right - height) * amplitude
			var dy = abs(up - height) * amplitude
			
			var normal = Vector3(-dx, -dy, 1.0).normalized()
			var color = Color((normal.x + 1.0) * 0.5, (normal.y + 1.0) * 0.5, (normal.z + 1.0) * 0.5)
			normal_image.set_pixel(x, y, color)
			
			var steepness = min(1.0, sqrt(dx * dx + dy * dy))
			steepness_image.set_pixel(x, y, Color(steepness, 0, 0))
	
	for y in size.y:
		for x in size.x:
			var height = height_image.get_pixel(x, y).r
			var steepness = steepness_image.get_pixel(x, y).r
			# biome
			var grass_noise_val = 1.0
			if grass_edge_noise_intensity > 0.0:
				grass_noise_val = lerp(1.0, grass_edge_noise.noise.get_noise_2d(x, y), grass_edge_noise_intensity)
			
			# And for the sand transition.
			var sand_noise_val = 1.0
			if sand_edge_noise_intensity > 0.0:
				sand_noise_val = lerp(1.0, sand_edge_noise.noise.get_noise_2d(x, y), sand_edge_noise_intensity)
			
			# Compute the cliff factor from the (optionally noise-modulated) steepness.
			# When steepness is high, cliff_factor → 1.
			var cliff_factor = smoothstep(max_grass_steepness - grass_edge_smoothing, max_grass_steepness, steepness * grass_noise_val)
			
			# Compute the sand factor from the (optionally noise-modulated) height.
			# When height is below max_sand_height, sand_factor → 1.
			var sand_factor = 1.0 - smoothstep(max_sand_height - sand_edge_smoothing, max_sand_height, height * sand_noise_val)
			
			# The remaining weight goes to grass.
			var grass_factor = (1.0 - cliff_factor) * (1.0 - sand_factor)
			# Adjust cliff weight so that grass + cliff = 1 when there’s no sand.
			var final_cliff = cliff_factor * (1.0 - sand_factor)
			var final_sand = sand_factor
			
			# Store the biome weights as (R, G, B) = (grass, cliff, sand)
			var biome_color = Color(grass_factor, final_cliff, final_sand)
			biome_image.set_pixel(x, y, biome_color)
	
	height_image.generate_mipmaps(true)
	steepness_image.generate_mipmaps(true)
	biome_image.generate_mipmaps(true)
	# Assign images to textures
	height_texture = ImageTexture.create_from_image(height_image)
	steepness_texture = ImageTexture.create_from_image(steepness_image)
	normal_texture = ImageTexture.create_from_image(normal_image)
	biome_texture = ImageTexture.create_from_image(biome_image)
	
	sprite_2d.texture = height_texture
	sprite_2d_2.texture = biome_texture
	#sprite_2d_2.texture = steepness_texture
	# Assign textures to the shader
	partition_material.set_shader_parameter("height_map", height_texture)
	partition_material.set_shader_parameter("biome_map", biome_texture)
	
	for gpu_particles: GPUParticles3D in foliage_particles:
		var mat: ShaderMaterial = gpu_particles.process_material
		mat.set_shader_parameter("height_map", height_texture)
		mat.set_shader_parameter("steepness_map", steepness_texture)
		mat.set_shader_parameter("amplitude", amplitude)
		mat.set_shader_parameter("normal_map", normal_texture)
		
	
func generate_colliders():
	for physics_body in physics_bodies:
		var collider: TerrainCollider = COLLIDER.instantiate()
		
		collider.physics_body = physics_body
		collider.height_image = height_image
		collider.amplitude = amplitude
		collider.partition_size = partition_size
		
		static_body.add_child.call_deferred(collider)

func generate_partitions():
	for x in range(-render_distance, render_distance + 1):
		for z in range(-render_distance, render_distance + 1):
			var partition: TerrainPartition = PARTITION.instantiate()
			
			partition.x = x
			partition.z = z
			partition.material_override = partition_material
			partition.size = partition_size
			partition.lod_step = partition_lod_step
			partition.lod_zero_radius = partition_lod_zero_radius
			
			partition_container.add_child.call_deferred(partition)
