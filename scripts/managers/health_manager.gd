class_name HealthManager
extends Node

const STARTING_MAX_HEALTH: float = 100.0
const VISUAL_HEALTH_SMOOTHING_RATE: float = 6.0
const _HEALTH_THRESHOLDS: Array[float] = [80.0, 50.0, 20.0, 10.0, 0.0]

@export var health_drain_per_second: float = 1.5
@export var health_restore_per_second: float = 0.75
@export var hp_penalty_per_missed_sticker: float = 5.0
@export var hp_penalty_cap_per_object: float = 15.0

@onready var camera: CameraControl = %Camera3D
@onready var health_overlay: HealthOverlay = %HealthOverlay

var _health: float = STARTING_MAX_HEALTH
var _visual_health: float = STARTING_MAX_HEALTH
var max_health: float = STARTING_MAX_HEALTH
var _has_focused_object: bool = false

# Drain is only active if the focused object (still) has stickers.
# Defaults to false — drain is off until we know the object has stickers
var _focused_object_has_stickers: bool = false
var _triggered_thresholds: Array[float] = []


func _ready() -> void:
	camera.camera_focus_changed.connect(_on_camera_focus_changed)


func _process(delta: float) -> void:
	if _has_focused_object and _focused_object_has_stickers:
		_set_health(_health - health_drain_per_second * delta)
	else:
		_set_health(_health + health_restore_per_second * delta)

	_visual_health = lerp(_visual_health, _health, 1.0 - exp(-VISUAL_HEALTH_SMOOTHING_RATE * delta))
	_update_health_overlay()


func register_object(obj: InteractibleObject) -> void:
	obj.object_interactible.connect(_on_object_interactible)
	obj.object_completed.connect(_on_object_completed)
	obj.has_stickers_remaining_changed.connect(_on_has_stickers_remaining_changed)

	# Reset to "no" per-object as default, wait for sticker info from object to set to 'true'
	_focused_object_has_stickers = false


func _set_health(value: float) -> void:
	var prev_health := _health
	_health = clampf(value, 0.0, max_health)
	_check_health_thresholds(prev_health)


func _update_health_overlay() -> void:
	health_overlay.set_health_normalized(_visual_health / 100.0)

## Used to check if HP is below 0
func _check_health_thresholds(prev_health: float) -> void:
	for threshold in _HEALTH_THRESHOLDS:
		if prev_health > threshold and _health <= threshold:
			_triggered_thresholds.append(threshold)
			print("HealthManager: Health dropped below %d (%s pts)" % [int(threshold), str(snappedf(_health, 0.1))])
			if threshold == 0.0:
				push_warning("HealthManager: Player current HP reached 0")
		elif prev_health <= threshold and _health > threshold:
			_triggered_thresholds.erase(threshold)
			print("HealthManager: Health recovered above %d (%s pts)" % [int(threshold), str(snappedf(_health, 0.1))])


func _on_camera_focus_changed(current_focus: CameraControl.CameraFocus) -> void:
	if current_focus == CameraControl.CameraFocus.DIALOGUE_AREA:
		_set_health(max_health)


func _on_object_interactible(is_interactible: bool) -> void:
	_has_focused_object = is_interactible


func _on_has_stickers_remaining_changed(has_remaining: bool) -> void:
	_focused_object_has_stickers = has_remaining


func reset_max_health() -> void:
	max_health = STARTING_MAX_HEALTH
	_set_health(max_health)
	_triggered_thresholds.clear()


func _on_object_completed(_object_name: String, _is_special: bool, completed_stickers: int, total_stickers: int) -> void:
	var missed_stickers := total_stickers - completed_stickers
	if missed_stickers <= 0:
		return
	var penalty := minf(missed_stickers * hp_penalty_per_missed_sticker, hp_penalty_cap_per_object)
	max_health = maxf(0.0, max_health - penalty)
	_set_health(_health)
	print("HealthManager: Max health set to %s" % str(snappedf(max_health, 0.1)))
	if max_health == 0.0:
		push_warning("HealthManager: Player max HP reached 0")
