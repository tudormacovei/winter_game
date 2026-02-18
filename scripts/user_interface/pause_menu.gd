extends CanvasLayer

var main_menu_scene: PackedScene = load("res://scenes/UI/main_menu.tscn")

@onready var settings_button := %SettingsButton
@onready var exit_to_menu_button := %ExitToMenuButton
@onready var return_to_game_button := %ReturnToGameButton

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	visible = false
	settings_button.pressed.connect(_on_settings_pressed)
	return_to_game_button.pressed.connect(_toggle_pause)
	exit_to_menu_button.pressed.connect(_on_exit_to_menu_pressed)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_pause"):
		_toggle_pause()


func _toggle_pause() -> void:
	# This works because the process mode of the PauseMenu node is set to 'Always'
	# because of that, it will still run (and listen for input events)
	get_tree().paused = !get_tree().paused
	visible = !visible


func _on_exit_to_menu_pressed() -> void:
	if main_menu_scene:
		get_tree().paused = false
		get_tree().change_scene_to_packed(main_menu_scene)
	else:
		push_warning("PauseMenu: main_menu_scene is not set.")


func _on_settings_pressed() ->void:
	%Settings.visible = !%Settings.visible
