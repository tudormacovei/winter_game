extends Node

var main_scene: PackedScene = null

@onready var continue_button: Button = %ContinueGameButton

func _ready() -> void:
	main_scene = load("res://scenes/main_game_view/workspace.tscn")

	# NOTE: continue_button.process_mode is set to PROCESS_MODE_ALWAYS, so that it can be pressed even when the game is paused
	continue_button.pressed.connect(_on_continue_pressed)
	
	CursorManager.register_controls([continue_button])

func _on_continue_pressed() -> void:
	if main_scene:
		if SaveManager.load_game():
			get_tree().change_scene_to_packed(main_scene)
		else:
			Utils.debug_error("DeathScreen: Pressed continue button with no save data found.")
	else:
		Utils.debug_error("DeathScreen: main_scene is not set.")
