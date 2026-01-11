extends Node3D

# position of the object when it is in focus
@export var focus_position: Node3D

# outline of object on mouse hover
@export var outline_material: Material

signal object_interactible(is_interactible: bool)

enum RotatorState {
	ON_TABLE, # Resting on the table, cannot be interacted with except by clicking to begin the interaction
	STATIONARY,
	ROTATING_LEFT,
	ROTATING_RIGHT,
	ROTATING_UP,
	ROTATING_BOTTOM,
	DRAGGING, # being dragged around the workspace
}

var _rotator_state = RotatorState.ON_TABLE
var _rotation_remaining = 0.0
var _is_mouse_on_object = false
var _sticker_total: int = 0 # set at initialization time, then readonly constant
var _completed_stickers: int = 0

static var ANIMATION_TIME = 0.1

# TODO: I would really like to move utility functions like this to a different place
# but I can't find a way to do it rn
func get_all_children(node) -> Array:
	var nodes : Array = []
	
	for N in node.get_children():
		if N.get_child_count() > 0:
			nodes.append(N)
			nodes.append_array(get_all_children(N))
		else:
			nodes.append(N)
	return nodes
	
func _set_state(state: RotatorState):
	_rotator_state = state
	print("Set state to " + str(state))
	if state == RotatorState.STATIONARY:
		object_interactible.emit(true)
	else:
		object_interactible.emit(false)
	if state == RotatorState.ON_TABLE:
		_place_object_on_xz_plane($Object)

func _on_sticker_completed():
	_completed_stickers += 1
	print("Completed " + str(_completed_stickers) + " stickers!")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	for child in get_all_children(self):
		if child is Sticker:
			_sticker_total += 1
			
			child.connect("sticker_completed", _on_sticker_completed)
			connect("object_interactible", child._on_object_interactible_change)
			_set_state(RotatorState.ON_TABLE)
	_place_object_on_xz_plane($Object)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	_handle_rotation(delta)
	_handle_drag()

func _input(event: InputEvent) -> void:
	if event.is_action_released("mouse_click_left"):
		if _rotator_state == RotatorState.ON_TABLE && _is_mouse_on_object:
			_set_state(RotatorState.STATIONARY)
			$Object.global_position = focus_position.global_position
			_remove_outline()
			get_viewport().set_input_as_handled()
			return
		if _rotator_state == RotatorState.STATIONARY && !_is_mouse_on_object:
			_set_state(RotatorState.ON_TABLE)
			$Object.position = Vector3.ZERO
			get_viewport().set_input_as_handled()
			return
	
	if event.is_action_pressed("mouse_click_right"):
		print("Right click detected!")
		if _rotator_state == RotatorState.ON_TABLE && _is_mouse_on_object:
			_set_state(RotatorState.DRAGGING)
			
	if event.is_action_released("mouse_click_right"):
		if _rotator_state == RotatorState.DRAGGING:
			_set_state(RotatorState.ON_TABLE)

	# Object can only rotate from stationary beginning
	if _rotator_state != RotatorState.STATIONARY:
		return
	
	if event.is_action_pressed("object_rotate_bottom"):
		_set_state(RotatorState.ROTATING_BOTTOM)
		_rotation_remaining = 1.0
	if event.is_action_pressed("object_rotate_top"):
		_set_state(RotatorState.ROTATING_UP)
		_rotation_remaining = 1.0
	if event.is_action_pressed("object_rotate_left"):
		_set_state(RotatorState.ROTATING_LEFT)
		_rotation_remaining = 1.0
	if event.is_action_pressed("object_rotate_right"):
		_set_state(RotatorState.ROTATING_RIGHT)
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
	if _rotator_state not in [RotatorState.ROTATING_LEFT, RotatorState.ROTATING_RIGHT,
								RotatorState.ROTATING_UP, RotatorState.ROTATING_BOTTOM]:
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
		_set_state(RotatorState.STATIONARY)

func _handle_drag():
	if _rotator_state != RotatorState.DRAGGING:
		return
	# Get intersect between raycast from viewport + mouse and XZ plane
	# Assumption: objects and scene is setup so object ALWAYS sit on the workbench plane
	# if they are at position y=0! So their origin has to be offset
	
	var camera: Camera3D = get_viewport().get_camera_3d()
	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	var origin: Vector3 = camera.project_ray_origin(mouse_pos)
	var direction: Vector3 = camera.project_ray_normal(mouse_pos)
	
	var distance_to_plane_intersect := -origin.y/direction.y
	var intersect = origin + direction * distance_to_plane_intersect # interesect on XZ plane (y=0)
	self.global_position = intersect
	
	print("Ray origin: " + str(origin))
	print("Direction vector " + str(direction))
	print("Distance to plane intersect: " + str(distance_to_plane_intersect))

var _original_mesh: Mesh = null

func _apply_outline():
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


func _remove_outline():
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


# Add outline to mesh and lift it slightly
func _on_object_mouse_entered() -> void:
	#print("INFO:: Mouse entered object")
	_is_mouse_on_object = true
	if _rotator_state == RotatorState.ON_TABLE:
		_apply_outline()

# Restore original mesh without outline material and original position
func _on_object_mouse_exited() -> void:
	#print("INFO:: Mouse exited object")
	_is_mouse_on_object = false
	if _rotator_state == RotatorState.ON_TABLE:
		_remove_outline()
		
# ensures the objects sits on top of the XZ plane, with no geometry sticking out below it
func _place_object_on_xz_plane(object: Node3D):
	var bbox: AABB = _calculate_bounding_box(object, false)
	global_position.y = bbox.size.y / 2
	print("Set object y coordinate to: " + str(global_position.y))

# TODO: move _calculate_bounding_box to utils
func _calculate_bounding_box(parent : Node3D, include_top_level_transform: bool) -> AABB:
	var bounds: AABB = AABB()
	if parent is VisualInstance3D:
		bounds = parent.get_aabb();

	for i in range(parent.get_child_count()):
		var child : Node3D = parent.get_child(i)
		if child:
			var child_bounds : AABB = _calculate_bounding_box(child, true)
			if bounds.size == Vector3.ZERO && parent:
				bounds = child_bounds
			else:
				bounds = bounds.merge(child_bounds)
	if include_top_level_transform:
		bounds = parent.transform * bounds
	return bounds
