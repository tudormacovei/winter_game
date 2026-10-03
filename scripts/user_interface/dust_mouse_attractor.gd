class_name DustMouseAttractor
extends GPUParticlesAttractorSphere3D

const EPSILON: float = 0.001

@export var dust_particles: GPUParticles3D
@export var push_strength: float = 1.0 # strength at full mouse speed
@export var full_push_mouse_speed: float = 200.0 # mouse speed (pixels per second) when push has full strength
@export var speed_smoothing: float = 5.0 # higher values track mouse speed with more accuracy, more jitter tho

var _last_mouse_position := Vector2.ZERO
var _smoothed_mouse_speed: float = 0.0


func _ready() -> void:
	_last_mouse_position = get_viewport().get_mouse_position()


func _process(delta: float) -> void:
	var mouse_position := get_viewport().get_mouse_position()
	var mouse_speed := mouse_position.distance_to(_last_mouse_position) / maxf(delta, EPSILON)
	_last_mouse_position = mouse_position
	_smoothed_mouse_speed = lerpf(_smoothed_mouse_speed, mouse_speed, 1.0 - exp(-speed_smoothing * delta))

	var camera := get_viewport().get_camera_3d()
	var dust_plane := Plane(dust_particles.global_basis.z, dust_particles.global_position)
	var mouse_position_on_dust_plane = dust_plane.intersects_ray(camera.project_ray_origin(mouse_position), camera.project_ray_normal(mouse_position))
	if mouse_position_on_dust_plane == null:
		strength = 0.0
		return

	global_position = mouse_position_on_dust_plane
	strength = -push_strength * clampf(_smoothed_mouse_speed / full_push_mouse_speed, 0.0, 1.0)
