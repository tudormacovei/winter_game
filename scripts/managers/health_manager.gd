class_name HealthManager
extends Node

const STARTING_MAX_HEALTH: float = 100.0
const VISUAL_HEALTH_SMOOTHING_RATE: float = 6.0

@export var health_drain_per_second: float = 1.5
@export var life_loss_before_sound_delay: float = 0.2
@export var life_loss_before_candle_delay: float = 0.4
@export var visual_health_curve: Curve
@export var environment_lights: Array[Light3D] = []

@onready var health_overlay: HealthOverlay = %HealthOverlay
@onready var health_visualization: HealthVisualization = %HealthVisualization
@onready var _world_environment := get_node_or_null("../../WorldEnvironment") as WorldEnvironment


var _health: float = STARTING_MAX_HEALTH
var _visual_health: float = 1.0
var _animated_visual_health: float = 1.0
var _remaining_lives: int = 0
var _is_losing_life: bool = false
var _environment_light_energies: Array[float] = []
var _ambient_light_energy: float = 0.0
var _current_light_energy_multiplier: float = 1.0
var _environment_lights_tween: Tween = null

var _environment_lights_dim_multiplier: float = 0.25
var _environment_lights_restore_duration: float = 10.00

# The object currently in focus, will be queried for drain info (does it have stickers?)
var _focused_object: InteractibleObject = null

# Flag to ensure player death event fires only once. 
# This flag is not cleared! — recovery from player death should be done via scene reload
var _is_dead: bool = false


func reset_health() -> void:
	_set_health(STARTING_MAX_HEALTH)
	_reset_lives()


## Register an object spawned on the workbench to connect health drain to object focus & completion
func register_object(obj: InteractibleObject) -> void:
	obj.object_interactible.connect(_on_object_interactible.bind(obj))
	obj.object_completed.connect(_on_object_completed)


func _ready() -> void:
	assert(visual_health_curve != null, "HealthManager requires a visual health curve.")
	assert(not environment_lights.is_empty(), "HealthManager requires at least one environment light.")
	assert(_world_environment != null, "HealthManager requires the world environment.")
	for light in environment_lights:
		assert(light != null, "HealthManager environment lights cannot contain null entries.")
		_environment_light_energies.append(light.light_energy)
	_ambient_light_energy = _world_environment.environment.ambient_light_energy
	_initialize_lives()
	if OS.is_debug_build():
		DebugUI.register_debug_target(self)


func _process(delta: float) -> void:
	# Either draining or recovering
	if _should_drain():
		_set_health(_health - health_drain_per_second * delta)

	var normalized_health := clampf(_health / STARTING_MAX_HEALTH, 0.0, 1.0)
	_visual_health = clampf(visual_health_curve.sample(normalized_health), 0.0, 1.0)
	_animated_visual_health = lerp(
		_animated_visual_health,
		_visual_health,
		1.0 - exp(-VISUAL_HEALTH_SMOOTHING_RATE * delta)
	)
	health_overlay.update_health_visualization(_animated_visual_health)


func _should_drain() -> bool:
	if debug_disable_drain:
		return false
	return is_instance_valid(_focused_object) and _focused_object.has_stickers_remaining()


func _set_health(value: float) -> void:
	_health = clampf(value, 0.0, STARTING_MAX_HEALTH)
	if _health <= 0.0 and not _is_dead:
		_lose_life()


func _initialize_lives() -> void:
	if health_visualization.get_slot_count() == 0:
		push_error("HealthManager requires HealthVisualization to have at least one health slot.")
		set_process(false)
		return
	_reset_lives()


func _reset_lives() -> void:
	_remaining_lives = health_visualization.get_slot_count()
	health_visualization.set_active_slot_count(_remaining_lives)


func _lose_life() -> void:
	if _is_losing_life:
		return
	_is_losing_life = true
	GameState.is_player_input_locked = true
	_health = STARTING_MAX_HEALTH

	if is_instance_valid(_focused_object):
		_focused_object.defocus()

	await get_tree().create_timer(life_loss_before_sound_delay).timeout
	AudioManager.play_sfx(Config.CANDLE_BLOW_SFX_NAME, Config.CANDLE_BLOW_SFX_VOLUME_DB)

	await get_tree().create_timer(life_loss_before_candle_delay).timeout
	_remaining_lives = maxi(_remaining_lives - 1, 0)
	health_visualization.set_active_slot_count(_remaining_lives)

	if _remaining_lives == 0:
		_set_environment_lights_blackout()
		_die()
		return

	_start_environment_lights_dim()
	_start_environment_lights_restore()
	GameState.is_player_input_locked = false
	_is_losing_life = false


func _start_environment_lights_dim() -> void:
	_stop_environment_lights_tween()
	_set_environment_lights_energy_multiplier(_environment_lights_dim_multiplier)

## From a dimmed state, restore the energy of environment lights back to default
func _start_environment_lights_restore() -> void:
	_stop_environment_lights_tween()
	_environment_lights_tween = create_tween()
	_environment_lights_tween.tween_method(
		_set_environment_lights_energy_multiplier,
		_current_light_energy_multiplier,
		1.0,
		_environment_lights_restore_duration
	)


func _stop_environment_lights_tween() -> void:
	if _environment_lights_tween != null and _environment_lights_tween.is_valid():
		_environment_lights_tween.kill()
	_environment_lights_tween = null


func _set_environment_lights_energy_multiplier(energy_multiplier: float) -> void:
	_current_light_energy_multiplier = energy_multiplier
	for light_index in environment_lights.size():
		environment_lights[light_index].light_energy = (
			_environment_light_energies[light_index] * energy_multiplier
		)
	var ambient_light_multiplier := lerpf(1.0, energy_multiplier, 0.5)
	_world_environment.environment.ambient_light_energy = _ambient_light_energy * ambient_light_multiplier


func _set_environment_lights_blackout() -> void:
	_stop_environment_lights_tween()
	_current_light_energy_multiplier = 0.0
	for light in environment_lights:
		light.light_energy = 0.0
	_world_environment.environment.ambient_light_energy = 0.0


func _die() -> void:
	_is_dead = true
	set_process(false) # stops drain, regen
	print("HealthManager: no lives remaining, signalling player death")
	GameState.player_died.emit()


func _on_object_interactible(is_interactible: bool, obj: InteractibleObject) -> void:
	if is_interactible:
		_focused_object = obj
	elif _focused_object == obj: # guard: a stale unfocus must not clear a newer focus
		_focused_object = null


func _on_object_completed(_object_name: String, _is_special_object: bool, completed_stickers: int, total_stickers: int) -> void:
	if completed_stickers < total_stickers:
		_set_health(-0.001) # lose a life if object is not properly cleansed
	else:
		_set_health(STARTING_MAX_HEALTH) # regen health if object was fully cleansed


#region Debug

var debug_disable_drain: bool = false

func debug_get_current_health() -> float:
	return _health

#endregion
