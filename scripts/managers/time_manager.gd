# Responsible for propagating time of day changes to relevant objects
class_name TimeManager
extends Node

var sprites: Array[Sprite3D] = []
var _current_time_of_day: float = 0.0

func _ready() -> void:
	# Defer this so all child scenes are fully instantiated 
	call_deferred("_register_sprites")

func _register_sprites() -> void:
	for node in get_tree().get_nodes_in_group("time_of_day"):
		if node is Sprite3D:
			sprites.append(node)
	
	if OS.is_debug_build():
		DebugUI.register_debug_target(self )

func _set_new_target_time_of_day(value: float) -> void:
	_current_time_of_day = clampf(value, 0.0, 1.0)
	_update_current_time_of_day()

func _update_current_time_of_day() -> void:
	for sprite in sprites:
		if sprite.material_override:
			sprite.material_override.set_shader_parameter("time_of_day", _current_time_of_day)

#region Debug

func debug_set_time_of_day(value: float) -> void:
	_set_new_target_time_of_day(value)

func debug_get_current_time_of_day() -> float:
	return _current_time_of_day

#endregion
