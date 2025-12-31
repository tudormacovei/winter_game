extends Node3D

# position of the object when it is in focus
@export var focus_position: Node3D

# outline of object on mouse hover
@export var outline_material: Material

enum RotatorState {
	ON_TABLE, # Resting on the table, cannot be interacted with except by clicking to begin the interaction
	STATIONARY,
	ROTATING_LEFT,
	ROTATING_RIGHT,
	ROTATING_UP,
	ROTATING_BOTTOM,
}

var _rotator_state = RotatorState.ON_TABLE
var _rotation_remaining = 0.0
var _is_mouse_on_object = false

static var ANIMATION_TIME = 0.1

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	_handle_rotation(delta)

func _input(event: InputEvent) -> void:
	if event.is_action_released("mouse_click_left"):
		# print("LOG: Mouse Click")
		if _rotator_state == RotatorState.ON_TABLE && _is_mouse_on_object:
			_rotator_state = RotatorState.STATIONARY
			# TODO: remove outline on focus gain
			$Object.global_position = focus_position.global_position
		if _rotator_state == RotatorState.STATIONARY && !_is_mouse_on_object:
			_rotator_state = RotatorState.ON_TABLE
			# TODO: add outline on focus loss
			$Object.position = Vector3.ZERO

	# Object can only rotate from stationary beginning
	if _rotator_state != RotatorState.STATIONARY:
		return
	
	# would be cool to be able to use a match block here, but looks like
	# it wouldn't really work because of the function call :/
	if event.is_action_pressed("object_rotate_bottom"):
		_rotator_state = RotatorState.ROTATING_BOTTOM
		_rotation_remaining = 1.0
	if event.is_action_pressed("object_rotate_top"):
		_rotator_state = RotatorState.ROTATING_UP
		_rotation_remaining = 1.0
	if event.is_action_pressed("object_rotate_left"):
		_rotator_state = RotatorState.ROTATING_LEFT
		_rotation_remaining = 1.0
	if event.is_action_pressed("object_rotate_right"):
		_rotator_state = RotatorState.ROTATING_RIGHT
		_rotation_remaining = 1.0

# takes value of a value x between 0.0 and 1.0 and applies a nonlinear
# transformation that keeps the endpoints at 0.0 and 1.0, respectively
func ease_function(x: float) -> float:
	return (x * x + 0.2) / 2

# Handles the rotation of the object with an ease-in and ease-out animation
# TODO:This method of handling the rotation is not good, should be switched
# to an approach that *sets* the object rotation every tick instead of calling
# the rotate(...) function. That way it will be much easier to set custom
# rotation curves to handle the animation 
func _handle_rotation(delta: float) -> void:
	if _rotator_state == RotatorState.ON_TABLE:
		return
	
	# to_rotate is from 0.0 to 1.0 here
	var to_rotate = delta / ANIMATION_TIME * ease_function(_rotation_remaining)
	
	if to_rotate > _rotation_remaining:
		to_rotate = _rotation_remaining
		_rotation_remaining = 0.0
	else:
		_rotation_remaining -= to_rotate
	
	# to_rotate is converted to values from 0.0 to PI / 2 here
	to_rotate *= PI / 2
	
	match _rotator_state:
		RotatorState.ROTATING_BOTTOM:
			$Object.rotate(Vector3.RIGHT, to_rotate)
			pass
		RotatorState.ROTATING_UP:
			$Object.rotate(Vector3.RIGHT, -to_rotate)
			pass
		RotatorState.ROTATING_LEFT:
			$Object.rotate(Vector3.UP, -to_rotate)
			pass
		RotatorState.ROTATING_RIGHT:
			$Object.rotate(Vector3.UP, to_rotate)
			pass

	if _rotation_remaining <= 0.0:
		_rotator_state = RotatorState.STATIONARY

var _original_mesh: Mesh = null

# Add outline to mesh and lift it slightly
func _on_object_mouse_entered() -> void:
	_is_mouse_on_object = true

	var mesh_instance := $Object.get_child(0) as MeshInstance3D
	if mesh_instance == null:
		return
	if outline_material == null:
		push_error("outline_material not set!")
		return

	if _original_mesh != null:
		return # already applied outline

	var mesh := mesh_instance.mesh
	if mesh == null:
		return
	else:
		_original_mesh = mesh

	# Duplicate mesh so we don't modify the imported/shared resource
	var mesh_clone := mesh.duplicate()
	mesh_instance.mesh = mesh_clone

	# Apply next_pass to each surface
	for i in range(mesh.get_surface_count()):
		var base_mat: Material = mesh_clone.surface_get_material(i)
		if base_mat == null:
			base_mat = StandardMaterial3D.new()

		var new_mat := base_mat.duplicate()
		new_mat.next_pass = outline_material

		mesh_clone.surface_set_material(i, new_mat)
		
	$Object.position.z += 0.1

# Restore original mesh without outline material and original position
func _on_object_mouse_exited() -> void:
	_is_mouse_on_object = false

	# Restore original mesh
	var mesh_instance := $Object.get_child(0) as MeshInstance3D
	if mesh_instance == null: # 'as' keyword casts to null on type mismatch
		return

	# if somehow we are in the case where we exit an object we have not entered
	if _original_mesh == null:
		return

	mesh_instance.mesh = _original_mesh
	_original_mesh = null
	
	$Object.position.z -= 0.1
