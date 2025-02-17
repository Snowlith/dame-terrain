extends MovementState
class_name AirState

@export var gravity: float = 25
@export var max_speed: float = 2
@export var acceleration: float = 40

@export var landing_sound: AudioStream

@export var footstep_player: FootstepManager

func update_status(delta: float):
	if not _cb.is_on_floor():
		return Status.ACTIVE
	return Status.INACTIVE
	
func handle(delta: float):
	_apply_acceleration(max_speed, acceleration, delta)
	_cb.velocity.y -= gravity * delta
	_cb.move_and_slide()

func exit():
	if landing_sound:
		return
		Audio.play_sound(landing_sound)
