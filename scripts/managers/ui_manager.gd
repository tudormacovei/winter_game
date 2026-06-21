# Responsible for managing UI elements and their transitions
# For now, manages behaviour of dialogue balloon
class_name UIManager
extends Node

@onready var camera: CameraControl = %Camera3D

# UI Elements
@onready var _day_end_screen := %DayEndScreen
@onready var _day_end_screen_label: Label = %DayEndScreen.get_node("%DayCompleteText")
# @onready var _dialogue_view := %DialogueView NOTE: This is not used anymore
@onready var _dialogue_state_balloon: CanvasLayer = %DialogueStateBalloon

var balloon_layer: CanvasLayer = null

# TODO: Show dialogue state bubble when in workspace view

func _ready() -> void:
	if camera and camera.has_signal("camera_focus_changed"):
		camera.connect("camera_focus_changed", Callable(self , "_on_camera_focus_changed"))
	if camera and camera.has_signal("camera_rotation_completed"):
		camera.connect("camera_rotation_completed", Callable(self , "_on_camera_rotation_completed"))

	if GameState and GameState.has_signal("dialogue_mutation_completed"):
		GameState.connect("dialogue_mutation_completed", Callable(self , "_on_dialogue_mutation_completed"))

func set_balloon_layer(new_balloon_layer: CanvasLayer):
	self.balloon_layer = new_balloon_layer

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

#region Signals

func _on_camera_focus_changed(current_focus) -> void:
	CursorManager.clear_requests()
	CursorManager.refresh()
	
	if current_focus == CameraControl.CameraFocus.WORK_AREA:
		hide_balloon_layer()
	
	if _dialogue_state_balloon and current_focus == CameraControl.CameraFocus.DIALOGUE_AREA:
		_dialogue_state_balloon.hide()

func _on_camera_rotation_completed(current_focus) -> void:
	if balloon_layer and current_focus == CameraControl.CameraFocus.DIALOGUE_AREA:
		balloon_layer.balloon.show()

# Emitted when a dialogue mutation finishes its awaiting
func _on_dialogue_mutation_completed() -> void:
	if _dialogue_state_balloon and camera._camera_focus != CameraControl.CameraFocus.DIALOGUE_AREA:
		_dialogue_state_balloon.show_state_balloon()
#endregion

#region Debug

func debug_hide_game_end_screen():
	_day_end_screen.hide()

#endregion
