extends Camera3D

var DIALOGUE_ROTATION = 0.0
var WORK_AREA_ROTATION = -80.0
var ANIMATION_TIME = 0.4

enum CameraState {
	STATIONARY,
	ROTATING
}

enum CameraFocus {
	DIALOGUE_AREA,
	WORK_AREA
}

var _camera_state = CameraState.STATIONARY
var _camera_focus = CameraFocus.DIALOGUE_AREA
var _rotation_tracker = 0.0 # values from 0 to 1, tracks where we are in the rotation animation

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	handle_rotation(delta)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_view"):
		toggle_view()

# smoothes out a value between 0 and 1
# function is symmetrical with respect to (0.5, 0.5)
func symmetrical_smooth(x: float):
	return (sin(x*PI - PI / 2) + 1) / 2.0

func handle_rotation(delta: float):
	if _camera_state == CameraState.STATIONARY:
		return
	
	var animation_increment = delta / ANIMATION_TIME
	_rotation_tracker += animation_increment
	var begin_rotation = DIALOGUE_ROTATION if _camera_focus == CameraFocus.WORK_AREA else WORK_AREA_ROTATION
	var end_rotation = WORK_AREA_ROTATION if _camera_focus == CameraFocus.WORK_AREA else DIALOGUE_ROTATION
	var new_rotation = lerpf(begin_rotation, end_rotation, symmetrical_smooth(_rotation_tracker))
	$".".rotation_degrees.x = new_rotation
	
	if _rotation_tracker >= 1.0:
		_camera_state = CameraState.STATIONARY
		_rotation_tracker = 0.0

# sets variables to toggle the camera view between dialogue view to the work area view
func toggle_view():
	# If we are rotation then we are interrupting a rotation with a toggle
	# To go the other direction we need the complement - if we have a little left to the original destination, 
	# then we have a long way back
	if _camera_state == CameraState.ROTATING:
		_rotation_tracker = 1.0 - _rotation_tracker
	_camera_state = CameraState.ROTATING
		
	if _camera_focus == CameraFocus.DIALOGUE_AREA:
		_camera_focus = CameraFocus.WORK_AREA
	else:
		_camera_focus = CameraFocus.DIALOGUE_AREA
