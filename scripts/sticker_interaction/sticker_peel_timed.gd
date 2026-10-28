## Timed sticker: keeps track of how long the object has been in focus
## Once the object has been in focus more than time_limit seconds, the sticker is permanently failed, and no longer interactible
@tool
class_name StickerPeelTimed extends StickerPeel

# these control how much of the time between the flashes (which adds up to a fraction of 1.0) is used to smooth out the flash
# currently we got a quick rise and slow fall
const FLASH_RISE_FRACTION: float = 0.1
const FLASH_FALL_FRACTION: float = 0.6

@export var time_limit: float = 10.0

# Flash rate, escalating linearly from min to max as the countdown runs out
@export var flash_min_hz: float = 1.0
@export var flash_max_hz: float = 12.0

var _time_remaining: float = 0.0
var _is_timer_running: bool = false
var _flash_phase: float = 0.0 # in cycles [0, 1)

func _ready() -> void:
	super._ready()
	_time_remaining = time_limit
	_write_shader_values()


func _on_object_interactible_change(is_interactible: bool) -> void:
	super._on_object_interactible_change(is_interactible)
	_is_timer_running = is_interactible and state == State.ACTIVE


func _process(delta: float) -> void:
	super._process(delta)
	if state != State.ACTIVE:
		return
	# debug mode (zoo scene): there is no parent object, force tick
	var is_countdown_running: bool = _is_timer_running or debug_enabled
	if is_countdown_running:
		_time_remaining = max(_time_remaining - delta, 0.0)
	_advance_flash(delta)
	_write_shader_values()
	if _time_remaining <= 0.0:
		_fail()


func _get_countdown_progress() -> float:
	return 1.0 - clamp(_time_remaining / time_limit, 0.0, 1.0)


func _advance_flash(delta: float) -> void:
	var flash_rate_hz: float = lerpf(flash_min_hz, flash_max_hz, _get_countdown_progress())
	_flash_phase = fmod(_flash_phase + flash_rate_hz * delta, 1.0)


func _get_flash_value() -> float:
	var fall_end_fraction: float = FLASH_RISE_FRACTION + FLASH_FALL_FRACTION
	var rise_value: float = smoothstep(0.0, FLASH_RISE_FRACTION, _flash_phase)
	var fall_value: float = smoothstep(FLASH_RISE_FRACTION, fall_end_fraction, _flash_phase)
	var single_flash_value: float = rise_value - fall_value
	
	return single_flash_value * _get_countdown_progress()


func _get_danger_amount(countdown_progress: float) -> float:
	return countdown_progress * countdown_progress


func _fail() -> void:
	state = State.FAILED
	_is_timer_running = false
	$CollisionShape3D.disabled = true
	# cancel any in-progress peel
	if is_peeling:
		is_peeling = false
		_start_rollback()
	_write_shader_values()


func _write_shader_values() -> void:
	var is_failed: bool = state == State.FAILED
	var flash_value: float = 0.0 if is_failed else _get_flash_value()
	var danger_amount: float = 1.0 if is_failed else _get_danger_amount(_get_countdown_progress())

	set_shader_value(&"flash", flash_value)
	set_shader_value(&"danger", danger_amount)
