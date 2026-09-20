@tool
class_name Candle
extends HealthVisualizationSlot

@export var light_fade_duration: float = 0.4

@export var is_on: bool = true:
	set(value):
		is_on = value
		if not is_node_ready():
			return
		if flame.emitting == value:
			return
		flame.emitting = value
		if not value:
			smoke.restart()
		if _light_tween:
			_light_tween.kill()
		_light_tween = create_tween()
		_light_tween.tween_property(omni_light, "light_energy", _lit_light_energy if value else 0.0, light_fade_duration)

@onready var flame: GPUParticles3D = $Flame
@onready var smoke: GPUParticles3D = $Smoke
@onready var omni_light: OmniLight3D = $OmniLight3D

var _lit_light_energy: float = 0.0
var _light_tween: Tween


func _ready() -> void:
	_lit_light_energy = omni_light.light_energy


func set_is_on(value: bool) -> void:
	is_on = value
