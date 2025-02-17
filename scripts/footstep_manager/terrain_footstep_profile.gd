@tool
extends FootstepProfile
class_name TerrainFootstepProfile

# TODO: add impact sounds for jump & land
@export var red_biome_audio_stream: AudioStream
@export var green_biome_audio_stream: AudioStream
@export var blue_biome_audio_stream: AudioStream

@export var biome_image: Image

func _on_terrain_generator_maps_calculated():
	biome_image = get_parent_entity().get_component(TerrainGenerator).biome_image

func get_audio_stream(footstep_manager: FootstepManager):
	var entity: Entity = footstep_manager.get_parent_entity()
	if not entity:
		return
	var biome = get_biome(entity.global_position)
	
	if is_zero_approx(biome.r + biome.g + biome.b):
		return audio_stream
		
	if biome.r >= max(biome.g, biome.b):
		return red_biome_audio_stream
	elif biome.g >= biome.b:
		return green_biome_audio_stream
	return blue_biome_audio_stream

func get_biome(pos: Vector3):
	var image_size = biome_image.get_size().x
	if abs(pos.x) > 0.5 * image_size or abs(pos.z) > 0.5 * image_size:
		return 0.0
	var pixel_x = int(pos.x + 0.5 * image_size)
	var pixel_z = int(pos.z + 0.5 * image_size)
	return biome_image.get_pixel(pixel_x, pixel_z)
	
