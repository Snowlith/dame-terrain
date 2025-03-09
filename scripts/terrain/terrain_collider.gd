extends CollisionShape3D
class_name TerrainCollider

@export var physics_body: PhysicsBody3D
@export var template_mesh: PlaneMesh

@onready var faces: PackedVector3Array = template_mesh.get_faces()
@onready var snap: Vector3 = Vector3.ONE * template_mesh.size.x / 2

var height_image: Image
var partition_size: float
var amplitude: float

func _ready():
	update_shape()
	
func _physics_process(delta):
	if not physics_body:
		return
	var rounded_body_position = physics_body.global_position.snapped(snap) * Vector3(1,0,1)
	if not global_position == rounded_body_position:
		global_position = rounded_body_position
		update_shape()
	
func update_shape():
	for i in faces.size():
		var global_vert = faces[i] + global_position
		faces[i].y = get_height(global_vert.x, global_vert.z)
	shape.set_faces(faces)

func get_height(x, z):
	var image_size: int = height_image.get_width()
	var half: float = image_size / 2.0
	if abs(x) > half or abs(z) > half:
		return 0.0
	var pixel_x = int(fposmod(x + half, image_size))
	var pixel_z = int(fposmod(z + half, image_size))
	return height_image.get_pixel(pixel_x, pixel_z).r * amplitude
