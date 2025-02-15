extends Component
class_name TerrainGenerator

# TODO:
# precalculate normals for grass direction

@export var noise_texture: NoiseTexture2D
@export var falloff_texture: CompressedTexture2D

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
	#grass.

func _physics_process(delta):
	partition_container.global_position = player_character.global_position.snapped(Vector3.ONE * partition_size) * Vector3(1, 0, 1)
	partition_material.set_shader_parameter("terrain_position", partition_container.global_position)

func precompute_maps():
	var noise_image = noise_texture.noise.get_image(noise_texture.get_width(), noise_texture.get_height())
	var falloff_image = falloff_texture.get_image()
	
	var size = noise_image.get_size()
	height_image = Image.create_empty(size.x, size.y, true, Image.FORMAT_R8)
	steepness_image = Image.create_empty(size.x, size.y, true, Image.FORMAT_R8)
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
			
			var dx2 = (right - left) * amplitude
			var dy2 = (up - down) * amplitude
			
			var normal = Vector3(-dx, -dy, 1.0).normalized()
			var color = Color((normal.x + 1.0) * 0.5, (normal.y + 1.0) * 0.5, (normal.z + 1.0) * 0.5)
			normal_image.set_pixel(x, y, color)
			
			var steepness = min(1.0, sqrt(dx * dx + dy * dy))
			steepness_image.set_pixel(x, y, Color(steepness, 0, 0))
	
	height_image.generate_mipmaps(true)
	steepness_image.generate_mipmaps(true)
	# Assign images to textures
	height_texture = ImageTexture.create_from_image(height_image)
	steepness_texture = ImageTexture.create_from_image(steepness_image)
	normal_texture = ImageTexture.create_from_image(normal_image)
	
	sprite_2d.texture = height_texture
	sprite_2d_2.texture = normal_texture
	#sprite_2d_2.texture = steepness_texture
	# Assign textures to the shader
	partition_material.set_shader_parameter("height_map", height_texture)
	partition_material.set_shader_parameter("steepness_map", steepness_texture)
	
	for gpu_particles: GPUParticles3D in foliage_particles:
		var mat: ShaderMaterial = gpu_particles.process_material
		mat.set_shader_parameter("height_map", height_texture)
		mat.set_shader_parameter("steepness_map", steepness_texture)
		mat.set_shader_parameter("amplitude", amplitude)
		#mat.set_shader_parameter("normal_map", normal_texture)
		
	
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
