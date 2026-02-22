# Responsible for managing UI elements and their transitions
# For now, manages behaviour of dialogue balloon
class_name UIManager
extends Node

@onready var camera: CameraControl = %Camera3D

# UI Elements
@onready var _day_end_screen := %DayEndScreen
@onready var _day_end_screen_label: Label = %DayCompleteText

var balloon_layer: CanvasLayer = null

# TODO: Show dialogue state bubble when in workspace view

func _ready() -> void:
	if camera and camera.has_signal("camera_focus_changed"):
		camera.connect("camera_focus_changed", Callable(self , "_on_camera_focus_changed"))
	set_cursor(CursorType.DEFAULT)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				set_cursor(CursorType.GRAB)
			else:
				set_cursor(CursorType.DEFAULT)

func show_day_end_screen(day_number: int) -> void:
	_day_end_screen_label.text = Config.DAY_END_SCREEN_MESSAGE % day_number

	_day_end_screen.show()
	await get_tree().create_timer(Config.DAY_END_SCREEN_SHOW_TIME_SECONDS).timeout
	_day_end_screen.hide()

func show_game_end_screen() -> void:
	_day_end_screen_label.text = Config.GAME_END_SCREEN_MESSAGE
	_day_end_screen.show()

#region Mouse Cursor

enum CursorType {
	DEFAULT,
	HOVER,
	GRAB
}

@export var cursor_default: Texture2D
@export var cursor_hover: Texture2D
@export var cursor_grab: Texture2D

const CURSOR_OFFSET: Vector2 = Vector2(7, 7)

func set_cursor(cursor_type: CursorType) -> void:
	var texture: Texture2D
	match cursor_type:
		CursorType.DEFAULT:
			texture = cursor_default
		CursorType.HOVER:
			texture = cursor_hover
		CursorType.GRAB:
			texture = cursor_grab
	
	if texture:
		Input.set_custom_mouse_cursor(texture, Input.CURSOR_ARROW, CURSOR_OFFSET)
	else:
		push_error("UIManager: No texture assigned for CursorType." + CursorType.keys()[cursor_type])

#endregion

#region Signals

func _on_camera_focus_changed(current_focus) -> void:
	if not balloon_layer:
		return

	# NOTE: It's important that we specifically show / hide the balloon_layer.balloon variable instead of 
	# the entire balloon_layer, so that the input events are propagated correctly based on logic in dialogue balloon script
	if current_focus == CameraControl.CameraFocus.WORK_AREA:
		balloon_layer.balloon.hide()
	elif current_focus == CameraControl.CameraFocus.DIALOGUE_AREA:
		# Delay showing the ballon until the camera rotation is complete
		await get_tree().create_timer(camera.ANIMATION_TIME).timeout
		balloon_layer.balloon.show()
		
#endregion

#region Debug

func debug_hide_game_end_screen():
	_day_end_screen.hide()

#endregion
