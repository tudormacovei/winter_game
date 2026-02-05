# Spawns and manages objects on the workbench at predefined slot positions.
class_name Workbench
extends Node3D

@export var object_slots: Array[Node3D]

signal all_objects_completed()

var _used_slots: int = 0
var _completed_objects_count: int = 0

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
	_used_slots = 0
	_completed_objects_count = 0


# adds a new object to the workbench
func add_object(object_scene: PackedScene):
	var interactible_object: InteractibleObject = _interactible_object_scene.instantiate()
	interactible_object.set_spawn_data($FocusPosition, $DoneArea, object_scene)
	add_child(interactible_object)
	
	interactible_object.global_position = _get_next_free_slot().global_position
	_used_slots = _used_slots + 1

	interactible_object.connect("object_completed", _on_object_completed)


#region Signals

func _on_object_completed():
	_completed_objects_count += 1
	if _completed_objects_count < _used_slots:
		return

	print("Workbench: All objects completed")
	emit_signal("all_objects_completed")
	
#endregion
