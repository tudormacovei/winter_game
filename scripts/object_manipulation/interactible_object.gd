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
@export var focus_curve: Curve
@export var unfocus_curve: Curve

enum State {
	ON_TABLE,
	FOCUSED,
	ROTATING,
	DRAGGING,
}

var _object: ObjectWithStickers = null
var _state := State.ON_TABLE
var _is_mouse_on_object := false
var _sticker_total: int = 0 # set at initialization time, then readonly constant
var _completed_stickers: int = 0
var _is_pending_completion := false
var _original_mesh: Mesh = null

static var HOVERED_SCALE = Vector3(1.02, 1.02, 1.02) # object scale on mouse hover
static var DRAG_THRESHOLD_FRACTION: float = 0.008 # fraction of viewport width before a press becomes a drag
# Full revolutions when dragging across the viewport width
static var ROTATION_REVOLUTIONS_PER_WIDTH: float = 1.0
static var ROTATION_SNAP_DURATION: float = 0.15
static var FOCUS_DURATION: float = 0.1

var _drag_threshold_px: float = 0.0
var _drag_start_pos: Vector2 = Vector2.ZERO
var _mouse_down: bool = false

var _rotation_sensitivity: float = 0.0  # radians per pixel, set in _ready
var _stickers_hovered: int = 0
var _hovered_stickers: Array[Sticker] = []
var _snap_tween: Tween
var _focus_position_tween: Tween
var _focus_rotation_tween: Tween
static var _snap_orientations: Array[Basis] = []

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if object_scene == null:
		Utils.debug_error("InteractibleObject: Attempted to instantiate null object scene. Check that the day resource does not contain empty objects!")
		queue_free() # delete self due to lack of child object
		return

	_object = object_scene.instantiate()
	if not (_object is ObjectWithStickers):
		# TODO: replace prints with warning logs
		Utils.debug_error("InteractibleObject: Object scene is not of type ObjectWithStickers. Type: " + str(_object.get_class()))
		queue_free()
		return
	add_child(_object)
	_place_object_on_xz_plane(_object)
	
	_object.mouse_entered.connect(_on_object_mouse_entered)
	_object.mouse_exited.connect(_on_object_mouse_exited)
	_object.area_entered.connect(_on_object_area_entered)
	_object.area_exited.connect(_on_object_area_exited)

	# Stickers are placed asynchronously — wait for the signal before scanning
	_object.stickers_placed.connect(_on_stickers_placed)

	_drag_threshold_px = get_viewport().get_visible_rect().size.x * DRAG_THRESHOLD_FRACTION
	_rotation_sensitivity = TAU * ROTATION_REVOLUTIONS_PER_WIDTH / get_viewport().get_visible_rect().size.x


func _process(_delta: float) -> void:
	_handle_drag()
	# wait for player to place object on table before complete
	if _is_pending_completion and _state == State.ON_TABLE:
		complete_object()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("mouse_click_left"):
		if _state == State.FOCUSED and _is_mouse_on_object and _stickers_hovered == 0:
			_mouse_down = true
			_drag_start_pos = get_viewport().get_mouse_position()
		elif _state == State.FOCUSED and not _is_mouse_on_object:
			get_viewport().set_input_as_handled()

	if event is InputEventMouseMotion:
		# FOCUSED drag: if crossed threshold: start rotating
		if _mouse_down and _state == State.FOCUSED:
			if get_viewport().get_mouse_position().distance_to(_drag_start_pos) > _drag_threshold_px:
				_mouse_down = false
				_set_state(State.ROTATING)
				_apply_rotation_delta(event.relative)
		# ROTATING: apply rotation every frame
		elif _state == State.ROTATING:
			_apply_rotation_delta(event.relative)

	if event.is_action_released("mouse_click_left"):
		if _state == State.DRAGGING:
			_mouse_down = false
			_set_state(State.ON_TABLE)
			get_viewport().set_input_as_handled()
			return
		if _state == State.ROTATING:
			_mouse_down = false
			_set_state(State.FOCUSED)
			_start_snap_tween()
			get_viewport().set_input_as_handled()
			return
		if _state == State.FOCUSED and not _is_mouse_on_object:
			_set_state(State.ON_TABLE)
			_start_focus_tween(Vector3.ZERO, unfocus_curve)
			get_viewport().set_input_as_handled()
			return
		if _state == State.FOCUSED:
			_mouse_down = false # click on focused object without crossing rotation threshold

# Handle interactions for object on the table in unhandled input
# this is done to first give the focused object the chance to consume the input event
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("mouse_click_left"):
		if _state == State.ON_TABLE and _is_mouse_on_object:
			_mouse_down = true
			_drag_start_pos = get_viewport().get_mouse_position()

	if event is InputEventMouseMotion:
		# ON_TABLE drag: if crossed threshold: start moving object
		if _mouse_down and _state == State.ON_TABLE:
			if get_viewport().get_mouse_position().distance_to(_drag_start_pos) > _drag_threshold_px:
				_mouse_down = false
				_set_state(State.DRAGGING)

	if event.is_action_released("mouse_click_left"):
		if _state == State.ON_TABLE and _mouse_down and _is_mouse_on_object:
			_mouse_down = false
			_set_state(State.FOCUSED)
			_start_focus_tween(self.to_local(focus_position.global_position), focus_curve)
			_remove_outline()
			get_viewport().set_input_as_handled()
			return
		_mouse_down = false


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
	for child in Utils.get_all_children(self):
		if child is Sticker:
			_sticker_total += 1
			child.sticker_completed.connect(_on_sticker_completed)
			object_interactible.connect(child._on_object_interactible_change)
			child.sticker_mouse_entered.connect(_on_sticker_mouse_entered)
			child.sticker_mouse_exited.connect(_on_sticker_mouse_exited)
			child.tree_exiting.connect(_on_sticker_tree_exiting.bind(child))
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
	if state == State.FOCUSED or state == State.ROTATING:
		object_interactible.emit(true)
	else:
		object_interactible.emit(false)
	if state == State.ROTATING:
		if _focus_rotation_tween and _focus_rotation_tween.is_valid():
			_focus_rotation_tween.kill()
	if state == State.ON_TABLE:
		_place_object_on_xz_plane(_object)
	
	object_state_changed.emit(state)


func _apply_rotation_delta(delta: Vector2) -> void:
	var camera := get_viewport().get_camera_3d()
	_object.rotate(camera.global_basis.y, delta.x * _rotation_sensitivity)
	_object.rotate(camera.global_basis.x, delta.y * _rotation_sensitivity)


func _start_snap_tween() -> void:
	# orthonormalize first: repeated rotate() calls accumulate float drift
	_object.basis = _object.basis.orthonormalized()
	var start_basis := _object.basis
	var target_basis := _nearest_snap_orientation(start_basis)
	if _snap_tween and _snap_tween.is_valid():
		_snap_tween.kill()
	_snap_tween = create_tween()
	_snap_tween.tween_method(
		func(t: float): _object.basis = Basis(Quaternion(start_basis).slerp(Quaternion(target_basis), t)),
		0.0, 1.0, ROTATION_SNAP_DURATION
	)


func _start_focus_tween(target_local_pos: Vector3, curve: Curve) -> void:
	var sample := func(t: float) -> float: return curve.sample(t) if curve else t
	var start_pos := _object.position
	var start_basis := _object.basis.orthonormalized()

	if _focus_position_tween and _focus_position_tween.is_valid():
		_focus_position_tween.kill()
	if _focus_rotation_tween and _focus_rotation_tween.is_valid():
		_focus_rotation_tween.kill()
	if _snap_tween and _snap_tween.is_valid():
		_snap_tween.kill()

	_focus_position_tween = create_tween()
	_focus_position_tween.tween_method(
		func(t: float): _object.position = start_pos.lerp(target_local_pos, sample.call(t)),
		0.0, 1.0, FOCUS_DURATION
	)
	_focus_position_tween.tween_callback(func(): _place_object_on_xz_plane(_object))

	_focus_rotation_tween = create_tween()
	_focus_rotation_tween.tween_method(
		func(t: float): _object.basis = Basis(Quaternion(start_basis).slerp(Quaternion.IDENTITY, sample.call(t))),
		0.0, 1.0, FOCUS_DURATION
	)


func _nearest_snap_orientation(current: Basis) -> Basis:
	if _snap_orientations.is_empty():
		_snap_orientations = _build_snap_orientations()
	var current_quat := Quaternion(current).normalized()
	var best := _snap_orientations[0]
	var best_dot := -1.0
	for candidate in _snap_orientations:
		var d: float = abs(current_quat.dot(Quaternion(candidate).normalized()))
		if d > best_dot:
			best_dot = d
			best = candidate
	return best


static func _build_snap_orientations() -> Array[Basis]:
	var cardinals: Array[Vector3] = [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.FORWARD, Vector3.BACK]
	var results: Array[Basis] = []
	for y_axis in cardinals:
		for z_axis in cardinals:
			if abs(y_axis.dot(z_axis)) > 0.001:
				continue
			var x_axis := y_axis.cross(z_axis).normalized()
			results.append(Basis(x_axis, y_axis, z_axis))
	return results


func _on_sticker_mouse_entered(sticker: Sticker) -> void:
	if _hovered_stickers.has(sticker):
		return
	_hovered_stickers.append(sticker)
	_stickers_hovered += 1


func _on_sticker_mouse_exited(sticker: Sticker) -> void:
	if not _hovered_stickers.has(sticker):
		return
	_hovered_stickers.erase(sticker)
	_stickers_hovered = max(0, _stickers_hovered - 1)


func _on_sticker_tree_exiting(sticker: Sticker) -> void:
	_on_sticker_mouse_exited(sticker)


func _handle_drag():
	if _state != State.DRAGGING:
		return
	# Get intersect between raycast from viewport + mouse and XZ plane
	# Assumption: scene is setup so workbench plane is at y = 0

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
	queue_free()
	emit_signal("object_completed", object_scene.resource_path.get_file().get_basename(), _object.is_special_object, _completed_stickers, _sticker_total)

# Ensures the objects sits on top of the XZ plane, with no geometry sticking out below it
func _place_object_on_xz_plane(object: Node3D):
	var bbox: AABB = Utils._calculate_bounding_box(object, false)
	# TODO: get the world space transform matrix of the object and multiply it with the object BBOX
	# bug is most likely caused by object bbox being in local coords
	global_position.y = bbox.size.y / 2
