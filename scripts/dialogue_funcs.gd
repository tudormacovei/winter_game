# Contains functionality that is available to use in dialogue files
extends Node

var game_manager: GameManager = null
func register_game_manager(gm: GameManager):
	game_manager = gm

var audio_manager: AudioManager = null
func register_audio_manager(am: AudioManager):
	audio_manager = am

#region Dialogue Functions

func add_object_to_workbench(object_name: String):
	if game_manager == null:
		Utils.debug_error("DialogueFuncs: Game manager not registered! Cannot add object to workbench. Inform Prog team of error!")
		return

	game_manager.dialogue_add_object_to_workbench(object_name)

func play_sfx(sfx_name: String):
	if audio_manager == null:
		Utils.debug_error("DialogueFuncs: Audio manager not registered! Cannot play SFX. Inform Prog team of error!")
		return
		
	audio_manager.play_sfx(sfx_name)
	
#endregion
