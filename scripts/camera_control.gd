class_name CameraControl
extends Camera3D

const DIALOGUE_ROTATION: float = 0.0
const WORK_AREA_ROTATION: float = -80.0

@export var focused_fov: float = 40.0
@export var focus_fov_curve: Curve
@export var dolly_zoom_sensitivity: float = 0.02 # godot units camera moves per 1 degree FOV change

@export_group("Dialogue View Transition")
@export var vertical_zone_fraction: float = 0.10
@export var vertical_dwell_time: float = 0.5
@export var vertical_transition_time: float = 0.6

enum CameraFocus {
	DIALOGUE_AREA,
	WORK_AREA,
}

signal camera_focus_changed(current_focus)
signal camera_rotation_completed(current_focus)

var _camera_focus: CameraFocus = CameraFocus.DIALOGUE_AREA
var _transition_tween: Tween
var _zoom_tween: Tween
var _object_focus_active: bool = false
var can_enter_dialogue_view: bool = true
var _starting_position: Vector3 = Vector3.ZERO
var _starting_fov: float = 0.0
var _vertical_dwell_elapsed: float = 0.0 # in seconds
var _is_locked: bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_starting_position = position
	_starting_fov = fov

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if _is_locked or GameState.is_player_input_locked:
		_vertical_dwell_elapsed = 0.0
		return

	_handle_vertical_proximity(delta)

func set_locked_to_dialogue(is_locked: bool) -> void:
	_is_locked = is_locked
	if not is_locked:
		return
	if _transition_tween:
		_transition_tween.kill()
	_camera_focus = CameraFocus.DIALOGUE_AREA
	rotation_degrees.x = DIALOGUE_ROTATION

func _transition_to(target_focus: CameraFocus) -> void:
	if _transition_tween:
		_transition_tween.kill()

	_camera_focus = target_focus
	AudioManager.play_sfx(Config.CAMERA_SWOOSH_SFX_NAME)
	camera_focus_changed.emit(_camera_focus)

	_transition_tween = create_tween()
	var target_rotation := DIALOGUE_ROTATION if target_focus == CameraFocus.DIALOGUE_AREA else WORK_AREA_ROTATION
	_transition_tween.tween_property(self, "rotation_degrees:x", target_rotation, vertical_transition_time).set_trans(Tween.TRANS_SINE)
	_transition_tween.finished.connect(_on_transition_finished)


func _on_transition_finished() -> void:
	camera_rotation_completed.emit(_camera_focus)


func _is_camera_animating() -> bool:
	return (_transition_tween != null and _transition_tween.is_running()) or _object_focus_active


func is_at_rest_in_workbench_view() -> bool:
	return not _is_camera_animating() and _camera_focus == CameraFocus.WORK_AREA


func _handle_vertical_proximity(delta: float) -> void:
	if _is_locked or not can_enter_dialogue_view or _is_camera_animating():
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
					_transition_to(CameraFocus.WORK_AREA)
			else:
				_vertical_dwell_elapsed = 0.0
		CameraFocus.WORK_AREA:
			if in_top:
				_vertical_dwell_elapsed += delta
				if _vertical_dwell_elapsed >= vertical_dwell_time:
					_vertical_dwell_elapsed = 0.0
					_transition_to(CameraFocus.DIALOGUE_AREA)
			else:
				_vertical_dwell_elapsed = 0.0


func begin_object_focus(zoom_percent: float, duration: float) -> void:
	_object_focus_active = true
	var camera_forward := -basis.z
	var default_dolly_distance: float = (focused_fov - _starting_fov) * dolly_zoom_sensitivity
	# add per-object custom zoom value
	var extra_zoom: float = max(default_dolly_distance, 0.0) * zoom_percent / 100.0
	_tween_fov_and_position(focused_fov, _starting_position + camera_forward * (default_dolly_distance + extra_zoom), duration)


func end_object_focus(duration: float) -> void:
	if not _object_focus_active:
		return
	_tween_fov_and_position(_starting_fov, _starting_position, duration)
	_zoom_tween.finished.connect(func() -> void: _object_focus_active = false)


func _tween_fov_and_position(target_fov: float, target_position: Vector3, duration: float) -> void:
	if _zoom_tween:
		_zoom_tween.kill()
	_zoom_tween = create_tween().set_parallel(true)
	var fov_tweener := _zoom_tween.tween_property(self, "fov", target_fov, duration)
	var position_tweener := _zoom_tween.tween_property(self, "position", target_position, duration)
	if focus_fov_curve:
		fov_tweener.set_custom_interpolator(focus_fov_curve.sample)
		position_tweener.set_custom_interpolator(focus_fov_curve.sample)
