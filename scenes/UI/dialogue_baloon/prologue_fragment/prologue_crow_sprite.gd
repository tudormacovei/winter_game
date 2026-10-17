extends Sprite2D

@export var normal_sprite: Texture2D
@export var ugly_eye_sprite: Texture2D

const FADE_DURATION: float = 1.5

var _fade_tween: Tween

# Showing for the first time & hiding will fade the texture
# Changing between textures (normal and ugly eye) will NOT fade

func _ready() -> void:
	modulate.a = 0.0
	visible = false

func show_normal() -> void:
	texture = normal_sprite
	_show_crow()

func show_ugly_eye() -> void:
	texture = ugly_eye_sprite
	_show_crow()

func hide_crow() -> void:
	_hide_crow()

func _show_crow() -> void:
	if visible:
		return
	
	visible = true
	modulate.a = 0.0
	_fade_texture(1.0, FADE_DURATION)

func _hide_crow() -> void:
	if not visible:
		return

	_fade_texture(0.0, FADE_DURATION)
	await _fade_tween.finished
	visible = false

func _fade_texture(target_alpha: float, duration: float) -> Tween:
	if _fade_tween:
		_fade_tween.kill()
	
	_fade_tween = create_tween()
	_fade_tween.set_ease(Tween.EASE_IN_OUT)
	_fade_tween.tween_property(self, "modulate:a", target_alpha, duration)

	return _fade_tween