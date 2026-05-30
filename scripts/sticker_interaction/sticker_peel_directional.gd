@tool
class_name StickerPeelDirectional extends StickerPeel

# Direction in sticker-local space the player must drag toward.
# 0° = sticker-local forward (+Z), positive rotates around local +Y (CCW from above).
@export var correct_angle_degrees: float = 0.0 : set = _set_correct_angle_degrees
# Angular wedge (centered on correct_angle_degrees) inside which a drag counts as correct.
@export var angle_width_degrees: float = 45.0
@export var randomize_direction: bool = true
# Quantization step for randomized direction. 90 => uniform pick of N/E/S/W.
@export var randomization_increment_degrees: float = 90.0

func _ready() -> void:
	# In editor: skip runtime setup, just push the current angle to the shader so the inspector preview works.
	if Engine.is_editor_hint():
		_apply_wave_direction_to_existing_material()
		return

	super._ready()

	if randomize_direction:
		var increment: float = max(randomization_increment_degrees, 0.001)
		var steps: int = max(int(round(360.0 / increment)), 1)
		correct_angle_degrees = float(randi() % steps) * increment

	_setup_shader_material()


func _set_correct_angle_degrees(value: float) -> void:
	correct_angle_degrees = value
	if Engine.is_editor_hint() and is_inside_tree():
		_apply_wave_direction_to_existing_material()


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


# Material params must be edited per-instance with the peel direciton
func _setup_shader_material() -> void:
	var mesh_instance := _find_mesh_instance(self)
	if mesh_instance == null:
		return
	
	# The Surface 0 override is the template ShaderMaterial set in the inspector.
	# We duplicate so each per-instance wave_direction edit does not bleed across stickers sharing the resource.
	var template := mesh_instance.get_surface_override_material(0)
	if not (template is ShaderMaterial):
		return
	var mat: ShaderMaterial = template.duplicate() as ShaderMaterial
	mesh_instance.set_surface_override_material(0, mat)
	mat.set_shader_parameter(&"wave_direction", _wave_direction_uv())


# Writes wave_direction onto whatever ShaderMaterial currently sits on Surface 0, without duplicating.
# Used at edit time so the inspector preview reflects correct_angle_degrees live.
func _apply_wave_direction_to_existing_material() -> void:
	var mesh_instance := _find_mesh_instance(self)
	if mesh_instance == null:
		return
	var mat := mesh_instance.get_surface_override_material(0)
	if not (mat is ShaderMaterial):
		return
	(mat as ShaderMaterial).set_shader_parameter(&"wave_direction", _wave_direction_uv())


# Wave direction in UV space.
func _wave_direction_uv() -> Vector2:
	var rad: float = deg_to_rad(correct_angle_degrees)
	return Vector2(-cos(rad), sin(rad))
