class_name CameraControl
extends Camera3D

var DIALOGUE_ROTATION = 0.0
var WORK_AREA_ROTATION = -80.0
var ANIMATION_TIME = 0.4

@export var focused_fov: float = 40.0
@export var focus_fov_curve: Curve
@export var dolly_zoom_sensitivity: float = 0.02 # godot units camera moves per 1 degree FOV change

@export_group("Quarantine View")
# exit zone is wider than entry zone: prevents the view flicking back and forth when the mouse sits near the boundary
@export var quarantine_entry_zone_fraction: float = 0.15
@export var quarantine_exit_zone_fraction: float = 0.25
@export var quarantine_x_offset: float = -0.5
@export var quarantine_dwell_time: float = 0.5
@export var quarantine_exit_grace: float = 0.15
@export var quarantine_transition_time: float = 0.4
@export var quarantine_transition_curve: Curve

enum CameraState {
	STATIONARY,
	ROTATING
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
var view_toggle_locked: bool = false
var _base_x: float = 0.0
var _quarantine_dwell_acc: float = 0.0
var _quarantine_exit_acc: float = 0.0
var _quarantine_tween: Tween

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_default_fov = fov
	_base_x = position.x

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	handle_rotation(delta)
	_handle_quarantine_proximity(delta)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_view"):
		toggle_view()

# smoothes out a value between 0 and 1
# function is symmetrical with respect to (0.5, 0.5)
func symmetrical_smooth(x: float):
	return (sin(x * PI - PI / 2) + 1) / 2.0

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
		emit_signal("camera_rotation_completed", _camera_focus)

# sets variables to toggle the camera view between dialogue view to the work area view
func toggle_view():
	if view_toggle_locked or _camera_focus == CameraFocus.QUARANTINE_VIEW:
		return
	# If we are rotation then we are interrupting a rotation with a toggle
	# To go the other direction we need the complement
	if _camera_state == CameraState.ROTATING:
		_rotation_tracker = 1.0 - _rotation_tracker
	_camera_state = CameraState.ROTATING
		
	if _camera_focus == CameraFocus.DIALOGUE_AREA:
		_camera_focus = CameraFocus.WORK_AREA
	else:
		_camera_focus = CameraFocus.DIALOGUE_AREA

	emit_signal("camera_focus_changed", _camera_focus)


func _handle_quarantine_proximity(delta: float) -> void:
	if view_toggle_locked or _camera_state == CameraState.ROTATING:
		_quarantine_dwell_acc = 0.0
		_quarantine_exit_acc = 0.0
		return

	var mouse_fraction := get_viewport().get_mouse_position().x / get_viewport().get_visible_rect().size.x

	if _camera_focus == CameraFocus.WORK_AREA:
		if mouse_fraction < quarantine_entry_zone_fraction:
			_quarantine_exit_acc = 0.0
			_quarantine_dwell_acc += delta
			if _quarantine_dwell_acc >= quarantine_dwell_time:
				_quarantine_dwell_acc = 0.0
				_enter_quarantine()
		else:
			_quarantine_dwell_acc = 0.0
	elif _camera_focus == CameraFocus.QUARANTINE_VIEW:
		if mouse_fraction >= quarantine_exit_zone_fraction:
			_quarantine_dwell_acc = 0.0
			_quarantine_exit_acc += delta
			if _quarantine_exit_acc >= quarantine_exit_grace:
				_quarantine_exit_acc = 0.0
				_exit_quarantine()
		else:
			_quarantine_exit_acc = 0.0


func _enter_quarantine() -> void:
	var start_x := position.x
	var target_x := _base_x + quarantine_x_offset
	if _quarantine_tween and _quarantine_tween.is_valid():
		_quarantine_tween.kill()
	_camera_focus = CameraFocus.QUARANTINE_VIEW
	camera_focus_changed.emit(_camera_focus)
	var sample := func(t: float) -> float: return quarantine_transition_curve.sample(t) if quarantine_transition_curve else t
	_quarantine_tween = create_tween()
	_quarantine_tween.tween_method(
		func(t: float) -> void: position.x = lerpf(start_x, target_x, sample.call(t)),
		0.0, 1.0, quarantine_transition_time
	)
	_quarantine_tween.tween_callback(func(): camera_rotation_completed.emit(_camera_focus))


func _exit_quarantine() -> void:
	var start_x := position.x
	var target_x := _base_x
	if _quarantine_tween and _quarantine_tween.is_valid():
		_quarantine_tween.kill()
	_camera_focus = CameraFocus.WORK_AREA
	camera_focus_changed.emit(_camera_focus)
	var sample := func(t: float) -> float: return quarantine_transition_curve.sample(t) if quarantine_transition_curve else t
	_quarantine_tween = create_tween()
	_quarantine_tween.tween_method(
		func(t: float) -> void: position.x = lerpf(start_x, target_x, sample.call(t)),
		0.0, 1.0, quarantine_transition_time
	)
	_quarantine_tween.tween_callback(func(): camera_rotation_completed.emit(_camera_focus))


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
