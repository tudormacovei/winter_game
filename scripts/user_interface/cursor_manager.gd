## Manages the mouse cursor appearance throughout the game.
## Registered as an AutoLoad
extends Node

enum CursorType {
	DEFAULT,
	HOVER,
	GRAB
}

var cursor_default: Texture2D = preload("res://2d_assets/hand cursor/handopen.webp")
var cursor_hover: Texture2D = preload("res://2d_assets/hand cursor/handopen.webp")
var cursor_grab: Texture2D = preload("res://2d_assets/hand cursor/handclosed.webp")

const CURSOR_OFFSET: Vector2 = Vector2(7, 7)

func _ready() -> void:
	set_cursor(CursorType.DEFAULT)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				set_cursor(CursorType.GRAB)
			else:
				set_cursor(CursorType.DEFAULT)

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
		push_error("CursorManager: No texture assigned for CursorType." + CursorType.keys()[cursor_type])
