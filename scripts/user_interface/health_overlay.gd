@tool
class_name HealthOverlay extends Node2D


func _ready() -> void:
	position = get_viewport_rect().size / 2.0


func update_health_visualization(health_fraction: float) -> void:
	for child in get_children():
		if child is BranchRing:
			child.update_health_visualization(health_fraction)
