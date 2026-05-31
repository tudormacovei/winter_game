extends Node

# Signals are emitted in relevant places in the codebase according to player actions so they are not used in this file

# Dialogue signals (used in dialogue files)
@warning_ignore("unused_signal")
signal first_drag_on_object
@warning_ignore("unused_signal")
signal first_rotate_on_object
@warning_ignore("unused_signal")
signal first_sticker_cleansed_on_object
@warning_ignore("unused_signal")
signal object_completed


@warning_ignore("unused_signal")
signal dialogue_mutation_completed

func wait_for(signal_name: String) -> void:
	if not has_signal(signal_name):
		Utils.debug_error("GameState: No valid signal with name: " + signal_name)
		return
	await self [signal_name]