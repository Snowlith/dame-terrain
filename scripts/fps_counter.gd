extends Node

@export var light_scene: PackedScene
@onready var label = $Label

func _unhandled_input(event):
	if event.is_action_pressed("spawn_light"):
		var light = light_scene.instantiate()
		get_tree().current_scene.add_child(light)
		light.global_position = get_parent().global_position + Vector3.UP
		light.light_color = Color(randf(), randf(), randf())
	elif event.is_action_pressed("switch_mouse_mode"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		elif Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			
func _process(delta):
	label.text = str(int(Engine.get_frames_per_second())) + " FPS"
