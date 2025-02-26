extends MeshInstance3D

@export var player: Node3D
@export var mat: ShaderMaterial

func _physics_process(delta):
	RenderingServer.global_shader_parameter_set("player_position", player.global_position)
