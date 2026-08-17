# Responsible for managing UI elements and their transitions
# For now, manages behaviour of dialogue balloon
class_name UIManager
extends Node

@onready var camera: CameraControl = %Camera3D

# UI Elements
@onready var _day_end_controller := %DayEndScreen
@onready var _death_screen := %DeathScreen
@onready var _death_screen_label: Label = %DeathScreen.get_node("%DeathText")
@onready var _game_state_ui: CanvasLayer = %GameStateUI
@onready var _workbench: Workbench = %WorkbenchView
@onready var _focus_blink: FocusBlink = %FocusBlinkRectangle
@onready var _health_overlay: HealthOverlay = %HealthOverlay

@onready var screen_fade_canvas: CanvasLayer = %ScreenFadeCanvas
@onready var screen_fade_rect: ColorRect = %ScreenFadeColorRect

var balloon_layer: CanvasLayer = null

func _ready() -> void:
	assert(_focus_blink != null, "UIManager requires the FocusBlink.")
	assert(_health_overlay != null, "UIManager requires the HealthOverlay.")
	_focus_blink.blink_closed.connect(_on_blink_closed)
	_health_overlay.hide()

	if camera and camera.has_signal("camera_focus_changed"):
		camera.connect("camera_focus_changed", Callable(self, "_on_camera_focus_changed"))
	if camera and camera.has_signal("camera_rotation_completed"):
		camera.connect("camera_rotation_completed", Callable(self, "_on_camera_rotation_completed"))
	if _workbench:
		_workbench.object_focus_changed.connect(_on_object_focus_changed)

	GameState.ui_manager = self
	if GameState.has_signal("dialogue_changed"):
		GameState.connect("dialogue_changed", Callable(self, "_on_dialogue_changed"))
	if GameState.has_signal("new_object_on_workbench"):
		GameState.connect("new_object_on_workbench", Callable(self, "_on_new_object_on_workbench"))
	if GameState.has_signal("day_ended"):
		GameState.connect("day_ended", Callable(self, "_on_day_ended"))
	if OS.is_debug_build():
		DebugUI.register_debug_target(self)

func set_balloon_layer(new_balloon_layer: CanvasLayer):
	self.balloon_layer = new_balloon_layer

	# Don't show Dialogue UI in workbench, instead show Dialogue State UI
	if camera._camera_focus != CameraControl.CameraFocus.DIALOGUE_AREA:
		call_deferred("hide_balloon_layer")
		if _game_state_ui:
			_game_state_ui.show_game_state_ui(_game_state_ui.GameStateUIType.DIALOGUE)

func show_day_end_screen(day_definition: DayDefintion) -> void:
	await fade_to_black()
	_day_end_controller.set_text(day_definition)
	_day_end_controller.show()
	await fade_from_black()

	AudioManager.play_sfx(Config.END_DAY_SFX_NAME, Config.END_DAY_SFX_VOLUME_DB)
	
	await get_tree().create_timer(Config.DAY_END_SCREEN_SHOW_TIME_SECONDS).timeout
	
	await fade_to_black()
	_day_end_controller.hide()
	await fade_from_black()

func show_death_screen() -> void:
	if _game_state_ui:
		_game_state_ui.hide_all_game_state_ui()

	hide_balloon_layer()
	
	await fade_to_black(_SCREEN_FADE_TO_DURATION_DEATH)
	_death_screen_label.text = Config.DEATH_SCREEN_MESSAGE
	_death_screen.show()
	await fade_from_black()

func show_game_end_screen() -> void:
	await fade_to_black(_SCREEN_FADE_DURATION_GAME_END)
	_day_end_controller.set_game_end_text()
	_day_end_controller.show()
	await fade_from_black(_SCREEN_FADE_DURATION_GAME_END)

func hide_balloon_layer() -> void:
	if balloon_layer and balloon_layer.balloon:
		# NOTE: It's important that we specifically show / hide the balloon_layer.balloon variable instead of 
		# the entire balloon_layer, so that the input events are propagated correctly based on logic in dialogue balloon script
		balloon_layer.balloon.hide()
	else:
		push_warning("UI Manager: Trying to hide invalid balloon layer or balloon.")

func try_show_object_state_ui(delay: float = 0.0) -> void:
	if not _game_state_ui:
		return

	if camera._camera_focus != CameraControl.CameraFocus.DIALOGUE_AREA:
		return

	if delay > 0.0:
		await get_tree().create_timer(delay).timeout

	if camera._camera_focus != CameraControl.CameraFocus.DIALOGUE_AREA:
		return

	_game_state_ui.show_game_state_ui(_game_state_ui.GameStateUIType.OBJECT)

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

#region Screen Fade

const _SCREEN_FADE_DURATION = 0.3
const _SCREEN_FADE_TO_DURATION_DEATH = 2.0
const _SCREEN_FADE_DURATION_GAME_END = 2
const _SCREEN_FADE_DURATION_INTERACTION_CONFIGS = 0.8
var _screen_fade_tween: Tween = null

func fade_to_black(duration: float = _SCREEN_FADE_DURATION) -> void:
	if not screen_fade_canvas or not screen_fade_rect:
		Utils.debug_error("UIManager:fade_to_black screen fade UI elements are null!")
		return

	_set_screen_fade_alpha(0.0)
	screen_fade_canvas.show()
	if duration <= 0.0:
		return

	if _screen_fade_tween:
		_screen_fade_tween.kill()
	_screen_fade_tween = create_tween()
	_screen_fade_tween.tween_method(
		func(t: float) -> void: _set_screen_fade_alpha(t),
		0.0, 1.0, duration
	)

	await _screen_fade_tween.finished

func fade_from_black(duration: float = _SCREEN_FADE_DURATION) -> void:
	if not screen_fade_canvas or not screen_fade_rect:
		Utils.debug_error("UIManager:fade_from_black screen fade UI elements are null!")
		return

	if _screen_fade_tween:
		_screen_fade_tween.kill()
	_screen_fade_tween = create_tween()
	_screen_fade_tween.tween_method(
		func(t: float) -> void: _set_screen_fade_alpha(t),
		1.0, 0.0, duration
	)

	await _screen_fade_tween.finished
	screen_fade_canvas.hide()

func _set_screen_fade_alpha(alpha: float) -> void:
	if not screen_fade_rect:
		Utils.debug_error("UIManager:_set_screen_fade_alpha screen fade rect is null!")
		return

	screen_fade_rect.color.a = alpha

#endregion

#region Signals

func _on_camera_focus_changed(current_focus) -> void:
	CursorManager.clear_requests()
	CursorManager.refresh()
	
	if current_focus == CameraControl.CameraFocus.WORK_AREA:
		hide_balloon_layer()
	
	if _game_state_ui:
		if current_focus == CameraControl.CameraFocus.DIALOGUE_AREA:
			_game_state_ui.hide_game_state_ui(_game_state_ui.GameStateUIType.DIALOGUE)
		else:
			_game_state_ui.hide_game_state_ui(_game_state_ui.GameStateUIType.OBJECT)

	show_screen_highlight()

func _on_camera_rotation_completed(current_focus) -> void:
	if balloon_layer and current_focus == CameraControl.CameraFocus.DIALOGUE_AREA:
		balloon_layer.balloon.show()

func _on_dialogue_changed() -> void:
	if _game_state_ui and camera._camera_focus != CameraControl.CameraFocus.DIALOGUE_AREA:
		_game_state_ui.show_game_state_ui(_game_state_ui.GameStateUIType.DIALOGUE)

func _on_new_object_on_workbench() -> void:
	try_show_object_state_ui()

func _on_day_ended(day_index: int) -> void:
	_game_state_ui.hide_all_game_state_ui()
	
func _on_object_focus_changed(is_focused: bool) -> void:
	if _focus_blink:
		_focus_blink.blink_once(is_focused)


func _on_blink_closed(is_focused: bool) -> void:
	if is_focused:
		_health_overlay.show()
	else:
		_health_overlay.hide()


#endregion

#region Debug

func debug_hide_game_end_screen():
	_day_end_controller.hide()

#endregion
