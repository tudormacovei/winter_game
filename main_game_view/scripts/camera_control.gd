extends Camera3D

var DIALOGUE_ROTATION = 0.0
var WORK_AREA_ROTATION = -90.0
var ANIMATION_TIME = 0.5

enum CameraState {
	Stationary,
	Rotating
}

enum CameraFocus {
	DialogueArea,
	WorkArea
}

var camera_state = CameraState.Stationary
var camera_focus = CameraFocus.DialogueArea
var rotation_tracker = 0.0 # values from 0 to 1, tracks where we are in the rotation animation

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	handle_rotation(delta)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_view") and camera_state == CameraState.Stationary :
		toggle_view()

func handle_rotation(delta: float):
	if camera_state == CameraState.Stationary:
		return
	
	var animation_increment = delta / ANIMATION_TIME
	rotation_tracker += animation_increment
	var begin_rotation = DIALOGUE_ROTATION if camera_focus == CameraFocus.WorkArea else WORK_AREA_ROTATION
	var end_rotation = WORK_AREA_ROTATION if camera_focus == CameraFocus.WorkArea else DIALOGUE_ROTATION
	var rotation = lerpf(begin_rotation, end_rotation, rotation_tracker)
	$".".rotation_degrees.x = rotation
	
	if rotation_tracker >= 1.0:
		camera_state = CameraState.Stationary
		rotation_tracker = 0.0

# sets variables to toggle the camera view between dialogue view to the work area view
func toggle_view():
	camera_state = CameraState.Rotating
		
	if camera_focus == CameraFocus.DialogueArea:
		camera_focus = CameraFocus.WorkArea
	else:
		camera_focus = CameraFocus.DialogueArea
