@tool
class_name HealthOverlay extends Node2D

const VISUAL_HEALTH_SMOOTHING_RATE: float = 6.0

@export var visual_health_curve: Curve

@export_group("Tint")
# The tints multiply the color of the branch textures
@export var gain_tint: Color = Color(0.35, 1.0, 0.35)
@export var loss_tint: Color = Color(1.0, 0.25, 0.25)
@export var tint_full_at_percent: float = 20.0
@export var tint_curve: Curve # x is time of the branch movement, y is tint strength

@export_group("Change Sequence")
@export var fade_duration: float = 0.4
@export var wait_before_change: float = 0.6
@export var wait_after_change: float = 0.6

var _target_health: float = 1.0 # normalized
var _displayed_visual_health: float = 1.0
var _current_max_tint_intensity: float = 0.0  # max tint intensity reached in current gain/drain animation
var _tint_time: float = 0.0 # time since the last animated health change
var _tint_color: Color = Color.WHITE
var _is_focused: bool = false
var _fade_tween: Tween = null


func _ready() -> void:
	position = get_viewport_rect().size / 2.0
	if Engine.is_editor_hint():
		return
	assert(visual_health_curve != null, "HealthOverlay needs a visual health curve")
	assert(tint_curve != null, "HealthOverlay needs a tint curve")
	modulate.a = 0.0


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var weight := 1.0 - exp(-VISUAL_HEALTH_SMOOTHING_RATE * delta)
	_displayed_visual_health = lerpf(_displayed_visual_health, visual_health_curve.sample(_target_health), weight)
	for child in get_children():
		if child is BranchRing:
			child.update_health_visualization(_displayed_visual_health)

	_tint_time += delta
	var tint_duration := log(100.0) / VISUAL_HEALTH_SMOOTHING_RATE
	var tint_progress := clampf(_tint_time / tint_duration, 0.0, 1.0)
	var displayed_tint_intensity := clampf(_current_max_tint_intensity * tint_curve.sample(tint_progress), 0.0, 1.0)

	modulate = Color(Color.WHITE.lerp(_tint_color, displayed_tint_intensity), modulate.a)


## In focus, the overlay is always visible.
## Out of focus, it is only visible during a change to the HP
func set_is_focused(is_focused: bool) -> void:
	_is_focused = is_focused
	if _fade_tween:
		_fade_tween.kill()
	modulate.a = 1.0 if is_focused else 0.0


func set_health(normalized_health: float, is_animated: bool) -> void:
	if is_animated:
		var change := normalized_health - _target_health
		_tint_color = gain_tint if change > 0.0 else loss_tint
		_current_max_tint_intensity = clampf(absf(change) / (tint_full_at_percent / 100.0), 0.0, 1.0)
		_tint_time = 0.0
	else:
		_displayed_visual_health = visual_health_curve.sample(normalized_health)
	_target_health = normalized_health


func fade_in() -> void:
	if _is_focused:
		return
	_fade_to(1.0)
	await get_tree().create_timer(fade_duration + wait_before_change, false).timeout # false: the timer stops while the game is paused


func fade_out() -> void:
	if _is_focused:
		return
	await get_tree().create_timer(wait_after_change, false).timeout
	if not _is_focused:
		_fade_to(0.0)


# Callers wait with a timer, not on the tween: a killed tween never emits finished
func _fade_to(alpha: float) -> void:
	if _fade_tween:
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "modulate:a", alpha, fade_duration)
