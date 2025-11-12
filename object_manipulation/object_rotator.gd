extends Node3D

enum RotatorState {
	Stationary,
	RotatingLeft,
	RotatingRight,
	RotatingUp,
	RotatingBottom
}

var rotatorState = RotatorState.Stationary
var rotationRemaining = 0.0
var elapsedTime = 0.0

static var ANIMATION_TIME = 0.1

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	handle_rotation(delta)
	pass

func _input(event: InputEvent) -> void:
	# disregard input if rotation ongoing
	if rotatorState != RotatorState.Stationary:
		return
	
	# would be cool to be able to use a match block here, but looks like
	# it wouldn't really work
	if event.is_action_pressed("object_rotate_bottom"):
		rotatorState = RotatorState.RotatingBottom
		rotationRemaining = 1.0
	if event.is_action_pressed("object_rotate_top"):
		rotatorState = RotatorState.RotatingUp
		rotationRemaining = 1.0
	if event.is_action_pressed("object_rotate_left"):
		rotatorState = RotatorState.RotatingLeft
		rotationRemaining = 1.0
	if event.is_action_pressed("object_rotate_right"):
		rotatorState = RotatorState.RotatingRight
		rotationRemaining = 1.0

# takes value of a value x between 0.0 and 1.0 and applies a nonlinear
# transformation that keeps the endpoints at 0.0 and 1.0, respectively
func ease_function(x : float) -> float:
	return (x*x + 0.2)/2

# Handles the rotation of the object with an ease-in and ease-out animation
# TODO:This method of handling the rotation is not good, should be switched
# to an approach that *sets* the object rotation every tick instead of calling
# the rotate(...) function. That way it will be much easier to set custom
# rotation curves to handle the animation 
func handle_rotation(delta: float) -> void:
	# to_rotate is from 0.0 to 1.0 here
	var to_rotate = delta / ANIMATION_TIME * ease_function(rotationRemaining) 
	
	if to_rotate > rotationRemaining:
		to_rotate = rotationRemaining
		rotationRemaining = 0.0
	else:
		rotationRemaining -= to_rotate
	
	# to_rotate is converted to values from 0.0 to PI / 2 here
	to_rotate *= PI / 2
	
	match rotatorState:
		RotatorState.RotatingBottom:
			$Object_Root.rotate(Vector3.RIGHT, to_rotate)
			pass
		RotatorState.RotatingUp:
			$Object_Root.rotate(Vector3.RIGHT, -to_rotate)
			pass
		RotatorState.RotatingLeft:
			$Object_Root.rotate(Vector3.UP, -to_rotate)
			pass
		RotatorState.RotatingRight:
			$Object_Root.rotate(Vector3.UP, to_rotate)
			pass

	if rotationRemaining == 0.0:
		rotatorState = RotatorState.Stationary
