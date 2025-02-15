extends Node3D
class_name Entity

var components: Dictionary[Object, Component]

var _cached_component_queries: Dictionary[Object, Array]

func get_physics_body() -> PhysicsBody3D:
	var node: Node = self
	return node as PhysicsBody3D

func get_component(type: Object) -> Component:
	return components.get(type, null)

func has_component(type: Object) -> bool:
	return components.has(type)

func get_components(type: Object) -> Array:
	if _cached_component_queries.has(type):
		return _cached_component_queries[type]
	var result: Array = []
	for component in components.values():
		if is_instance_of(component, type):
			result.append(component)
	_cached_component_queries[type] = result
	return result

func register_component(component: Component):
	var type: Object = component.get_script()
	if has_component(type):
		push_error("Duplicate component " + str(component) + " at " + str(self))
	else:
		components[type] = component
		_cached_component_queries.clear()

func unregister_component(component: Component):
	var type: Object = component.get_script()
	if has_component(type):
		components.erase(type)
		_cached_component_queries.clear()
