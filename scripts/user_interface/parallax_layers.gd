class_name ParallaxLayers
extends Node3D

@export var layers: Array[Sprite3D] # back to front

@export_group("Mouse Parallax")
# what % of screen height the layer moves when the mouse is at the screen edge (moves 0 at center), so it goes +- this amount in total movement for both edges
@export_range(0.0, 4.5, 0.1) var back_layer_mouse_strength: float = 1.0
@export_range(0.0, 4.5, 0.1) var front_layer_mouse_strength: float = 4.5

@export_group("Breathing")
## Seconds for one full 'breath' movement, so lower is faster
@export_range(1.0, 30.0, 0.5) var breathing_period: float = 8.0 # seconds
@export_range(0.0, 1.0, 0.05) var breathing_rotation: float = 1.0 # degrees
@export_range(0.0, 1.0, 0.05) var breathing_movement: float = 1.0 # % of screen height

@export_group("Pulsing-Slash-Throbbing Animation")
@export var pulse_ring_texture: Texture2D
@export var pulse_noise_texture: Texture2D
@export_range(0.0, 1.0, 0.05) var pulse_noise_amount: float = 1.0
## Seconds for a pulse to make a full dark-bright-dark cycle, so lower is faster (again :) )
@export_range(1.0, 30.0, 0.5) var pulse_period: float = 16.0 # seconds
@export_range(1.0, 8.0, 0.1) var pulse_ring_count: float = 3.5
@export_range(0.0, 1.0, 0.05) var pulse_min_multiplier: float = 0.0
@export_range(1.0, 10.0, 0.1) var pulse_max_multiplier: float = 5.0

const LAYER_SHADER: Shader = preload("res://3d_assets/shaders/parallax_layer.gdshader")
const MOUSE_SMOOTHING_RATE: float = 8.0
const LAYER_PHASE_STEP: float = 0.3 # for visual variety offset the layers so they are not playing the same anim
const ROTATION_PHASE_OFFSET: float = 0.125 # offset the rotation so it is not obviously locked to the movement

# TODO: are floating point errors worth looking at for this time var? (I mean precision errors due to accumulation)
var _elapsed_time: float = 0.0 # seconds
var _mouse_offset: Vector2 = Vector2.ZERO # -1 to 1 from the screen center

func _ready() -> void:
	for layer_index in layers.size():
		var layer := layers[layer_index]
		var layer_material := ShaderMaterial.new()

		layer_material.shader = LAYER_SHADER
		layer_material.set_shader_parameter("texture_albedo", layer.texture)
		layer_material.set_shader_parameter("pulse_ring_texture", pulse_ring_texture)
		layer_material.set_shader_parameter("pulse_noise_texture", pulse_noise_texture)
		layer_material.render_priority = layer_index
		layer.material_override = layer_material

func _process(delta: float) -> void:
	_elapsed_time += delta
	# smooth the mouse offset so parralax animation is not immediate, looks better
	_mouse_offset = _mouse_offset.lerp(_get_mouse_offset_from_screen_center(), 1.0 - exp(-MOUSE_SMOOTHING_RATE * delta))
	for layer_index in layers.size():
		_update_layer(layer_index)

func _get_mouse_offset_from_screen_center() -> Vector2:
	var screen_size := get_viewport().get_visible_rect().size
	var mouse_offset := get_viewport().get_mouse_position() / screen_size * 2.0 - Vector2.ONE
	return mouse_offset.clampf(-1.0, 1.0)

## Returns 0.0 for the back layer, 1.0 for the front layer
func _get_front_fraction(layer_index: int) -> float:
	return layer_index / maxf(layers.size() - 1, 1.0)

func _update_layer(layer_index: int) -> void:
	var layer := layers[layer_index]
	var front_fraction := _get_front_fraction(layer_index)
	var mouse_strength := lerpf(back_layer_mouse_strength, front_layer_mouse_strength, front_fraction)
	var breathing_angle := TAU * (_elapsed_time / breathing_period + layer_index * LAYER_PHASE_STEP)

	var movement := Vector2.from_angle(breathing_angle) * breathing_movement # % of screen height, drifts in a small circle
	movement += Vector2(-_mouse_offset.x, _mouse_offset.y) * mouse_strength # against the mouse, screen-down is world-up
	var screen_height := layer.texture.get_height() * layer.pixel_size # a layer at scale 1 fills the screen
	var layer_offset := movement / 100.0 * screen_height

	layer.position = Vector3(layer_offset.x, layer_offset.y, 0.0)
	layer.rotation_degrees.z = breathing_rotation * sin(breathing_angle + TAU * ROTATION_PHASE_OFFSET)
	var layer_material := layer.material_override as ShaderMaterial
	layer_material.set_shader_parameter("pulse_cycles", _elapsed_time / pulse_period)
	layer_material.set_shader_parameter("pulse_ring_count", pulse_ring_count)
	layer_material.set_shader_parameter("pulse_noise_amount", pulse_noise_amount)
	layer_material.set_shader_parameter("pulse_min_multiplier", pulse_min_multiplier)
	layer_material.set_shader_parameter("pulse_max_multiplier", pulse_max_multiplier)
