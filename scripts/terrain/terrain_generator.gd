@tool
extends Component
class_name TerrainGenerator

@export_tool_button("Generate") var generate_button = generate_terrain

@export var terrain_processing_material: ShaderMaterial
@export var partition_material: ShaderMaterial

@export var player_character: Node3D
@export var partition_container: Node3D
@export var physics_bodies: Array[PhysicsBody3D] = []
@export var foliage_particles: Array[GPUParticles3D]
@export var render_distance: int = 8

const COLLIDER = preload("res://scripts/terrain/terrain_collider.tscn")
const PARTITION = preload("res://scripts/terrain/terrain_partition.tscn")
const PROCESSOR = preload("res://scripts/terrain/terrain_processor.tscn")

@onready var static_body: StaticBody3D = get_parent_entity().get_physics_body()
@onready var sprite_2d = $Sprite2D
@onready var sprite_2d_2 = $Sprite2D2

var amplitude: float
var partition_size: float
var partition_lod_step: float
var partition_lod_zero_radius: int

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

var partitions: Array[TerrainPartition]

func _ready():
	if Engine.is_editor_hint():
		return
	generate_terrain()

func _physics_process(delta):
	partition_container.global_position = player_character.global_position.snapped(Vector3.ONE * partition_size) * Vector3(1, 0, 1)
	partition_material.set_shader_parameter("terrain_position", partition_container.global_position)

func generate_terrain():
	print("[TerrainGenerator] Generating...")
	get_shader_uniforms()
	await generate_maps()
	await generate_partitions()
	if Engine.is_editor_hint():
		return
	generate_colliders()

func get_shader_uniforms():
	amplitude = terrain_processing_material.get_shader_parameter("amplitude")
	partition_size = partition_material.get_shader_parameter("partition_size")
	partition_lod_step = partition_material.get_shader_parameter("partition_lod_step")
	partition_lod_zero_radius = partition_material.get_shader_parameter("partition_lod_zero_radius")

func generate_maps():
	var terrain_processor = PROCESSOR.instantiate()
	add_child(terrain_processor)
	terrain_processor.set_terrain_processing_material(terrain_processing_material)
	
	height_image = await terrain_processor.get_image(0)
	normal_image = await terrain_processor.get_image(1)
	steepness_image = await terrain_processor.get_image(2)
	biome_image = await terrain_processor.get_image(3)
	
	#height_image.generate_mipmaps(true)
	#steepness_image.generate_mipmaps(true)
	#biome_image.generate_mipmaps(true)
	#normal_image.generate_mipmaps(true)
	
	height_texture = ImageTexture.create_from_image(height_image)
	steepness_texture = ImageTexture.create_from_image(steepness_image)
	normal_texture = ImageTexture.create_from_image(normal_image)
	biome_texture = ImageTexture.create_from_image(biome_image)
	
	sprite_2d.texture = height_texture
	sprite_2d_2.texture = normal_texture
	
	partition_material.set_shader_parameter("amplitude", amplitude)
	partition_material.set_shader_parameter("height_map", height_texture)
	partition_material.set_shader_parameter("normal_map", normal_texture)
	partition_material.set_shader_parameter("biome_map", biome_texture)
	
	for gpu_particles: GPUParticles3D in foliage_particles:
		var mat: ShaderMaterial = gpu_particles.process_material
		print("SETTING STUFF")
		mat.set_shader_parameter("amplitude", amplitude)
		mat.set_shader_parameter("height_map", height_texture)
		mat.set_shader_parameter("normal_map", normal_texture)
		mat.set_shader_parameter("biome_map", biome_texture)
	
	remove_child(terrain_processor)
	terrain_processor.queue_free()
	
	maps_calculated.emit()
	
func generate_colliders():
	for physics_body in physics_bodies:
		var collider: TerrainCollider = COLLIDER.instantiate()
		
		collider.physics_body = physics_body
		collider.height_image = height_image
		collider.amplitude = amplitude
		collider.partition_size = partition_size
		
		static_body.add_child.call_deferred(collider)

func generate_partitions():
	for partition in partitions:
		partition_container.remove_child(partition)
		partition.queue_free()
	partitions.clear()
		
	for x in range(-render_distance, render_distance + 1):
		for z in range(-render_distance, render_distance + 1):
			var partition: TerrainPartition = PARTITION.instantiate()
			
			partition.x = x
			partition.z = z
			partition.material_override = partition_material
			partition.size = partition_size
			partition.lod_step = partition_lod_step
			partition.lod_zero_radius = partition_lod_zero_radius
			
			partitions.append(partition)
			
			partition_container.add_child.call_deferred(partition)
