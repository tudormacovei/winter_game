extends Node

signal first_object_dragged
signal first_object_rotated

func wait_for(signal_name: String) -> void:
	if not has_signal(signal_name):
		Utils.debug_error("GameState: No valid signal with name: " + signal_name)
		return
	await self [signal_name]