@tool
extends MeshInstance3D
class_name TerrainPartition

var x: int = 0
var z: int = 0

var size: float
var lod_step: int
var lod_zero_radius: int

# Called when the node enters the scene tree for the first time.
func _ready():
	mesh = PlaneMesh.new()
	mesh.size = Vector2.ONE * size
	
	position = Vector3(x, 0, z) * size
	
	var lod: int = max(abs(x), abs(z)) * lod_step
	lod = max(0, lod - lod_zero_radius * lod_step)
	var subdivisions: int = int(pow(2, lod))
	var subdivision_depth: int = max(size / subdivisions - 1, 0)
	
	mesh.subdivide_width = subdivision_depth
	mesh.subdivide_depth = subdivision_depth
