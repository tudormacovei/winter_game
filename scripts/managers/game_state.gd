extends Node

@onready var game_manager: GameManager = null
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

# Emitted when:
# - dialogue starts typing after a pause
# - dialogue progress indicator becomes visible
@warning_ignore("unused_signal")
signal dialogue_changed

@warning_ignore("unused_signal")
signal day_ended(day_index: int)
@warning_ignore("unused_signal")
signal day_started(day_index: int)

@warning_ignore("unused_signal")
signal player_died

@warning_ignore("unused_signal")
signal life_lost

@warning_ignore("unused_signal")
signal day_end_screen_shown

@warning_ignore("unused_signal")
signal new_object_on_workbench

# A push of air in the room that moves the candle flames. The Wind node holds the push and duration of each kind
@warning_ignore("unused_signal")
signal add_wind_gust(kind: Wind.GustKind)

func wait_for(signal_name: String) -> void:
	if not has_signal(signal_name):
		Utils.debug_error("GameState: No valid signal with name: " + signal_name)
		return
	await self[signal_name]

func do_scripted_event(event_name: String) -> void:
	self.call(event_name)

#region Scripted Events 

# NOTE: If more scripted events are needed, a better system should be implemented to handle them
var is_tutorial_find_workbench_enabled: bool = false

func start_find_workbench_tutorial() -> void:
	if not ui_manager:
		Utils.debug_error("GameState:start_find_workbench_tutorial UIManager is not set!")
		return

	is_tutorial_find_workbench_enabled = true
	ui_manager.show_screen_highlight()

func stop_find_workbench_tutorial() -> void:
	is_tutorial_find_workbench_enabled = false
	ui_manager.hide_screen_highlight()

# Pulse object with a delay until the player focuses on it. If the player focuses on it before the delay, the pulse will not occur.
var was_object_focused: bool = false
var is_object_pulse_active: bool = false
func start_focus_object_tutorial() -> void:
	var DELAY_SECONDS = 15.0
	var workbench: Workbench = game_manager.workbench
	if not workbench:
		Utils.debug_error("GameState:start_focus_object_tutorial Workbench is not set!")
		return

	var object = workbench.get_first_object()
	if object == null:
		Utils.debug_alert("GameState:start_focus_object_tutorial No first object found on workbench!")
		return

	if object.get_state() != InteractibleObject.State.ON_TABLE and object.get_state() != InteractibleObject.State.DRAGGING:
		Utils.debug_alert("GameState:start_focus_object_tutorial Object is not on table! Cancelling pulse.")
		return

	was_object_focused = false
	is_object_pulse_active = false
	object.object_state_changed.connect(Callable(self, "_helper_on_object_focus_for_pulse").bind(object), CONNECT_PERSIST)

	await get_tree().create_timer(DELAY_SECONDS).timeout

	if was_object_focused:
		return # Player already focused on the object, no need to start the pulse

	if is_instance_valid(object):
		is_object_pulse_active = true
		object.start_outline_scale_pulse()

func _helper_on_object_focus_for_pulse(new_state: InteractibleObject.State, object: InteractibleObject) -> void:
	if not is_instance_valid(object):
		return

	if new_state == InteractibleObject.State.FOCUSED:
		was_object_focused = true

		if is_object_pulse_active:
			is_object_pulse_active = false
			object.end_outline_scale_pulse()
		
		object.object_state_changed.disconnect(Callable(self, "_helper_on_object_focus_for_pulse").bind(object))

#endregion

#region Lock Player Actions

var is_player_input_locked: bool = false

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
