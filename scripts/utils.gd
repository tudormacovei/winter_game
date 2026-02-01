@tool
extends Node

func debug_error(message: String):
	push_error(message)
	if OS.has_feature("debug"):
		OS.alert(message)

func get_timestamp_string() -> String:
	var dt := Time.get_datetime_dict_from_system()
	return "%04d-%02d-%02d %02d:%02d:%02d" % [
		dt.year, dt.month, dt.day,
		dt.hour, dt.minute, dt.second
	]

# Gets all children and subchildren of a node
func get_all_children(node: Node) -> Array[Node]:
	var nodes: Array[Node] = []
	
	for N in node.get_children():
		if N.get_child_count() > 0:
			nodes.append(N)
			nodes.append_array(get_all_children(N))
		else:
			nodes.append(N)
	return nodes

# Calculates axis-aligned bounding box of a Node3D, including its children
func _calculate_bounding_box(parent: Node3D, include_top_level_transform: bool) -> AABB:
	var bounds: AABB = AABB()
	if parent is VisualInstance3D:
		bounds = parent.get_aabb();

	for i in range(parent.get_child_count()):
		var child: Node3D = parent.get_child(i)
		if child:
			var child_bounds: AABB = _calculate_bounding_box(child, true)
			if bounds.size == Vector3.ZERO && parent:
				bounds = child_bounds
			else:
				bounds = bounds.merge(child_bounds)
	if include_top_level_transform:
		bounds = parent.transform * bounds
	return bounds
