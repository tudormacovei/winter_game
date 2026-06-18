## Timed sticker: keeps track of how long the object has been in focus
## Once the object has been in focus more than time_limit seconds, the sticker is permanently failed, and no longer interactible
@tool
class_name StickerPeelTimed extends StickerPeel

@export var time_limit: float = 10.0

var _time_remaining: float = 0.0
var _is_timer_running: bool = false
var _material: ShaderMaterial = null

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
	_write_shader_uniforms()
	if _time_remaining <= 0.0:
		_fail()


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
	_material.set_shader_parameter(&"failed", 1.0 if state == State.FAILED else 0.0)
