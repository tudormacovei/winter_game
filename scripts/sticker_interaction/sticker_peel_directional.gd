@tool
class_name StickerPeelDirectional extends StickerPeel

# Direction in sticker-local space the player must drag toward.
# 0° = sticker-local forward (+Z), positive rotates around local +Y (CCW from above).
@export var correct_angle_degrees: float = 0.0 : set = _set_correct_angle_degrees
# Angular wedge centered on correct_angle_degrees, inside which a drag counts as correct.
@export var angle_width_degrees: float = 45.0
@export var randomize_direction: bool = true
@export var randomization_increment_degrees: float = 90.0  # 90 => uniform pick of N/E/S/W.

func _ready() -> void:
	super._ready() # base picks + applies the spot

	if randomize_direction and not Engine.is_editor_hint():
		var increment: float = max(randomization_increment_degrees, 0.001)
		var steps: int = max(int(round(360.0 / increment)), 1)
		correct_angle_degrees = float(randi() % steps) * increment

	_apply_wave_direction()


func _set_correct_angle_degrees(value: float) -> void:
	correct_angle_degrees = value
	# Editor preview: the inspector shows changes to correct_angle_degrees live
	if Engine.is_editor_hint() and is_inside_tree():
		_apply_wave_direction()


# Projects the sticker-local completion angle into world XZ.
# Sticker's local +Z is "forward" on its face; rotating that around local +Y by the chosen angle
# yields the in-plane drag target. Drop Y to compare against drag direction (already world XZ).
func _compute_correct_dir_world() -> Vector3:
	var local_dir := Vector3.BACK.rotated(Vector3.UP, deg_to_rad(correct_angle_degrees))
	var world_dir: Vector3 = global_transform.basis * local_dir
	var xz := Vector3(world_dir.x, 0.0, world_dir.z)
	if xz.length_squared() < 1e-6:
		return Vector3.BACK
	return xz.normalized()


func _passes_completion_check(fraction: float) -> bool:
	if fraction < COMPLETION_THRESHOLD:
		return false
	var drag_xz := Vector3(_drag_dir.x, 0.0, _drag_dir.z)
	if drag_xz.length_squared() < 1e-6:
		return false
	# Recompute each check: the sticker's parent InteractibleObject rotates during gameplay,
	# so the world-space target direction is only valid at the moment of release.
	var correct_dir_world := _compute_correct_dir_world()
	var dot_val: float = clamp(drag_xz.normalized().dot(correct_dir_world), -1.0, 1.0)
	var angle_between: float = acos(dot_val)
	return angle_between <= deg_to_rad(angle_width_degrees) * 0.5


func _apply_wave_direction() -> void:
	set_shader_value(&"wave_direction", _wave_direction_uv())


# Wave direction in UV space.
func _wave_direction_uv() -> Vector2:
	var rad: float = deg_to_rad(correct_angle_degrees)
	return Vector2(-cos(rad), sin(rad))
