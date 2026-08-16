@tool
class_name FocusBlink
extends ColorRect

signal blink_closed(is_focused: bool)

@export_group("Blink Preview")
@export_range(0.0, 1.0, 0.01)
var eye_open_amount: float = 1.0

@export_group("Eye Shape")
@export_range(0.0, 6.0, 0.01)
var vertical_point_distance: float = 3.0

@export_range(0.0, 8.0, 0.01)
var horizontal_point_distance: float = 4.0

@export_range(0.1, 3.0, 0.01)
var blink_duration: float = 0.6

var _open_amount_tween: Tween


func _ready() -> void:
	_apply_shader_parameters()


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		_apply_shader_parameters()


func blink_once(is_focused: bool) -> void:
	if _open_amount_tween:
		_open_amount_tween.kill()

	_open_amount_tween = create_tween()
	_open_amount_tween.tween_method(
		_update_eye_open_amount,
		eye_open_amount,
		0.0,
		blink_duration * 0.5
	).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN)

	# emit signal when eye is fully closed: good moment to change other UI elements (changes hidden by the blink)
	_open_amount_tween.tween_callback(func() -> void: blink_closed.emit(is_focused))
	
	_open_amount_tween.tween_method(
		_update_eye_open_amount,
		0.0,
		1.0,
		blink_duration * 0.5
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _update_eye_open_amount(new_open_amount: float) -> void:
	eye_open_amount = new_open_amount
	if not is_inside_tree():
		return

	var blink_material := material as ShaderMaterial
	if blink_material == null:
		return

	blink_material.set_shader_parameter("eye_open_amount", eye_open_amount)


func _apply_shader_parameters() -> void:
	if not is_inside_tree():
		return

	var blink_material := material as ShaderMaterial
	if blink_material == null:
		return

	blink_material.set_shader_parameter("eye_open_amount", eye_open_amount)
	blink_material.set_shader_parameter("vertical_point_distance", vertical_point_distance)
	blink_material.set_shader_parameter("horizontal_point_distance", horizontal_point_distance)
