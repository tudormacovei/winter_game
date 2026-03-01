# Spawns and manages objects on the workbench at predefined slot positions.
class_name Workbench
extends Node3D

@export var object_slots: Array[Node3D]

@export var transition_curve: Curve
@export var transition_duration: float = 0.3
signal all_objects_completed()

var _drag_color := Color(0.5, 0.5, 0.5, 0.25)
var _pending_completion_color := Color("white")
var _current_color: Color = _drag_color
var _tween: Tween
const _interactible_object_scene = preload("res://scenes/object_manipulation/interactible_object.tscn")

func _ready() -> void:
	pass


func _process(_delta: float) -> void:
	pass

# adds a new object to the workbench
func add_object(object_scene: PackedScene):
	var interactible_object: InteractibleObject = _interactible_object_scene.instantiate()
	interactible_object.set_spawn_data($FocusPosition, $DoneArea, object_scene)
	
	var slot = _get_next_free_slot()
	if slot == null:
		interactible_object.queue_free()
		return null
	
	slot.add_child(interactible_object)
	interactible_object.global_position = slot.global_position

	interactible_object.connect("object_completed", _on_object_completed)
	interactible_object.connect("object_state_changed", _on_object_state_changed)
	interactible_object.connect("object_pending_completion_changed", _on_object_pending_completion_changed)
	return interactible_object

func reset_workbench() -> void:
	for i in len(object_slots):
		for child in object_slots[i].get_children():
			child.queue_free()
			push_warning("Workbench: Resetting workbench, removed UNCOMPLETED object from slot number ", i)

func is_workbench_empty() -> bool:
	for slot in object_slots:
		for child in slot.get_children():
			if not child.is_queued_for_deletion():
				return false
	return true

func _get_next_free_slot() -> Node3D:
	for slot in object_slots:
		if slot.get_child_count() == 0:
			return slot
			
	Utils.debug_error("Workbench: Attempting to add object when workbench is full! Skipping object add...")
	return null

func _set_overlay_color(target: Color) -> void:
	if _tween: _tween.kill()
	var start = %WorkbenchDoneAreaOverlay.modulate
	_tween = create_tween()
	_tween.tween_method(func(t: float): %WorkbenchDoneAreaOverlay.modulate = start.lerp(target, transition_curve.sample(t)), 0.0, 1.0, transition_duration)

#region Signals

func _on_object_completed(_object_name: String, _is_special_object: bool, _completed_stickers: int, _total_stickers: int):
	_current_color = _drag_color
	_set_overlay_color(Color(0.0, 0.0, 0.0, 0.0))
	
	if is_workbench_empty():
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
