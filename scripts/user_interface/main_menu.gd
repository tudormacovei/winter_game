extends Node

@export var main_scene: PackedScene

@onready var settings_panel: VBoxContainer = %Settings
@onready var settings_button: Button = %SettingsButton
@onready var start_button: Button = %StartGameButton
@onready var exit_button: Button = %ExitGameButton

func _ready() -> void:
	settings_panel.visible = false
	settings_button.pressed.connect(_on_settings_pressed)
	start_button.pressed.connect(_on_start_pressed)
	exit_button.pressed.connect(_on_exit_pressed)


func _on_settings_pressed() -> void:
	settings_panel.visible = !settings_panel.visible


func _on_start_pressed() -> void:
	if main_scene:
		get_tree().change_scene_to_packed(main_scene)
	else:
		push_warning("MainMenu: main_scene is not set.")


func _on_exit_pressed() -> void:
	get_tree().quit()
