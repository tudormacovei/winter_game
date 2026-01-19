class_name Workbench
extends Node3D

@export var object_slots: Array[Node3D]

var _used_slots: int = 0

const _object_rotator_scene = preload("res://scenes/object_manipulation/object_rotator.tscn")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _get_next_free_slot() -> Node3D:
	if _used_slots >= object_slots.size():
		print("ERROR: Attempting to add object when workbench is full! Skipping object add...")
		return
	return object_slots[_used_slots]

# adds a new object to the workbench
func add_object(object_scene: PackedScene):
	var object_rotator: ObjectRotator = _object_rotator_scene.instantiate()
	object_rotator.set_spawn_data($FocusPosition, $DoneArea, object_scene)
	add_child(object_rotator)
	
	object_rotator.global_position = _get_next_free_slot().global_position
	_used_slots = _used_slots + 1
