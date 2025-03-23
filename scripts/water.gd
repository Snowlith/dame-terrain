extends Area3D

var entities: Array[Entity]

@export var world_environment: BiomeWorldEnvironment

@onready var water_overlay: TextureRect = $WaterOverlay

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _unhandled_input(event):
	if event.is_action_pressed("spawn_light"):
		water_overlay.visible = not water_overlay.visible

func _on_body_entered(body: Node3D):
	var entity = body as Entity
	if not entity:
		return
	var water_state = entity.get_component(WaterState)
	if not water_state:
		return
	if water_state.enter_water(self):
		water_overlay.show()
		world_environment.switch_to_environment_type(BiomeWorldEnvironment.EnvironmentType.Water)
		entities.append(entity)

func _on_body_exited(body: Node3D):
	var entity = body as Entity
	if not entity:
		return
	var found = entities.find(entity)
	if found != -1:
		water_overlay.hide()
		world_environment.switch_to_environment_type(BiomeWorldEnvironment.EnvironmentType.Default)
		entity.get_component(WaterState).exit_water()
		entities.remove_at(found)
