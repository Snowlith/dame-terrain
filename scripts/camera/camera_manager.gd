extends Component
class_name CameraManager

@export var sensitivity: float = 1.5
@export var nodes_with_camera_offset: Array[Node]

@export_subgroup("Dynamic FOV")
@export var fov_speed_change: float = 0.5
@export var fov_settle_speed: float = 10

@onready var camera: Camera3D = $Camera3D

var default_fov: float

var start_pos: Vector3

# TODO: 3rd person camera
# TODO: move hand naturally

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	camera.rotation_order = EULER_ORDER_XYZ # Fixes camera turning problems
	process_priority = 100 # Updates after other nodes

	default_fov = camera.fov
	start_pos = camera.position

func _unhandled_input(event: InputEvent):
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	var mouse_event := event as InputEventMouseMotion
	if mouse_event:
		# Camera rotation
		var look_dir: Vector2 = mouse_event.relative * 0.001
		
		parent_entity.rotate_y(-look_dir.x * sensitivity)
		camera.rotate_x(-look_dir.y * sensitivity)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-90), deg_to_rad(90))

func _process(delta):
	_update_fov_offset(delta)
	
	var cumulative_offset := Vector3.ZERO
	for node in nodes_with_camera_offset:
		if not is_instance_valid(node):
			continue
		if "camera_offset" in node:
			var offset = node.camera_offset as Vector3
			cumulative_offset += offset
	
	camera.position = start_pos + cumulative_offset

func get_look_dir() -> Vector3:
	return -camera.global_transform.basis.z

func set_look_dir(dir: Vector3) -> void:
	var yaw = atan2(dir.x, dir.z)
	var pitch = asin(dir.y)

	parent_entity.rotation.y = yaw
	camera.rotation.x = clamp(pitch, deg_to_rad(-89), deg_to_rad(89))

## Visual effects

func _update_fov_offset(delta: float) -> void:
	# Horizontal look direction and player velocity
	var look_dir_xz = Vector2(get_look_dir().x, get_look_dir().z).normalized()
	var velocity_xz = Vector2(parent_entity.velocity.x, parent_entity.velocity.z)
	var vel_length = velocity_xz.length()

	# Default target FOV
	var target_fov = default_fov

	# Adjust FOV based on the velocity's alignment with the look direction
	if vel_length > 0.0:
		var velocity_normalized = velocity_xz.normalized()
		var vel_dot = look_dir_xz.dot(velocity_normalized) * vel_length
		target_fov += fov_speed_change * vel_dot

	# Smoothly interpolate the FOV and clamp it
	camera.fov = clamp(lerp(camera.fov, target_fov, fov_settle_speed * delta), default_fov - 15, default_fov + 15)
