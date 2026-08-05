## Timed sticker: keeps track of how long the object has been in focus
## Once the object has been in focus more than time_limit seconds, the sticker is permanently failed, and no longer interactible
@tool
class_name StickerPeelTimed extends StickerPeel

@export var time_limit: float = 10.0

# Edge glow pulse rate, escalating from min to max as the countdown runs out
@export var edge_pulse_min_hz: float = 1.0
@export var edge_pulse_max_hz: float = 3.0

var _time_remaining: float = 0.0
var _is_timer_running: bool = false
var _material: ShaderMaterial = null
var _pulse_phase: float = 0.0 # in cycles [0, 1)

func _ready() -> void:
	super._ready()
	_time_remaining = time_limit
	_setup_shader_material()
	_write_shader_uniforms()


func _on_object_interactible_change(is_interactible: bool) -> void:
	super._on_object_interactible_change(is_interactible)
	_is_timer_running = is_interactible and state == State.ACTIVE


func _process(delta: float) -> void:
	super._process(delta)
	# debug mode (zoo scene): there is no parent object, force tick
	var should_tick: bool = state == State.ACTIVE and (_is_timer_running or debug_enabled)
	if not should_tick:
		return
	_time_remaining = max(_time_remaining - delta, 0.0)
	_advance_pulse_phase(delta)
	_write_shader_uniforms()
	if _time_remaining <= 0.0:
		_fail()


# Makes the sticker flash quicker as times goes on
func _advance_pulse_phase(delta: float) -> void:
	var progress: float = 1.0 - clamp(_time_remaining / time_limit, 0.0, 1.0)
	var pulse_hz: float = lerpf(edge_pulse_min_hz, edge_pulse_max_hz, progress)
	_pulse_phase = fmod(_pulse_phase + pulse_hz * delta, 1.0)


func _fail() -> void:
	state = State.FAILED
	_is_timer_running = false
	$CollisionShape3D.disabled = true
	# cancel any in-progress peel
	if is_peeling:
		is_peeling = false
		_start_rollback()
	_write_shader_uniforms()


# setup the per-instance ShaderMaterial & store a reference to it
func _setup_shader_material() -> void:
	var mat := _get_or_duplicate_surface_material()
	if not (mat is ShaderMaterial):
		return
	_material = mat as ShaderMaterial


func _write_shader_uniforms() -> void:
	if _material == null:
		return
	var progress: float = 1.0 - clamp(_time_remaining / time_limit, 0.0, 1.0)
	_material.set_shader_parameter(&"progress", progress)
	_material.set_shader_parameter(&"pulse_phase", _pulse_phase)
	_material.set_shader_parameter(&"failed", 1.0 if state == State.FAILED else 0.0)
