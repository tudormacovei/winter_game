class_name Candle
extends HealthVisualizationSlot


@onready var flame: Node3D = get_node("Flame")


func set_is_on(is_on: bool) -> void:
	flame.visible = is_on
