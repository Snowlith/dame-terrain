@tool
extends Component
class_name TerrainGenerator

@export_tool_button("Generate", "GridMap") var generate_button = generate_terrain

@export var terrain_processing_material: ShaderMaterial

@export_group("Partition Configuration")
@export var partition_scene: PackedScene
@export var partition_container: Node3D
@export var render_distance: int = 10
@export var partition_size: float = 32.0
@export var partition_lod_step: int = 1
@export var partition_lod_zero_radius: int = 2

@export_group("Node Configuration")
@export var player_character: Node3D
@export var physics_bodies: Array[PhysicsBody3D] = []

const COLLIDER = preload("res://scripts/terrain/terrain_collider.tscn")
const PROCESSOR = preload("res://scripts/terrain/terrain_processor.tscn")

@onready var static_body: StaticBody3D = get_parent_entity().get_physics_body()
@onready var sprite_2d = $Sprite2D
@onready var sprite_2d_2 = $Sprite2D2

var amplitude: float

signal maps_calculated

var height_image: Image
var normal_image: Image
var biome_image: Image

var height_texture: ImageTexture
var normal_texture: ImageTexture
var biome_texture: ImageTexture

var partitions: Array[TerrainPartition]

func _ready():
	if Engine.is_editor_hint():
		return
	generate_terrain()

func _physics_process(delta):
	var player_position: Vector3 = player_character.global_position
	partition_container.global_position = player_position.snapped(Vector3.ONE * partition_size) * Vector3(1, 0, 1)
	RenderingServer.global_shader_parameter_set("terrain_position", partition_container.global_position)
	RenderingServer.global_shader_parameter_set("player_position", player_position)

func generate_terrain():
	print("[TerrainGenerator] Generating...")
	if not terrain_processing_material: #or not terrain_material or not water_material:
		push_error("[TerrainGenerator] ERROR: Material missing!")
		return
	if not partition_scene:
		push_error("[TerrainGenerator] ERROR: Partition not assigned!")
		return
	configure_shader_uniforms()
	await generate_maps()
	await generate_partitions()
	if Engine.is_editor_hint():
		return
	generate_colliders()

func configure_shader_uniforms():
	amplitude = terrain_processing_material.get_shader_parameter("amplitude")

func generate_maps():
	var terrain_processor = PROCESSOR.instantiate()
	add_child(terrain_processor)
	terrain_processor.set_terrain_processing_material(terrain_processing_material)
	
	height_image = await terrain_processor.get_image(0)
	normal_image = await terrain_processor.get_image(1)
	biome_image = await terrain_processor.get_image(3)
	
	height_image.generate_mipmaps(true)
	biome_image.generate_mipmaps(true)
	normal_image.generate_mipmaps(true)
	
	height_texture = ImageTexture.create_from_image(height_image)
	normal_texture = ImageTexture.create_from_image(normal_image)
	biome_texture = ImageTexture.create_from_image(biome_image)
	
	sprite_2d.texture = height_texture
	sprite_2d_2.texture = normal_texture
	
	RenderingServer.global_shader_parameter_set("height_map_amplitude", amplitude)
	RenderingServer.global_shader_parameter_set("partition_size", partition_size)
	RenderingServer.global_shader_parameter_set("partition_lod_step", partition_lod_step)
	RenderingServer.global_shader_parameter_set("partition_lod_zero_radius", partition_lod_zero_radius)
	RenderingServer.global_shader_parameter_set("height_map", height_texture)
	RenderingServer.global_shader_parameter_set("normal_map", normal_texture)
	RenderingServer.global_shader_parameter_set("biome_map", biome_texture)
	RenderingServer.global_shader_parameter_set("height_map_amplitude", amplitude)
	RenderingServer.global_shader_parameter_set("height_map_amplitude", amplitude)
	
	remove_child(terrain_processor)
	terrain_processor.queue_free()
	
	maps_calculated.emit()
	
func generate_colliders():
	for physics_body: PhysicsBody3D in physics_bodies:
		var collider: TerrainCollider = COLLIDER.instantiate()
		
		collider.physics_body = physics_body
		collider.height_image = height_image
		collider.amplitude = amplitude
		collider.partition_size = partition_size
		
		static_body.add_child.call_deferred(collider)

func generate_partitions():
	if not partition_container:
		push_error("[TerrainGenerator] Partition container missing!")
		return
	for partition in partitions:
		partition_container.remove_child(partition)
		partition.queue_free()
	partitions.clear()
	
	var partition_custom_aabb := AABB(-Vector3(1, 0, 1) * partition_size / 2, Vector3(partition_size, amplitude, partition_size))
		
	for x: int in range(-render_distance, render_distance + 1):
		for z: int in range(-render_distance, render_distance + 1):
			var partition: TerrainPartition = partition_scene.instantiate()
			
			partition.x = x
			partition.z = z
			partition.size = partition_size
			partition.custom_aabb = partition_custom_aabb
			partition.lod_step = partition_lod_step
			partition.lod_zero_radius = partition_lod_zero_radius
			
			partitions.append(partition)
			
			partition_container.add_child.call_deferred(partition)
