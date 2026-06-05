@tool
class_name HealthOverlay extends Node2D


func _ready() -> void:
	position = get_viewport_rect().size / 2.0


func set_health_normalized(h: float) -> void:
	for child in get_children():
		if child is BranchRing:
			child.set_health_normalized(h)
