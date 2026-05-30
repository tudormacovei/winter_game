class_name CameraControl
extends Camera3D

var DIALOGUE_ROTATION = 0.0
var WORK_AREA_ROTATION = -80.0

@export var focused_fov: float = 40.0
@export var focus_fov_curve: Curve
@export var dolly_zoom_sensitivity: float = 0.02 # godot units camera moves per 1 degree FOV change

@export_group("Quarantine View Transition")
# exit zone is wider than entry zone: prevents the view flicking back and forth when the mouse sits near the boundary
@export var quarantine_entry_zone_fraction: float = 0.15
@export var quarantine_exit_zone_fraction: float = 0.25
@export var quarantine_x_offset: float = -0.5
@export var quarantine_dwell_time: float = 0.5
@export var quarantine_exit_grace: float = 0.15
@export var quarantine_transition_time: float = 0.4
@export var quarantine_transition_curve: Curve

@export_group("Dialogue View Transition")
@export var vertical_zone_fraction: float = 0.10
@export var vertical_dwell_time: float = 0.5
@export var vertical_transition_time = 0.6

enum CameraState {
	STATIONARY,
	ROTATING,
	MOVING,
}

enum CameraFocus {
	DIALOGUE_AREA,
	WORK_AREA,
	QUARANTINE_VIEW,
}

signal camera_focus_changed(current_focus)
signal camera_rotation_completed(current_focus)

var _camera_state = CameraState.STATIONARY
var _camera_focus = CameraFocus.DIALOGUE_AREA
var _rotation_tracker = 0.0 # values from 0 to 1, tracks where we are in the rotation animation
var _default_fov: float = 0.0
var _fov_tween: Tween
var _dolly_tween: Tween
var rotation_locked: bool = false
var _base_x: float = 0.0
var _quarantine_dwell_elapsed: float = 0.0 # in seconds
var _quarantine_exit_elapsed: float = 0.0 # in seconds
var _quarantine_tween: Tween
var _vertical_dwell_elapsed: float = 0.0 # in seconds
var _pending_transition_to_dialogue: bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_default_fov = fov
	_base_x = position.x

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	handle_rotation(delta)
	_handle_quarantine_proximity(delta)
	_handle_vertical_proximity(delta)

# smoothes out a value between 0 and 1
# function is symmetrical with respect to (0.5, 0.5)
func symmetrical_smooth(x: float):
	return (sin(x * PI - PI / 2) + 1) / 2.0

func handle_rotation(delta: float):
	if _camera_state != CameraState.ROTATING:
		return
	
	var animation_increment = delta / vertical_transition_time
	_rotation_tracker += animation_increment
	var begin_rotation = DIALOGUE_ROTATION if _camera_focus == CameraFocus.WORK_AREA else WORK_AREA_ROTATION
	var end_rotation = WORK_AREA_ROTATION if _camera_focus == CameraFocus.WORK_AREA else DIALOGUE_ROTATION
	var new_rotation = lerpf(begin_rotation, end_rotation, symmetrical_smooth(_rotation_tracker))
	$".".rotation_degrees.x = new_rotation
	
	if _rotation_tracker >= 1.0:
		_camera_state = CameraState.STATIONARY
		_rotation_tracker = 0.0
		camera_rotation_completed.emit(_camera_focus)

# begins a rotation from the current camera_focus to target_focus (WORK_AREA or DIALOGUE_AREA)
func _start_rotation_to(target_focus: CameraFocus) -> void:
	if rotation_locked:
		return
	# interrupting an in-progress rotation toward the opposite target: reverse by complementing the tracker
	if _camera_state == CameraState.ROTATING:
		_rotation_tracker = 1.0 - _rotation_tracker
	_camera_state = CameraState.ROTATING
	_camera_focus = target_focus
	camera_focus_changed.emit(_camera_focus)


func _is_camera_animating() -> bool:
	return _camera_state != CameraState.STATIONARY


func is_at_rest_in_workbench_view() -> bool:
	return _camera_state == CameraState.STATIONARY and _camera_focus == CameraFocus.WORK_AREA


func is_at_rest_at_table() -> bool:
	return _camera_state == CameraState.STATIONARY and (_camera_focus == CameraFocus.WORK_AREA or _camera_focus == CameraFocus.QUARANTINE_VIEW)


func _handle_quarantine_proximity(delta: float) -> void:
	if _is_camera_animating():
		_quarantine_dwell_elapsed = 0.0
		_quarantine_exit_elapsed = 0.0
		return

	var mouse_fraction := get_viewport().get_mouse_position().x / get_viewport().get_visible_rect().size.x

	if _camera_focus == CameraFocus.WORK_AREA:
		if mouse_fraction < quarantine_entry_zone_fraction:
			_quarantine_exit_elapsed = 0.0
			_quarantine_dwell_elapsed += delta
			if _quarantine_dwell_elapsed >= quarantine_dwell_time:
				_quarantine_dwell_elapsed = 0.0
				_enter_quarantine()
		else:
			_quarantine_dwell_elapsed = 0.0
	elif _camera_focus == CameraFocus.QUARANTINE_VIEW:
		# dialogue transition wins when both dialogue and quarantine transition is valid
		var mouse_y_frac := get_viewport().get_mouse_position().y / get_viewport().get_visible_rect().size.y
		var in_top_zone := mouse_y_frac < vertical_zone_fraction
		if mouse_fraction >= quarantine_exit_zone_fraction and not in_top_zone:
			_quarantine_dwell_elapsed = 0.0
			_quarantine_exit_elapsed += delta
			if _quarantine_exit_elapsed >= quarantine_exit_grace:
				_quarantine_exit_elapsed = 0.0
				_exit_quarantine()
		else:
			_quarantine_exit_elapsed = 0.0


func _handle_vertical_proximity(delta: float) -> void:
	if rotation_locked or _is_camera_animating():
		_vertical_dwell_elapsed = 0.0
		return

	var viewport_size := get_viewport().get_visible_rect().size
	var mouse_y_frac := get_viewport().get_mouse_position().y / viewport_size.y
	var in_top := mouse_y_frac < vertical_zone_fraction
	var in_bottom := mouse_y_frac > 1.0 - vertical_zone_fraction

	match _camera_focus:
		CameraFocus.DIALOGUE_AREA:
			if in_bottom:
				_vertical_dwell_elapsed += delta
				if _vertical_dwell_elapsed >= vertical_dwell_time:
					_vertical_dwell_elapsed = 0.0
					_start_rotation_to(CameraFocus.WORK_AREA)
			else:
				_vertical_dwell_elapsed = 0.0
		CameraFocus.WORK_AREA:
			if in_top:
				_vertical_dwell_elapsed += delta
				if _vertical_dwell_elapsed >= vertical_dwell_time:
					_vertical_dwell_elapsed = 0.0
					_start_rotation_to(CameraFocus.DIALOGUE_AREA)
			else:
				_vertical_dwell_elapsed = 0.0
		CameraFocus.QUARANTINE_VIEW:
			if in_top:
				_vertical_dwell_elapsed += delta
				if _vertical_dwell_elapsed >= vertical_dwell_time:
					_vertical_dwell_elapsed = 0.0
					# position and rotation must never animate simultaneously, so chain transitions
					_enter_dialogue_from_quarantine_chained()
			else:
				_vertical_dwell_elapsed = 0.0


func _enter_dialogue_from_quarantine_chained() -> void:
	_pending_transition_to_dialogue = true
	_exit_quarantine()


func _enter_quarantine() -> void:
	var start_x := position.x
	var target_x := _base_x + quarantine_x_offset
	if _quarantine_tween and _quarantine_tween.is_valid():
		_quarantine_tween.kill()
	_camera_state = CameraState.MOVING
	_camera_focus = CameraFocus.QUARANTINE_VIEW
	camera_focus_changed.emit(_camera_focus)
	var sample := func(t: float) -> float: return quarantine_transition_curve.sample(t) if quarantine_transition_curve else t
	_quarantine_tween = create_tween()
	_quarantine_tween.tween_method(
		func(t: float) -> void: position.x = lerpf(start_x, target_x, sample.call(t)),
		0.0, 1.0, quarantine_transition_time
	)
	_quarantine_tween.tween_callback(_on_enter_quarantine_finished)


func _on_enter_quarantine_finished() -> void:
	_camera_state = CameraState.STATIONARY
	camera_rotation_completed.emit(_camera_focus)


func _exit_quarantine() -> void:
	var start_x := position.x
	var target_x := _base_x
	if _quarantine_tween and _quarantine_tween.is_valid():
		_quarantine_tween.kill()
	_camera_state = CameraState.MOVING
	_camera_focus = CameraFocus.WORK_AREA
	camera_focus_changed.emit(_camera_focus)
	var sample := func(t: float) -> float: return quarantine_transition_curve.sample(t) if quarantine_transition_curve else t
	_quarantine_tween = create_tween()
	_quarantine_tween.tween_method(
		func(t: float) -> void: position.x = lerpf(start_x, target_x, sample.call(t)),
		0.0, 1.0, quarantine_transition_time
	)
	_quarantine_tween.tween_callback(_on_exit_quarantine_finished)


func _on_exit_quarantine_finished() -> void:
	_camera_state = CameraState.STATIONARY
	camera_rotation_completed.emit(_camera_focus)

	# Check if we have to complete the chain of transitions back to dialogue
	if _pending_transition_to_dialogue:
		_pending_transition_to_dialogue = false
		_start_rotation_to(CameraFocus.DIALOGUE_AREA)


func tween_fov(target_fov: float, duration: float) -> void:
	if _fov_tween and _fov_tween.is_valid():
		_fov_tween.kill()
	if _dolly_tween and _dolly_tween.is_valid():
		_dolly_tween.kill()
	var start_fov := fov
	var start_pos := position
	var fov_delta := target_fov - start_fov
	var target_pos := start_pos + (-basis.z * fov_delta * dolly_zoom_sensitivity)
	var curve_sample := func(t: float) -> float: return focus_fov_curve.sample(t) if focus_fov_curve else t
	_fov_tween = create_tween()
	_fov_tween.tween_method(
		func(t: float) -> void: fov = lerpf(start_fov, target_fov, curve_sample.call(t)),
		0.0, 1.0, duration
	)
	_dolly_tween = create_tween()
	_dolly_tween.tween_method(
		func(t: float) -> void: position = start_pos.lerp(target_pos, curve_sample.call(t)),
		0.0, 1.0, duration
	)
