class_name HealthVisualizationSlot # interface class for health slot objects
extends Node3D


func set_is_on(is_on: bool) -> void:
	push_error("HealthVisualizationSlot must implement set_is_on(). Requested state: %s" % is_on)
