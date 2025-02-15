extends Component
class_name TerrainGrass

@onready var terrain_manager: TerrainManager = get_parent_entity().get_component(TerrainManager)

@onready var gpu_particles: GPUParticles3D = $GPUParticles3D

func _ready():
	assert(terrain_manager != null)
	var mat: ShaderMaterial = gpu_particles.process_material
	mat.set_shader_parameter("heightmap", terrain_manager.height_texture)
	mat.set_shader_parameter("heightmap_height_scale", terrain_manager.amplitude)
