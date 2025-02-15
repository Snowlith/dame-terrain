extends MeshInstance3D
class_name TerrainPartition

var x = 0
var z = 0

var size: float
var lod_step: float
var lod_zero_radius: int

# Called when the node enters the scene tree for the first time.
func _ready():
	mesh = PlaneMesh.new()
	mesh.size = Vector2.ONE * size
	
	position = Vector3(x,0,z) * size
	
	var lod = max(abs(x),abs(z)) * lod_step
	lod = max(0, lod - lod_zero_radius)
	var subdivision_length = pow(2,lod)
	var subdivides = max(size/subdivision_length - 1, 0)
	mesh.subdivide_width = subdivides
	mesh.subdivide_depth = subdivides
