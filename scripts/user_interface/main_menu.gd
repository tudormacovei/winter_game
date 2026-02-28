extends Node

var main_scene: PackedScene = preload("res://scenes/main_game_view/workspace.tscn")

@onready var settings_panel: VBoxContainer = %Settings
@onready var settings_button: Button = %SettingsButton
@onready var start_button: Button = %StartGameButton
@onready var exit_button: Button = %ExitGameButton

func _ready() -> void:
	settings_panel.visible = false
	settings_button.pressed.connect(_on_settings_pressed)
	start_button.pressed.connect(_on_start_pressed)
	exit_button.pressed.connect(_on_exit_pressed)
	CursorManager.register_controls([start_button, settings_button, exit_button])


func _on_settings_pressed() -> void:
	settings_panel.visible = !settings_panel.visible


func _on_start_pressed() -> void:
	if main_scene:
		# TODO: This should be a general function in game manager.
		Variables.reset()
		get_tree().change_scene_to_packed(main_scene)
	else:
		push_warning("MainMenu: main_scene is not set.")


func _on_exit_pressed() -> void:
	get_tree().quit()
