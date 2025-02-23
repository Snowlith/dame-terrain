@tool
extends Node2D

@onready var sub_viewport: SubViewport = $SubViewport
@onready var color_rect: ColorRect = $SubViewport/ColorRect

func set_terrain_processing_material(mat: ShaderMaterial):
	color_rect.material = mat
	mat.set_shader_parameter("cycle_mode", false)

func get_image(mode: int):
	color_rect.material.set_shader_parameter("mode", mode)
	await RenderingServer.frame_post_draw
	var texture = sub_viewport.get_texture()
	return texture.get_image()
