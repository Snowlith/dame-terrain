extends MovementState
class_name WaterState

@export var max_speed: float = 5
@export var acceleration: float = 5
@export var friction: float = 10

@export var gravity: float = 5

var active: bool = false

var current_water

@onready var camera: Camera3D = get_parent_entity().get_component(CameraManager).get_camera()
@export var cam_bob: CameraBobManager

func handle(delta: float):
	var input_vector: Vector3 = camera.global_basis * _get_input_vector()
	var alternate_y = input_int("jump") - input_int("crouch")
	if abs(alternate_y) > abs(input_vector.y):
		input_vector.y = alternate_y
	input_vector = input_vector.normalized()
	
	if not input_vector:
		_cb.velocity = lerp(_cb.velocity, Vector3.ZERO, friction * delta)
	else:
		_cb.velocity = lerp(_cb.velocity, input_vector * max_speed, acceleration * delta)
	
	_apply_friction(friction, delta)
	
	_cb.velocity.y -= gravity * delta
	
	_cb.move_and_slide()

func update_status(delta: float):
	if current_water:
		return Status.ACTIVE
	return Status.INACTIVE

func enter_water(water):
	if current_water:
		return false
	active = true
	current_water = water
	cam_bob.disable()
	return true

func exit_water():
	active = false
	current_water = null
	cam_bob.enable()
