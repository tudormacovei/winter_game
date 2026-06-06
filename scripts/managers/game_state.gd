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

## Lock or unlock specific player actions [br]
## [param action_name] "focus_object", "complete_sticker", or "complete_object" (synced with InteractibleObject.STRING_TO_ACTION_NAME_MAP) [br]
## [param locked] true to lock, false to unlock
func lock_player_action(action_name: String, locked: bool) -> void:
	var workbench: Workbench = get_tree().current_scene.find_child("WorkbenchView", true, false) as Workbench
	if not workbench:
		Utils.debug_error("GameState: Could not find Workbench in current scene")
		return
	
	for slot in workbench.object_slots:
		for child in slot.get_children():
			var interactible: InteractibleObject = child as InteractibleObject
			if is_instance_valid(interactible):
				interactible.lock_player_action(action_name, locked)