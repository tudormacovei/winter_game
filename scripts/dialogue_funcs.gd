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

## Returns number of objects in the workbench that still need to be cleansed / completed
func get_object_count() -> int:
	if game_manager == null:
		Utils.debug_error("DialogueFuncs: Game manager not registered! Cannot get object count. Inform Prog team of error!")
		return -1

	return game_manager.dialogue_get_object_count()

func play_sfx(sfx_name: String, volume_db: float = 0.0):
	AudioManager.play_sfx(sfx_name, volume_db)

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
