# Contains functionality that is available to use in dialogue files
extends Node

var game_manager: GameManager = null
func register_game_manager(gm: GameManager):
	game_manager = gm

#region Dialogue Functions

func add_object_to_workbench(object_name: String):
	if game_manager == null:
		Utils.debug_error("DialogueFuncs: Game manager not registered! Cannot add object to workbench. Inform Prog team of error!")
		return

	game_manager.dialogue_add_object_to_workbench(object_name)

## Plays an SFX by name. [param volume_offset_db] nudges this one playback
## louder/quieter than the sound's configured base volume.
## Use this sparingly - for a rare, one-off dramatic beat only. If a sound
## should sound different every time it plays, change its volume in
## res://data/audio/sfx_config.tres instead, so all SFX stay consistent.
func play_sfx(sfx_name: String, volume_offset_db: float = 0.0):
	AudioManager.play_sfx(sfx_name, volume_offset_db)

## Makes characters present in the scene leave the scene simultaneously
## Call the function like this: [do! DialogueFuncs.exit_characters(["Micah", "Sarah"])]
func exit_characters(display_names: Array):
	if game_manager == null:
		Utils.debug_error("DialogueFuncs: Game manager not registered! Cannot exit characters. Inform Prog team of error!")
		return

	game_manager.dialogue_exit_characters(display_names)

## Returns false is the object is not special or if the object has not been completed
func has_completed_special_object(object_name: String) -> bool:
	return Variables.has(Config.SCORE_SPECIAL_OBJECT_VAR_KEY_PREFIX + object_name)
	
#endregion
