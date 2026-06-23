# Responsible for propagating time of day changes to relevant objects
class_name TimeManager
extends Node

var sprites: Array[Sprite3D] = []
var _current_time_of_day: float = 0.0:
	set(value):
		_current_time_of_day = clampf(value, 0.0, 1.0)
		_update_current_time_of_day()
	get:
		return _current_time_of_day

var _active_tween = null

func _ready() -> void:
	# Defer this so all child scenes are fully instantiated 
	call_deferred("_register_sprites")

func set_target_time_of_day(day_progress: float, do_lerp: bool = true) -> void:
	const ERROR_MARGIN: float = 0.0001

	if _active_tween:
		_active_tween.kill()
		_active_tween = null

	# Map day progress to time of day (take into account actual start time of day)
	var target_time = lerp(Config.TIME_OF_DAY_START, 1.0, day_progress)

	var delta = abs(target_time - _current_time_of_day)
	if not do_lerp or delta <= ERROR_MARGIN:
		_current_time_of_day = target_time
		return

	_active_tween = get_tree().create_tween()
	_active_tween.tween_property(self, "_current_time_of_day", target_time, Config.TIME_OF_DAY_BASE_LERP_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _register_sprites() -> void:
	for node in get_tree().get_nodes_in_group("time_of_day"):
		if node is Sprite3D:
			sprites.append(node)
	
	_update_current_time_of_day()

	if OS.is_debug_build():
		DebugUI.register_debug_target(self)

func _update_current_time_of_day() -> void:
	for sprite in sprites:
		if sprite.material_override:
			sprite.material_override.set_shader_parameter("time_of_day", _current_time_of_day)

#region Debug

func debug_set_time_of_day(value: float) -> void:
	_current_time_of_day = value

func debug_get_current_time_of_day() -> float:
	return _current_time_of_day

#endregion
