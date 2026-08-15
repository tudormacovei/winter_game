class_name HealthVisualization
extends Node3D


var slots: Array[HealthVisualizationSlot] = [] # dynamically populated at runtime cause we cool like that


func _ready() -> void:
	for child in get_children():
		if child is HealthVisualizationSlot:
			slots.append(child)

	if slots.is_empty():
		push_error("HealthVisualization needs at least one health slot child.")


func get_slot_count() -> int:
	return slots.size()


func set_active_slot_count(active_slot_count: int) -> void:
	active_slot_count = clampi(active_slot_count, 0, slots.size())
	for slot_index in slots.size():
		slots[slot_index].set_is_on(slot_index < active_slot_count)
