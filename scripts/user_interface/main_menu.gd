extends Node

const ShaderWarmup: GDScript = preload("res://scripts/user_interface/shader_warmup.gd")

var main_scene: PackedScene = preload("res://scenes/main_game_view/workspace.tscn")

@onready var settings_panel: VBoxContainer = %Settings
@onready var settings_button: Button = %SettingsButton
@onready var start_button: Button = %StartGameButton
@onready var continue_button: Button = %ContinueGameButton
@onready var exit_button: Button = %ExitGameButton

func _ready() -> void:
	# NOTE: This prevents hitches in the main scene. In case we need warmup to run for the main menu, we need to think of another solution (for example, a loading screen or a transition)
	var warmup: Node = ShaderWarmup.new()
	add_child(warmup)

	settings_panel.visible = false
	settings_button.pressed.connect(_on_settings_pressed)
	start_button.pressed.connect(_on_start_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	exit_button.pressed.connect(_on_exit_pressed)
	CursorManager.register_controls([start_button, settings_button, continue_button, exit_button])

	continue_button.disabled = not SaveManager.does_save_exist()
	AudioManager.play_ambient_stream(Config.AMBIENT_MAIN_MENU_STREAM_NAME)

	for button in [start_button, continue_button, settings_button, exit_button]:
			button.mouse_entered.connect(_on_button_hover.bind(button, true))
			button.mouse_exited.connect(_on_button_hover.bind(button, false))

func _on_settings_pressed() -> void:
	settings_panel.visible = !settings_panel.visible


func _on_start_pressed() -> void:
	if main_scene:
		# TODO: This should be a general function in game manager.
		Variables.reset()
		SaveManager.reset_save()
		get_tree().change_scene_to_packed(main_scene)
	else:
		push_warning("MainMenu: main_scene is not set.")


func _on_continue_pressed() -> void:
	if main_scene:
		if SaveManager.load_game():
			get_tree().change_scene_to_packed(main_scene)
		else:
			Utils.debug_alert("MainMenu: Pressed continue button with no save data found.")
	else:
		push_warning("MainMenu: main_scene is not set.")

func _on_button_hover(button: Button, is_hovering: bool) -> void:
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUAD)
	
	var target_color = Color(0.6, 0.4, 0.2, 1.0) if is_hovering else Color(0.85, 0.78, 0.6, 1.0)
	var target_scale = Vector2(1.05, 1.05) if is_hovering else Vector2(1.0, 1.0)
	
	tween.tween_property(button, "scale", target_scale, 0.15)
	tween.parallel().tween_property(button, "theme_override_colors/font_color", target_color, 0.2)

func _on_exit_pressed() -> void:
	get_tree().quit()
