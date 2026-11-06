extends Sprite2D

@export var normal_sprite: Texture2D
@export var ugly_eye_sprite: Texture2D

const WIPE_DURATION: float = 1.0
const SPRITE_SWITCH_DURATION: float = 0.8

var _wipe_tween: Tween
var _is_hiding: bool = false

# Showing for the first time fades the crow in, hiding fades it out (continuing the same animation)
# Changing between textures (normal and ugly eye) reveals the new texture with a lil animation
# (very edge case) starting a wipe while another is running finishes the running one instantly !

func _ready() -> void:
	_reset_to_hidden_state()
	visible = false

func show_normal() -> void:
	_show_texture(normal_sprite)

func show_ugly_eye() -> void:
	_show_texture(ugly_eye_sprite)

func hide_crow() -> void:
	_hide_crow()

# Depending on current state of the sprite (visible or not), shows the given texture
func _show_texture(new_texture: Texture2D) -> void:
	if _is_hiding:
		_finish_running_wipe()

	if not visible:
		# first time show
		texture = new_texture
		visible = true
		_reset_to_hidden_state()
		_wipe("shader_parameter/visibility_end", 1.0, WIPE_DURATION)
	elif texture != new_texture:
		# sprite switch
		_finish_running_wipe()
		material.set("shader_parameter/previous_texture", texture)
		material.set("shader_parameter/sprite_switch_progress", 0.0)
		texture = new_texture
		_wipe("shader_parameter/sprite_switch_progress", 1.0, SPRITE_SWITCH_DURATION)

func _hide_crow() -> void:
	if not visible or _is_hiding:
		return

	_finish_running_wipe()
	_is_hiding = true
	_wipe("shader_parameter/visibility_start", 1.0, WIPE_DURATION)
	await _wipe_tween.finished
	_is_hiding = false
	visible = false

func _reset_to_hidden_state() -> void:
	material.set("shader_parameter/visibility_start", 0.0)
	material.set("shader_parameter/visibility_end", 0.0)
	material.set("shader_parameter/sprite_switch_progress", 1.0)

func _finish_running_wipe() -> void:
	if _wipe_tween and _wipe_tween.is_running():
		_wipe_tween.custom_step(maxf(WIPE_DURATION, SPRITE_SWITCH_DURATION))

func _wipe(param: String, target: float, duration: float) -> void:
	if _wipe_tween:
		_wipe_tween.kill()

	_wipe_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_wipe_tween.tween_property(material, param, target, duration)
