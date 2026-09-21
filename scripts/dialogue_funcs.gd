# Contains functionality that is available to use in dialogue files
extends Node

var game_manager: GameManager = null
func register_game_manager(gm: GameManager):
	game_manager = gm

var ui_manager: UIManager = null
func register_ui_manager(um: UIManager):
	ui_manager = um

#region Dialogue Functions

func add_object_to_workbench(object_name: String):
	if game_manager == null:
		Utils.debug_error("DialogueFuncs: Game manager not registered! Cannot add object to workbench. Inform Prog team of error!")
		return

	game_manager.dialogue_add_object_to_workbench(object_name)

## Plays an SFX by name. 
## [param volume_offset_db] nudges this one playback louder/quieter than the sound's configured base volume. Use this sparingly.
## If a sound should sound different every time it plays, change its volume in res://data/audio/sfx_config.tres instead.
func play_sfx(sfx_name: String, volume_offset_db: float = 0.0):
	AudioManager.play_sfx(sfx_name, volume_offset_db)

## Pause the dialogue to play an SFX. Resume when SFX finishes playing. 
## If [param transition_to_black] is true, the screen will fade to black before playing the SFX, and fade back in after the SFX finishes playing.
## !!! WARNING !!! Only call at the start of a dialogue line, before any text is displayed. 
## Otherwise, bugs are introduced if player rapidly clicks to advance dialogue.
func play_sfx_and_wait(sfx_name: String, volume_offset_db: float = 0.0, transition_to_black: bool = false) -> void:
	assert(ui_manager != null, "DialogueFuncs:play_sfx_and_wait UI manager not registered!")

	if transition_to_black:
		await ui_manager.fade_to_black(ui_manager._SCREEN_FADE_DURATION_DIALOGUE_SFX)
	
	await AudioManager.play_sfx_and_wait(sfx_name, volume_offset_db)

	if transition_to_black:
		await ui_manager.fade_from_black(ui_manager._SCREEN_FADE_DURATION_DIALOGUE_SFX)

## Returns number of objects in the workbench that still need to be cleansed / completed
func get_object_count() -> int:
	if game_manager == null:
		Utils.debug_error("DialogueFuncs: Game manager not registered! Cannot get object count. Inform Prog team of error!")
		return -1

	return game_manager.dialogue_get_object_count()

## Makes characters present in the scene leave the scene simultaneously
## Call the function like this: [do! DialogueFuncs.exit_characters(["Micah", "Sarah"])]
func exit_characters(display_names: Array):
	if game_manager == null:
		Utils.debug_error("DialogueFuncs: Game manager not registered! Cannot exit characters. Inform Prog team of error!")
		return

	game_manager.dialogue_exit_characters(display_names)

## Immediately kills the player, bypassing the normal life-loss flow.
## Call the function like this: [do! DialogueFuncs.kill_player()]
func kill_player():
	if game_manager == null:
		Utils.debug_error("DialogueFuncs: Game manager not registered! Cannot kill player. Inform Prog team of error!")
		return

	game_manager.dialogue_kill_player()

## Returns false is the object is not special or if the object has not been completed
func has_completed_special_object(object_name: String) -> bool:
	return Variables.has(Config.SCORE_SPECIAL_OBJECT_VAR_KEY_PREFIX + object_name)
	
#endregion
