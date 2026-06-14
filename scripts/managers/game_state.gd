extends Node

@onready var ui_manager: UIManager = null

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

func do_scripted_event(event_name: String) -> void:
	self.call(event_name)

#region Scripted Events 

# NOTE: If more scripted events are needed, a better system should be implemented to handle them
var is_tutorial_find_quarantine_enabled: bool = false

func start_find_quarantine_tutorial() -> void:
	if not ui_manager:
		Utils.debug_error("GameState:start_find_quarantine_tutorial UIManager is not set!")
		return

	is_tutorial_find_quarantine_enabled = true
	ui_manager.show_screen_highlight()

func stop_find_quarantine_tutorial() -> void:
	is_tutorial_find_quarantine_enabled = false
	ui_manager.hide_screen_highlight()

#endregion

#region Lock Player Actions

enum ActionName {
	FOCUS_OBJECT,
	COMPLETE_STICKER,
	COMPLETE_OBJECT,
}

static var STRING_TO_ACTION_NAME_MAP = {
	"focus_object": ActionName.FOCUS_OBJECT,
	"complete_sticker": ActionName.COMPLETE_STICKER,
	"complete_object": ActionName.COMPLETE_OBJECT,
}

var is_action_locked: Dictionary = {
	ActionName.FOCUS_OBJECT: false,
	ActionName.COMPLETE_STICKER: false,
	ActionName.COMPLETE_OBJECT: false,
}

## Lock or unlock specific player actions [br]
## [param action_name] "focus_object", "complete_sticker", or "complete_object" (synced with GameState.STRING_TO_ACTION_NAME_MAP) [br]
## [param locked] true to lock, false to unlock
func lock_player_action(action_name: String, locked: bool) -> void:
	var workbench: Workbench = get_tree().current_scene.find_child("WorkbenchView", true, false) as Workbench
	if not workbench:
		Utils.debug_error("GameState: Could not find Workbench in current scene")
		return
	
	is_action_locked[STRING_TO_ACTION_NAME_MAP[action_name]] = locked

#endregion