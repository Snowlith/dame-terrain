@tool
extends WorldEnvironment
class_name BiomeWorldEnvironment

enum EnvironmentType {
	Default,
	Water
}

@export_tool_button("Update Selected Environment", "WorldEnvironment") var update = _update_environment

@export var selected_environment: EnvironmentType = EnvironmentType.Default

@export var default_environment: Environment
@export var water_environment: Environment

func _update_environment():
	switch_to_environment_type(selected_environment)

func switch_to_environment_type(environment_type: EnvironmentType):
	match environment_type:
		EnvironmentType.Default:
			environment = default_environment
		
		EnvironmentType.Water:
			environment = water_environment
