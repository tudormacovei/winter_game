# Wrapper for ObjectWithStickers that handles player interaction via a state machine.
# Objects can be picked up, rotated, dragged around, and completed when dragged to a completion area.
#
# Setup: Call set_spawn_data() or set exports before use
class_name InteractibleObject
extends Node3D

signal object_interactible(is_interactible: bool)
signal object_completed(object_name: String, is_special_object: bool, completed_stickers: int, total_stickers: int)
signal object_state_changed(state: State)
signal object_pending_completion_changed(is_pending: bool)

# Setup variables, set before node enters scene tree
var focus_position: Node3D
var object_completed_area: Area3D
var object_scene: PackedScene # ObjectWithStickers scene to load
@export var outline_material: Material

enum State {
	ON_TABLE,
	FOCUSED,
	ROTATING_LEFT,
	ROTATING_RIGHT,
	ROTATING_UP,
	ROTATING_BOTTOM,
	DRAGGING,
}

var _object: ObjectWithStickers = null
var _state = State.ON_TABLE
var _rotation_remaining = 0.0
var _is_mouse_on_object = false
var _sticker_total: int = 0 # set at initialization time, then readonly constant
var _completed_stickers: int = 0
var _is_pending_completion: bool = false
var _original_mesh: Mesh = null

static var ANIMATION_TIME = 0.1
static var HOVERED_SCALE = Vector3(1.02, 1.02, 1.02)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if object_scene == null:
		print("InteractibleObject: Attempted to instantiate null object scene. Aborting...")
		queue_free() # delete self due to lack of child object

	_object = object_scene.instantiate()
	if not (_object is ObjectWithStickers):
		# TODO: replace prints with warning logs
		print("InteractibleObject: Object scene is not of type ObjectWithStickers. Type: " + str(_object.get_class()))
	add_child(_object)
	_place_object_on_xz_plane(_object)
	
	_object.mouse_entered.connect(_on_object_mouse_entered)
	_object.mouse_exited.connect(_on_object_mouse_exited)
	_object.area_entered.connect(_on_object_area_entered)
	_object.area_exited.connect(_on_object_area_exited)

	# Stickers are placed asynchronously — wait for the signal before scanning
	_object.stickers_placed.connect(_on_stickers_placed)


func _process(delta: float) -> void:
	_handle_rotation(delta)
	_handle_drag()
	# wait for player to place object on table before complete
	if _is_pending_completion and _state == State.ON_TABLE:
		complete_object()


func _input(event: InputEvent) -> void:
	if event.is_action_released("mouse_click_left"):
		if _state == State.ON_TABLE && _is_mouse_on_object:
			_set_state(State.FOCUSED)
			_object.global_position = focus_position.global_position
			_remove_outline()
			get_viewport().set_input_as_handled()
			return
		if _state == State.FOCUSED && !_is_mouse_on_object:
			_set_state(State.ON_TABLE)
			_object.position = Vector3.ZERO
			get_viewport().set_input_as_handled()
			return
	
	if event.is_action_pressed("mouse_click_right"):
		if _state == State.ON_TABLE && _is_mouse_on_object:
			_set_state(State.DRAGGING)
			
	if event.is_action_released("mouse_click_right"):
		if _state == State.DRAGGING:
			_set_state(State.ON_TABLE)

	# Object can only rotate from FOCUSED beginning
	if _state != State.FOCUSED:
		return
	
	if event.is_action_pressed("object_rotate_bottom"):
		_set_state(State.ROTATING_BOTTOM)
		_rotation_remaining = 1.0
	if event.is_action_pressed("object_rotate_top"):
		_set_state(State.ROTATING_UP)
		_rotation_remaining = 1.0
	if event.is_action_pressed("object_rotate_left"):
		_set_state(State.ROTATING_LEFT)
		_rotation_remaining = 1.0
	if event.is_action_pressed("object_rotate_right"):
		_set_state(State.ROTATING_RIGHT)
		_rotation_remaining = 1.0


func _on_object_mouse_entered() -> void:
	_is_mouse_on_object = true
	if _state == State.ON_TABLE:
		_apply_outline()
		CursorManager.request_cursor(CursorManager.CursorType.HOVER)


func _on_object_mouse_exited() -> void:
	_is_mouse_on_object = false
	if _state == State.ON_TABLE:
		_remove_outline()
		CursorManager.release_cursor(CursorManager.CursorType.HOVER)


func _on_object_area_entered(area: Area3D) -> void:
	# wait for player to place the object on the table before completing it
	if area == object_completed_area:
		_is_pending_completion = true
		object_pending_completion_changed.emit(true)


func _on_object_area_exited(area: Area3D) -> void:
	if area == object_completed_area and not is_queued_for_deletion():
		_is_pending_completion = false
		object_pending_completion_changed.emit(false)


func _on_stickers_placed() -> void:
	for child in Utils.get_all_children(self ):
		if child is Sticker:
			_sticker_total += 1
			child.connect("sticker_completed", _on_sticker_completed)
			connect("object_interactible", child._on_object_interactible_change)
	_set_state(State.ON_TABLE)


func _on_sticker_completed():
	_completed_stickers += 1
	print("Completed " + str(_completed_stickers) + " stickers!")


# Set all data needed for correct functionality
func set_spawn_data(focus_position: Node3D, object_completed_area: Area3D, object_scene: PackedScene):
	self.focus_position = focus_position
	self.object_completed_area = object_completed_area
	self.object_scene = object_scene


func _set_state(state: State):
	if _state != state:
		CursorManager.clear_requests()
	_state = state
	#print("Set state to " + str(state))
	if state == State.FOCUSED:
		object_interactible.emit(true)
	else:
		object_interactible.emit(false)
	if state == State.ON_TABLE:
		_place_object_on_xz_plane(_object)
	
	object_state_changed.emit(state)


# Handles the rotation of the object with an ease-in and ease-out animation
# TODO:This method of handling the rotation is not good, should be switched
# to an approach that *sets* the object rotation every tick instead of calling
# the rotate(...) function.
func _handle_rotation(delta: float) -> void:
	if _state not in [State.ROTATING_LEFT, State.ROTATING_RIGHT,
								State.ROTATING_UP, State.ROTATING_BOTTOM]:
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
	
	match _state:
		State.ROTATING_BOTTOM:
			_object.rotate(Vector3.RIGHT, to_rotate)
		State.ROTATING_UP:
			_object.rotate(Vector3.RIGHT, -to_rotate)
		State.ROTATING_LEFT:
			_object.rotate(Vector3.FORWARD, -to_rotate)
		State.ROTATING_RIGHT:
			_object.rotate(Vector3.FORWARD, to_rotate)

	if _rotation_remaining <= 0.0:
		_set_state(State.FOCUSED)


func _handle_drag():
	if _state != State.DRAGGING:
		return
	# Get intersect between raycast from viewport + mouse and XZ plane
	# Assumption: objects and scene is setup so object ALWAYS sit on the workbench plane
	# if they are at position y=0! So their origin has to be offset
	
	var camera: Camera3D = get_viewport().get_camera_3d()
	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	var origin: Vector3 = camera.project_ray_origin(mouse_pos)
	var direction: Vector3 = camera.project_ray_normal(mouse_pos)
	
	var distance_to_plane_intersect := -origin.y / direction.y
	var intersect = origin + direction * distance_to_plane_intersect # interesect on XZ plane (y=0)
	self.global_position = intersect
	_place_object_on_xz_plane(_object) # intersect y coord is incorrect, update to correct one
	
	#print("Ray origin: " + str(origin))
	#print("Direction vector " + str(direction))
	#print("Distance to plane intersect: " + str(distance_to_plane_intersect))


func _apply_outline():
	var mesh_instance := _object.get_child(0) as MeshInstance3D
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

	_object.scale = HOVERED_SCALE


func _remove_outline():
	# Restore original mesh
	var mesh_instance := _object.get_child(0) as MeshInstance3D
	if mesh_instance == null: # 'as' keyword casts to null on type mismatch
		return

	# failsafe if somehow we are in the case where we exit an object we have not entered
	if _original_mesh == null:
		return

	mesh_instance.mesh = _original_mesh
	_original_mesh = null
	_object.scale = Vector3.ONE


func complete_object():
	print("Object Completed! Stickers completed: " + str(_completed_stickers) + "/" + str(_sticker_total))
	
	_set_state(State.ON_TABLE)
	emit_signal("object_completed", object_scene.resource_path.get_file().get_basename(), _object.is_special_object, _completed_stickers, _sticker_total)
	queue_free()

# Ensures the objects sits on top of the XZ plane, with no geometry sticking out below it
func _place_object_on_xz_plane(object: Node3D):
	var bbox: AABB = Utils._calculate_bounding_box(object, false)
	global_position.y = bbox.size.y / 2

# takes value of a value x between 0.0 and 1.0 and applies a nonlinear
# transformation that keeps the endpoints at 0.0 and 1.0, respectively
func ease_function(x: float) -> float:
	return (x * x + 0.2) / 2
