extends Component
class_name FootstepManager

@onready var character_body: CharacterBody3D = get_parent_entity().get_physics_body()

@export var frequency: float = 3.14

@onready var audio_stream_player: AudioStreamPlayer3D = $AudioStreamPlayer3D
@onready var ray_cast: RayCast3D = $RayCast3D

var enabled: bool = true

var current_collider: Object
var current_footstep_profile: FootstepProfile

var _bob_time: float = 0

func _physics_process(delta):
	if current_footstep_profile:
		_bob_time += delta * character_body.velocity.length() * int(character_body.is_on_floor())
	
		if _bob_time > frequency:
			_bob_time -= frequency
			Audio.play_sound(current_footstep_profile.footstep_profile)
	
	var new_collider = ray_cast.get_collider()
	if new_collider == current_collider:
		return
	current_collider = new_collider
	#print("Collider changed")
	if not current_collider:
		current_footstep_profile = null
		return
	current_footstep_profile = _get_footstep_profile(current_collider)


func _get_footstep_profile(collider: Object):
	var entity: Entity = collider as Entity
	if not entity:
		return null
	var footstep_profile: FootstepProfile = entity.get_component(FootstepProfile)
	return footstep_profile

func enable():
	enabled = true

func disable():
	enabled = false
