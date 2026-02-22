## Manages the mouse cursor appearance throughout the game.
## Registered as an AutoLoad
extends Node

enum CursorType {
	DEFAULT,
	HOVER, # should be active whenever left-clicking will have an effect (UI/object/sticker/..)
	GRAB
}

var cursor_default: Texture2D = preload("res://2d_assets/hand cursor/hand_open.webp")
var cursor_hover: Texture2D = preload("res://2d_assets/hand cursor/hand_hovering.webp")
var cursor_grab: Texture2D = preload("res://2d_assets/hand cursor/hand_closed.webp")

const CURSOR_OFFSET: Vector2 = Vector2(7, 7)

var _locked := false
var _desired_cursor: CursorType = CursorType.DEFAULT

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_cursor(CursorType.DEFAULT)

func _input(event: InputEvent) -> void:
	if _locked:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				#print("UNHANDLED INPUT, setting cursor type to GRAB")
				set_cursor(CursorType.GRAB)
			else:
				#print("UNHANDLED INPUT, setting cursor type to DEFAULT")
				set_cursor(CursorType.DEFAULT)

## Connects mouse_entered/exited on the given controls to show HOVER/DEFAULT cursor.
func register_controls(controls: Array) -> void:
	for control: Control in controls:
		control.mouse_entered.connect(func(): set_cursor(CursorType.HOVER))
		control.mouse_exited.connect(func():
			if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
				set_cursor(CursorType.DEFAULT))

## Lock the cursor to a specific type. All set_cursor calls are ignored until unlock_cursor().
func lock_cursor(cursor_type: CursorType) -> void:
	_locked = true
	_apply_cursor(cursor_type)

func unlock_cursor() -> void:
	_locked = false
	set_cursor(_desired_cursor)

func set_cursor(cursor_type: CursorType) -> void:
	_desired_cursor = cursor_type
	print("Desired cursor: " + str(_desired_cursor))
	if _locked:
		return
	_apply_cursor(cursor_type)

## Re-evaluate what's under the cursor by injecting a mouse motion event.
## Call after content moves under a stationary cursor (camera pan, rotation end, etc.)
func refresh() -> void:
	var event := InputEventMouseMotion.new()
	event.position = get_viewport().get_mouse_position()
	event.global_position = event.position
	Input.parse_input_event(event)

func _apply_cursor(cursor_type: CursorType) -> void:
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
