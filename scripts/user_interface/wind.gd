## Pushes the particles inside the defined box around
class_name Wind
extends GPUParticlesAttractorBox3D

const EPSILON: float = 0.001

enum GustKind { BLOW_OUT, DOOR }

@export_group("Breeze")
@export var breeze_strength: float = 0.05 # breeze is constant, always happening slight movements in wind direction
@export var breeze_speed: float = 0.3 # how fast the breeze changes, in noise cycles per second
@export_group("Blow Out Gust")
@export var blow_out_push: Vector3 = Vector3(-0.2, 0.0, -0.4)
@export var blow_out_duration: float = 1.6
@export_group("Door Gust")
@export var door_push: Vector3 = Vector3(0.5, 0.0, 0.0) # when a character enters or leaves :)
@export var door_duration: float = 1.0

var _gusts: Array[Gust] = []
var _breeze_noise := FastNoiseLite.new()
var _time: float = 0.0 # wraps every hour to avoid floating point precision issues


func _ready() -> void:
	directionality = 1.0 # push along the local -Z axis, the axis look_at points at a target, not toward the box center
	_breeze_noise.frequency = 1.0
	_breeze_noise.fractal_type = FastNoiseLite.FRACTAL_NONE
	GameState.add_wind_gust.connect(add_gust)


func _process(delta: float) -> void:
	_time = fmod(_time + delta, 3600.0)
	var noise_position_x := _time * breeze_speed
	var noise_position_z := noise_position_x + 1000.0
	var breeze_direction := Vector3(_breeze_noise.get_noise_1d(noise_position_x), 0.0, _breeze_noise.get_noise_1d(noise_position_z))
	var wind_push := breeze_direction * breeze_strength

	for gust_index in range(_gusts.size() - 1, -1, -1):
		var active_gust := _gusts[gust_index]
		active_gust.time_left -= delta
		if active_gust.time_left <= 0.0:
			_gusts.remove_at(gust_index)
			continue
		var gust_remaining_fraction := active_gust.time_left / active_gust.duration
		wind_push += active_gust.push * gust_remaining_fraction

	var wind_strength := wind_push.length()
	if wind_strength < EPSILON:
		strength = 0.0
		return
	strength = wind_strength

	var wind_direction := wind_push / wind_strength
	var point_downwind := global_position + wind_direction
	var is_wind_vertical := absf(wind_direction.y) > 0.99
	var look_at_up_axis := Vector3.RIGHT if is_wind_vertical else Vector3.UP
	look_at(point_downwind, look_at_up_axis) # it's very weird IMO, but you gotta rotate the attractor object to change the direction of the force??


func add_gust(kind: GustKind) -> void:
	var new_gust := Gust.new()
	match kind:
		GustKind.BLOW_OUT:
			new_gust.push = blow_out_push
			new_gust.duration = blow_out_duration
		GustKind.DOOR:
			new_gust.push = door_push
			new_gust.duration = door_duration
	new_gust.duration = maxf(new_gust.duration, EPSILON)
	new_gust.time_left = new_gust.duration
	_gusts.append(new_gust)


class Gust:
	var push: Vector3
	var duration: float
	var time_left: float
