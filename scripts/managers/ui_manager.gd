# Responsible for managing UI elements and their transitions
# For now, manages behaviour of dialogue balloon
class_name UIManager
extends Node

@onready var camera: CameraControl = %Camera3D
@onready var health_manager: HealthManager = %HealthManager

# UI Elements
@onready var _day_end_screen := %DayEndScreen
@onready var _death_screen := %DeathScreen
@onready var _day_end_screen_label: Label = %DayEndScreen.get_node("%DayCompleteText")
@onready var _death_screen_label: Label = %DeathScreen.get_node("%DeathText")
# @onready var _dialogue_view := %DialogueView NOTE: This is not used anymore
@onready var _dialogue_state_balloon: CanvasLayer = %DialogueStateBalloon

var balloon_layer: CanvasLayer = null

# TODO: Show dialogue state bubble when in workspace view

func _ready() -> void:
	if camera and camera.has_signal("camera_focus_changed"):
		camera.connect("camera_focus_changed", Callable(self , "_on_camera_focus_changed"))
	if camera and camera.has_signal("camera_rotation_completed"):
		camera.connect("camera_rotation_completed", Callable(self , "_on_camera_rotation_completed"))
	if GameState.has_signal("player_died"):
		GameState.connect("player_died", Callable(self , "show_death_screen"))

	GameState.ui_manager = self
	if GameState.has_signal("dialogue_changed"):
		GameState.connect("dialogue_changed", Callable(self , "_on_dialogue_changed"))
	
	if OS.is_debug_build():
		DebugUI.register_debug_target(self)

func set_balloon_layer(new_balloon_layer: CanvasLayer):
	self.balloon_layer = new_balloon_layer

	# Don't show Dialogue UI in workbench, instead show Dialogue State UI
	if camera._camera_focus == CameraControl.CameraFocus.WORK_AREA:
		call_deferred("hide_balloon_layer")
		if _dialogue_state_balloon:
			_dialogue_state_balloon.show_state_balloon()

func show_day_end_screen(day_number: int) -> void:
	_day_end_screen_label.text = Config.DAY_END_SCREEN_MESSAGE % day_number
	_day_end_screen.show()
	AudioManager.play_sfx(Config.END_DAY_SFX_NAME, Config.END_DAY_SFX_VOLUME_DB)
	await get_tree().create_timer(Config.DAY_END_SCREEN_SHOW_TIME_SECONDS).timeout
	_day_end_screen.hide()

func show_death_screen() -> void:
	if not debug_disable_death_screen:
		_death_screen_label.text = Config.DEATH_SCREEN_MESSAGE
		_death_screen.show()
		get_tree().paused = true

func show_game_end_screen() -> void:
	_day_end_screen_label.text = Config.GAME_END_SCREEN_MESSAGE
	_day_end_screen.show()

func hide_balloon_layer() -> void:
	if balloon_layer and balloon_layer.balloon:
		# NOTE: It's important that we specifically show / hide the balloon_layer.balloon variable instead of 
		# the entire balloon_layer, so that the input events are propagated correctly based on logic in dialogue balloon script
		balloon_layer.balloon.hide()
	else:
		push_warning("UI Manager: Trying to hide invalid balloon layer or balloon.")

#region Screen Highlight

const _SCREEN_HIGHLIGHT_FADE_DURATION = 2.0
var _screen_highlight_tween: Tween = null

# NOTE: These values must match the values in the shader
enum ScreenHighlightEdge {
	NONE = 0,
	TOP = 1,
	BOTTOM = 2,
	LEFT = 4,
	RIGHT = 8,
}

func show_screen_highlight() -> void:
	var screen_highlight_canvas: CanvasLayer = %ScreenHighlightCanvas
	var screen_highlight_rect: ColorRect = %ScreenHighlightColorRect
	if not screen_highlight_canvas or not screen_highlight_rect:
		Utils.debug_error("UIManager:show_screen_highlight Screen highlight UI elements are null!")
		return

	var mat = screen_highlight_rect.material as ShaderMaterial
	mat.set_shader_parameter("edges_enabled_mask", get_current_screen_highlight_mask())
	
	# Fade in the screen highlight, so that it doesn't look too jarring
	if _screen_highlight_tween:
		_screen_highlight_tween.kill()
	_screen_highlight_tween = create_tween()
	_screen_highlight_tween.tween_method(
		func(t: float) -> void: %ScreenHighlightColorRect.material.set_shader_parameter("_fade_progress", t),
		0.0, 1.0, _SCREEN_HIGHLIGHT_FADE_DURATION
	)

	screen_highlight_canvas.show()

func hide_screen_highlight() -> void:
	var screen_highlight_canvas: CanvasLayer = %ScreenHighlightCanvas
	if not screen_highlight_canvas:
		Utils.debug_error("UIManager:hide_screen_highlight Screen highlight canvas is null!")
		return

	screen_highlight_canvas.hide()

func get_current_screen_highlight_mask() -> int:
	# For now, edge highlighting is only enabled for finding the quarantine during tutorial
	# This can be expanded in the future for other use cases 
	if not GameState.is_tutorial_find_quarantine_enabled:
		return ScreenHighlightEdge.NONE
	
	if camera._camera_focus == CameraControl.CameraFocus.DIALOGUE_AREA:
		return ScreenHighlightEdge.BOTTOM
	
	if camera._camera_focus == CameraControl.CameraFocus.WORK_AREA:
		return ScreenHighlightEdge.LEFT
		
	return ScreenHighlightEdge.NONE

#endregion


#region Signals

func _on_camera_focus_changed(current_focus) -> void:
	CursorManager.clear_requests()
	CursorManager.refresh()
	
	if current_focus == CameraControl.CameraFocus.WORK_AREA:
		hide_balloon_layer()
	
	if _dialogue_state_balloon and current_focus == CameraControl.CameraFocus.DIALOGUE_AREA:
		_dialogue_state_balloon.hide()

	show_screen_highlight()

func _on_camera_rotation_completed(current_focus) -> void:
	if balloon_layer and current_focus == CameraControl.CameraFocus.DIALOGUE_AREA:
		balloon_layer.balloon.show()

func _on_dialogue_changed() -> void:
	if _dialogue_state_balloon and camera._camera_focus != CameraControl.CameraFocus.DIALOGUE_AREA:
		_dialogue_state_balloon.show_state_balloon()

#endregion

#region Debug
var debug_disable_death_screen: bool = false

func debug_hide_game_end_screen():
	_day_end_screen.hide()

#endregion
