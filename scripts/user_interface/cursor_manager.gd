## Manages the mouse cursor appearance throughout the game.
## Registered as an AutoLoad.
## Cursor state is determined by a priority queue: the highest priority active request wins.
## Priority order (highest to lowest): GRAB > HOVER > DEFAULT
extends Node

enum CursorType {
	DEFAULT = 0,
	HOVER = 1,
	GRAB = 2
}

var cursor_default: Texture2D = preload("res://2d_assets/hand cursor/hand_open.webp")
var cursor_hover: Texture2D = preload("res://2d_assets/hand cursor/hand_hovering.webp")
var cursor_grab: Texture2D = preload("res://2d_assets/hand cursor/hand_closed.webp")

const CURSOR_OFFSET: Vector2 = Vector2(7, 7)

# Tracks how many active requests exist for each cursor type
var _requests: Dictionary = {
	CursorType.DEFAULT: 1, # DEFAULT always has a baseline request
	CursorType.HOVER: 0,
	CursorType.GRAB: 0
}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_apply_highest()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				request_cursor(CursorType.GRAB)
			else:
				release_cursor(CursorType.GRAB)

## Add a cursor request. The highest priority active request will be displayed.
func request_cursor(cursor_type: CursorType) -> void:
	_requests[cursor_type] += 1
	_apply_highest()

## Remove a cursor request. Automatically falls back to next highest active request.
func release_cursor(cursor_type: CursorType) -> void:
	if _requests[cursor_type] <= 0:
		push_warning("CursorManager: Tried to release a cursor request that was never made: " + CursorType.keys()[cursor_type])
		return
	_requests[cursor_type] -= 1
	_apply_highest()

## Connects mouse_entered/exited on the given controls to show HOVER/DEFAULT cursor.
func register_controls(controls: Array) -> void:
	for control: Control in controls:
		control.mouse_entered.connect(func(): request_cursor(CursorType.HOVER))
		control.mouse_exited.connect(func(): release_cursor(CursorType.HOVER))

## Clears all requests except the DEFAULT baseline.
func clear_requests() -> void:
	for key in _requests:
		_requests[key] = 0
	_requests[CursorType.DEFAULT] = 1
	_apply_highest()

## Re-evaluate what's under the cursor by injecting a mouse motion event.
## Call after content moves under a stationary cursor (camera pan, rotation end, etc.)
func refresh() -> void:
	get_viewport().set_input_as_handled()
	var event := InputEventMouseMotion.new()
	event.position = get_viewport().get_mouse_position()
	event.global_position = event.position
	Input.parse_input_event(event)

func _apply_highest() -> void:
	#print("GRAB: " + str(_requests[CursorType.GRAB]))
	#print("HOVER: " + str(_requests[CursorType.HOVER]))
	#print("DEFAULT: " + str(_requests[CursorType.DEFAULT]))
	# Iterate from highest to lowest priority
	for cursor_type in [CursorType.GRAB, CursorType.HOVER, CursorType.DEFAULT]:
		if _requests[cursor_type] > 0:
			_apply_cursor(cursor_type)
			return

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
