class_name HealthManager
extends Node

const STARTING_MAX_HEALTH: float = 100.0
const VISUAL_HEALTH_SMOOTHING_RATE: float = 6.0

@export var health_drain_per_second: float = 1.5
@export var health_restore_per_second: float = 0.75
@export var hp_penalty_per_missed_sticker: float = 5.0
@export var hp_penalty_cap_per_object: float = 15.0

@onready var camera: CameraControl = %Camera3D
@onready var health_overlay: HealthOverlay = %HealthOverlay


var _health: float = STARTING_MAX_HEALTH
var _visual_health: float = STARTING_MAX_HEALTH
var max_health: float = STARTING_MAX_HEALTH

# The object currently in focus, will be queried for drain info (does it have stickers?)
var _focused_object: InteractibleObject = null

# Flag to ensure player death event fires only once. 
# This flag is not cleared! — recovery from player death should be done via scene reload
var _is_dead: bool = false

# debug: accumulates delta for the once-per-second health printout
var _debug_print_elapsed: float = 0.0


func reset_max_health() -> void:
	max_health = STARTING_MAX_HEALTH
	_set_health(max_health)


## Register an object spawned on the workbench to connect health drain to object focus & completion
func register_object(obj: InteractibleObject) -> void:
	obj.object_interactible.connect(_on_object_interactible.bind(obj))
	obj.object_completed.connect(_on_object_completed)


func _ready() -> void:
	camera.camera_focus_changed.connect(_on_camera_focus_changed)


func _process(delta: float) -> void:
	# Either draining or recovering
	if _should_drain():
		_set_health(_health - health_drain_per_second * delta)
	else:
		_set_health(_health + health_restore_per_second * delta)

	_visual_health = lerp(_visual_health, _health, 1.0 - exp(-VISUAL_HEALTH_SMOOTHING_RATE * delta))
	health_overlay.set_health_normalized(_visual_health / STARTING_MAX_HEALTH)

	# TODO: remove debug prints
	# _debug_print_elapsed += delta
	# if _debug_print_elapsed >= 1.0:
	# 	_debug_print_elapsed = 0.0
	# 	var focused := is_instance_valid(_focused_object)
	# 	print("HealthManager: HP %s/%s | focused=%s has_stickers=%s -> %s" % [
	# 		str(snappedf(_health, 0.1)), str(snappedf(max_health, 0.1)),
	# 		str(focused), str(focused and _focused_object.has_stickers_remaining()),
	# 		"DRAINING" if _should_drain() else "restoring",
	# 	])


func _should_drain() -> bool:
	return is_instance_valid(_focused_object) and _focused_object.has_stickers_remaining()


func _set_health(value: float) -> void:
	_health = clampf(value, 0.0, max_health)
	if _health <= 0.0 and not _is_dead:
		_die()


func _die() -> void:
	_is_dead = true
	set_process(false) # stops drain, regen, debug updates
	push_warning("Player HP reached 0")
	GameState.player_died.emit()


func _on_camera_focus_changed(current_focus: CameraControl.CameraFocus) -> void:
	if current_focus == CameraControl.CameraFocus.DIALOGUE_AREA:
		_set_health(max_health)


func _on_object_interactible(is_interactible: bool, obj: InteractibleObject) -> void:
	if is_interactible:
		_focused_object = obj
	elif _focused_object == obj: # guard: a stale unfocus must not clear a newer focus
		_focused_object = null


func _on_object_completed(_object_name: String, _is_special: bool, completed_stickers: int, total_stickers: int) -> void:
	var missed_stickers := total_stickers - completed_stickers
	if missed_stickers <= 0:
		return
	var penalty := minf(missed_stickers * hp_penalty_per_missed_sticker, hp_penalty_cap_per_object)
	max_health = maxf(0.0, max_health - penalty)
	_set_health(_health) # re-clamp to the new ceiling: a zero ceiling will trigger death
	print("HealthManager: Max health set to %s" % str(snappedf(max_health, 0.1)))