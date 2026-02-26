# Spawns and manages objects on the workbench at predefined slot positions.
class_name Workbench
extends Node3D

@export var object_slots: Array[Node3D]

@export var transition_curve: Curve
@export var transition_duration: float = 0.3
signal all_objects_completed()

var _used_slots: int = 0
var _completed_objects_count: int = 0 # Completed objects for the current interaction

var _drag_color := Color(0.5, 0.5, 0.5, 0.25)
var _pending_completion_color := Color("white")
var _current_color: Color = _drag_color
var _tween: Tween
const _interactible_object_scene = preload("res://scenes/object_manipulation/interactible_object.tscn")

func _ready() -> void:
	pass


func _process(_delta: float) -> void:
	pass


func _get_next_free_slot() -> Node3D:
	if _used_slots >= object_slots.size():
		print("ERROR: Attempting to add object when workbench is full! Skipping object add...")
		return
	return object_slots[_used_slots]


func reset_workbench() -> void:
	for i in len(object_slots):
		for child in object_slots[i].get_children():
			child.queue_free()
			push_warning("Workbench: Resetting workbench, removed UNCOMPLETED object from slot number ", i)
			
	_used_slots = 0
	_completed_objects_count = 0


func _set_overlay_color(target: Color) -> void:
	if _tween: _tween.kill()
	var start = %WorkbenchDoneAreaOverlay.modulate
	_tween = create_tween()
	_tween.tween_method(func(t: float): %WorkbenchDoneAreaOverlay.modulate = start.lerp(target, transition_curve.sample(t)), 0.0, 1.0, transition_duration)


# adds a new object to the workbench
func add_object(object_scene: PackedScene):
	var interactible_object: InteractibleObject = _interactible_object_scene.instantiate()
	interactible_object.set_spawn_data($FocusPosition, $DoneArea, object_scene)
	
	var slot = _get_next_free_slot()
	slot.add_child(interactible_object)
	interactible_object.global_position = slot.global_position
	_used_slots = _used_slots + 1

	interactible_object.connect("object_completed", _on_object_completed)
	interactible_object.connect("object_state_changed", _on_object_state_changed)
	interactible_object.connect("object_pending_completion_changed", _on_object_pending_completion_changed)
	return interactible_object


#region Signals

func _on_object_completed(object_name: String, is_special_object: bool, completed_stickers: int, total_stickers: int):
	_current_color = _drag_color
	_set_overlay_color(Color(0.0, 0.0, 0.0, 0.0))
	
	_completed_objects_count += 1
	if _completed_objects_count < _used_slots:
		return

	print("Workbench: All objects completed")
	emit_signal("all_objects_completed")


func _on_object_state_changed(state: InteractibleObject.State) -> void:
	if state == InteractibleObject.State.DRAGGING:
		_set_overlay_color(_current_color)
	else:
		_set_overlay_color(Color(0.0, 0.0, 0.0, 0.0))


func _on_object_pending_completion_changed(is_pending_completion: bool) -> void:
	if is_pending_completion:
		_current_color = _pending_completion_color
		_set_overlay_color(_current_color)
	else:
		_current_color = _drag_color
		_set_overlay_color(_current_color)


#endregion
