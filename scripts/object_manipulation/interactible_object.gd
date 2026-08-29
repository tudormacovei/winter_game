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

# Fires after:
# - initial sticker placement finishes
# - stickers get peeled of the object (sticker completion)
signal has_stickers_remaining_changed(has_remaining: bool)

# Setup variables, set before node enters scene tree
var _focus_position: Node3D
var _on_table_neutral_position: Node3D
var _object_completed_area: Area3D
var _out_of_bounds_area: Area3D
var _object_scene: PackedScene # ObjectWithStickers scene to load
const RETURN_TWEEN_DURATION: float = 0.2
@export var outline_material: Material
@export var focus_position_curve: Curve
@export var focus_rotation_curve: Curve

enum State {
	ON_TABLE,
	FOCUSED,
	ROTATING,
	DRAGGING,
	RETURNING,
}

# What the soft select system is currently targeting (it does not mean an interaction was triggered)
# Refreshes every physics tick, only while the object is focused
enum SoftSelectTarget {
	NONE,
	OBJECT,
	STICKER,
}

# What the player is currently grabbing, only used in focused mode
enum CurrentlyGrabbed {
	NONE, # the grab action is not held
	STICKER, # a sticker accepted the grab and receives all mouse events until release
	OBJECT, # the grab landed on the object. Rotation starts after the drag threshold
	MISS, # the grab missed the object. A release that also misses defocuses
}

var _object: ObjectWithStickers = null
var _state := State.ON_TABLE
var _is_mouse_on_object := false
var _sticker_total: int = 0 # set at initialization time, then readonly constant
var _completed_stickers: int = 0
var _is_pending_completion := false
var _original_mesh: Mesh = null

static var HOVERED_SCALE = Vector3(1.02, 1.02, 1.02) # object scale on mouse hover
static var DRAG_THRESHOLD_FRACTION: float = 0.008 # fraction of viewport width before a grab becomes a drag (prevents jitter)
static var ROTATION_REVOLUTIONS_PER_WIDTH: float = 1.25 # full revolutions when dragging across the viewport width
static var ROTATION_SNAP_DURATION: float = 0.2
static var FOCUS_DURATION: float = 0.25
static var FOCUS_OBJECT_SCALE: float = 0.3
const SOFT_SELECT_RADII: Array[float] = [0.0, 0.005, 0.01, 0.02, 0.03, 0.04] # screen-width fractions
const SOFT_SELECT_RAY_COUNTS: Array[int] = [1, 9, 12, 15, 18, 21]
const STICKER_RING_COUNT: int = 4 # the first X rings select a sticker, the outer rings detect the object only (player has to be more precise when selecting a sticker than the object)

#region Game State 

var _has_player_dragged_object: bool = false
var _has_player_rotated_object: bool = false
var _has_player_cleansed_sticker: bool = false

#endregion

#region Workspace Object Bounds

const OUT_OF_BOUNDS_MARGIN: float = 0.2
const _RETURN_IN_BOUNDS_ITERATION_CAP: int = 12

#endregion

var _drag_threshold_px: float = 0.0
var _drag_start_pos: Vector2 = Vector2.ZERO
var _mouse_down: bool = false # for table mode only! Focused mode uses _currently_grabbed.

var _rotation_sensitivity: float = 0.0 # radians per pixel, set in _ready
var _soft_select_target := SoftSelectTarget.NONE # result of the last soft select
var _selected_sticker: Sticker = null # the sticker a grab would land on, refreshed every physics tick. While a sticker is grabbed this is frozen and is the grabbed sticker!
var _currently_grabbed := CurrentlyGrabbed.NONE # what type of object is currently grabbed? Dictates how we process input
var _soft_select_debug_markers: SoftSelectRayDebugMarkers = null
var _snap_tween: Tween
var _focus_position_tween: Tween
var _focus_rotation_tween: Tween
var _focus_scale_tween: Tween
static var _snap_orientations: Array[Basis] = []

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	assert(_focus_position != null and _object_completed_area != null and _object_scene != null, "set_spawn_data() must be called before InteractibleObject enters the scene tree")
	if _object_scene == null:
		Utils.debug_error("InteractibleObject: Attempted to instantiate null object scene. Check that the day resource does not contain empty objects!")
		queue_free() # delete self due to lack of child object
		return

	_object = _object_scene.instantiate()
	if not (_object is ObjectWithStickers):
		# TODO: replace prints with warning logs
		Utils.debug_error("InteractibleObject: Object scene is not of type ObjectWithStickers. Type: " + str(_object.get_class()))
		queue_free()
		return
	add_child(_object)
	_object.owner = get_tree().current_scene
	_place_object_on_xz_plane(_object)
	
	_object.mouse_entered.connect(_on_object_mouse_entered)
	_object.mouse_exited.connect(_on_object_mouse_exited)
	_object.area_entered.connect(_on_object_area_entered)
	_object.area_exited.connect(_on_object_area_exited)

	# Stickers are placed asynchronously — wait for the signal before scanning
	_object.stickers_placed.connect(_on_stickers_placed)

	_drag_threshold_px = get_viewport().get_visible_rect().size.x * DRAG_THRESHOLD_FRACTION
	_rotation_sensitivity = TAU * ROTATION_REVOLUTIONS_PER_WIDTH / get_viewport().get_visible_rect().size.x

	_soft_select_debug_markers = SoftSelectRayDebugMarkers.new()
	add_child(_soft_select_debug_markers)


func _process(_delta: float) -> void:
	_handle_drag()
	# wait for player to place object on table before complete
	if _is_pending_completion and _state == State.ON_TABLE:
		complete_object()


func _physics_process(_delta: float) -> void:
	if GameState.is_player_input_locked:
		_cancel_mouse_input()
		_clear_soft_select()
		_currently_grabbed = CurrentlyGrabbed.NONE
		return
	if _state != State.FOCUSED and _state != State.ROTATING:
		_clear_soft_select()
		return
	if _currently_grabbed == CurrentlyGrabbed.STICKER:
		return # the grabbed sticker stays selected until the grab ends
	_soft_select_target = _soft_select()


#region Soft Select

## Casts rays in rings around the cursor, so an imprecise click still works.
## A sticker hit always wins over an object hit
func _soft_select() -> SoftSelectTarget:
	_soft_select_debug_markers.clear_markers()
	var camera := get_viewport().get_camera_3d()
	if camera == null or camera.far <= 0.0:
		_set_selected_sticker(null)
		return SoftSelectTarget.NONE

	var viewport_size := get_viewport().get_visible_rect().size # refetch per tick in case of window resize
	var mouse_position := get_viewport().get_mouse_position()
	var is_object_hit := false
	for ring_index in SOFT_SELECT_RADII.size():
		var is_sticker_ring := ring_index < STICKER_RING_COUNT
		if not is_sticker_ring and is_object_hit:
			break # the sticker rings already hit the object, so the outer rings are skipped
		var radius := SOFT_SELECT_RADII[ring_index] * viewport_size.x
		var ray_count := SOFT_SELECT_RAY_COUNTS[ring_index]
		for ray_index in ray_count:
			var screen_position := mouse_position
			if radius > 0.0:
				var angle := TAU * float(ray_index) / float(ray_count)
				screen_position += Vector2(cos(angle), sin(angle)) * radius
			if screen_position.x < 0.0 or screen_position.y < 0.0 or screen_position.x >= viewport_size.x or screen_position.y >= viewport_size.y:
				continue # out of viewport bounds
			
			var hit := _soft_select_raycast(screen_position, camera)
			var hit_sticker: Sticker = hit.node as Sticker if hit != null else null
			if hit_sticker != null and (not is_sticker_ring or not _is_sticker_facing_camera(hit_sticker, camera)):
				hit_sticker = null # any sticker in an object-only ring counts as an object hit
			_show_soft_select_ray_debug_marker(camera, screen_position, hit, hit_sticker)

			if hit == null:
				continue
			if hit_sticker != null:
				_set_selected_sticker(hit_sticker)
				return SoftSelectTarget.STICKER
			is_object_hit = true

	_set_selected_sticker(null)
	return SoftSelectTarget.OBJECT if is_object_hit else SoftSelectTarget.NONE


## Casts one ray. Returns a hit on the object or on one of its interactible stickers, null otherwise.
func _soft_select_raycast(screen_position: Vector2, camera: Camera3D) -> SoftSelectRayHit:
	if _object == null:
		return null

	var origin := camera.project_ray_origin(screen_position)
	var direction := camera.project_ray_normal(screen_position)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * camera.far)
	query.collide_with_areas = true
	query.collide_with_bodies = false

	# TODO: if we run into performance issues we could restrict this raycast to only work on the focused object
	var physics_hit := get_world_3d().direct_space_state.intersect_ray(query)
	if physics_hit.is_empty():
		return null

	var collider := physics_hit["collider"] as Node
	var is_object := collider == _object
	var is_sticker := collider is Sticker and _object.is_ancestor_of(collider) and (collider as Sticker).is_interactible()
	if not is_object and not is_sticker:
		return null
	return SoftSelectRayHit.new(collider, physics_hit["position"])


## A sticker on the side of the object is not a valid target.
func _is_sticker_facing_camera(sticker: Sticker, camera: Camera3D) -> bool:
	var sticker_normal := sticker.global_basis.y.normalized() # stickers are placed with their local Y along the surface normal
	var direction_toward_camera := camera.global_basis.z # opposite of the camera forward axis
	return sticker_normal.dot(direction_toward_camera) >= cos(deg_to_rad(30.0)) # exclude stickers that do not face the camera


## A hit is marked at its hit position, a miss is marked along the ray at the depth of this object's origin
func _show_soft_select_ray_debug_marker(camera: Camera3D, screen_position: Vector2, hit: SoftSelectRayHit, hit_sticker: Sticker) -> void:
	if hit == null:
		var object_depth := (global_position - camera.global_position).dot(-camera.global_basis.z)
		var miss_position := camera.project_position(screen_position, object_depth)
		_soft_select_debug_markers.add_marker(camera, screen_position, miss_position, SoftSelectRayDebugMarkers.Result.MISS)
		return
	var result: SoftSelectRayDebugMarkers.Result = SoftSelectRayDebugMarkers.Result.STICKER if hit_sticker != null else SoftSelectRayDebugMarkers.Result.OBJECT
	_soft_select_debug_markers.add_marker(camera, screen_position, hit.position, result)


func _clear_soft_select() -> void:
	_set_selected_sticker(null)
	_soft_select_target = SoftSelectTarget.NONE
	_soft_select_debug_markers.clear_markers()


func _set_selected_sticker(sticker: Sticker) -> void:
	if sticker != null and not is_instance_valid(sticker):
		sticker = null
	if _selected_sticker == sticker: # previous sticker equals new sticker, early return
		return

	var previous_sticker := _selected_sticker
	_selected_sticker = sticker
	if is_instance_valid(previous_sticker):
		previous_sticker.set_deselected()
	if is_instance_valid(_selected_sticker):
		_selected_sticker.set_selected()

#endregion


#region Grab
# When a player clicks while in focus mode, we say that they are attempting to grab
# The player can grab the object in order to rotate it, the sticker in order to peel it, or they can grab the space around the object to exit focus mode

## Returns true when the sticker can be interacted with
func _try_grab_selected_sticker(event: InputEvent) -> bool:
	if not is_instance_valid(_selected_sticker):
		return false
	return _selected_sticker.handle_mouse_input(event)


## Sends motion and release events to the grabbed sticker.
func _forward_mouse_input_to_grabbed_sticker(event: InputEvent) -> void:
	if is_instance_valid(_selected_sticker):
		_selected_sticker.handle_mouse_input(event)


## Rotation starts after the cursor moves past the drag threshold and continues until release.
func _handle_object_grab_motion(event: InputEventMouseMotion) -> void:
	if _state == State.ROTATING:
		_apply_rotation_delta(event.relative)
		return
	if _state == State.FOCUSED and get_viewport().get_mouse_position().distance_to(_drag_start_pos) > _drag_threshold_px:
		_set_state(State.ROTATING)
		_apply_rotation_delta(event.relative)


#endregion


## Ends a sticker grab without a release: the sticker rolls back its peel.
func _cancel_mouse_input() -> void:
	if _currently_grabbed != CurrentlyGrabbed.STICKER:
		return
	_currently_grabbed = CurrentlyGrabbed.NONE
	if is_instance_valid(_selected_sticker):
		_selected_sticker.cancel_mouse_input()


func _return_object_in_bounds() -> void:
	if _is_pending_completion:
		_is_pending_completion = false
		object_pending_completion_changed.emit(false)

	# Each iteration shoves the candidate out of whichever offending box requires the smallest displacement.
	# One iteration is enough in the common case, the loop only matters when out of bounds boxes overlap (bound corners)
	var candidate := self.global_position
	var converged := false
	for _i in _RETURN_IN_BOUNDS_ITERATION_CAP:
		var push := _smallest_push_to_safe(candidate)
		if push == Vector3.ZERO:
			converged = true
			break
		candidate += push

	if not converged:
		# Geometric search could not find a safe point, fall back to the neutral position
		push_warning("InteractibleObject: bounds recovery did not converge; returning to neutral position")
		candidate = _on_table_neutral_position.global_position

	_return_to(candidate)


# Among all out-of-bounds boxes the point violates, returns the smalles world-space displacement vector
# that exits one box by `OUT_OF_BOUNDS_MARGIN`.
# Returns `Vector3.ZERO` when the point is already safe.
func _smallest_push_to_safe(point: Vector3) -> Vector3:
	const EPSILON: float = 0.0001
	var best_push := Vector3.ZERO
	var best_magnitude_sq := INF
	for child in _out_of_bounds_area.get_children():
		if not (child is CollisionShape3D and (child as CollisionShape3D).shape is BoxShape3D):
			continue
		var collision_shape := child as CollisionShape3D
		var box := collision_shape.shape as BoxShape3D
		var local: Vector3 = collision_shape.global_transform.affine_inverse() * point
		var half: Vector3 = box.size * 0.5
		var dx: float = max(abs(local.x) - half.x, 0.0)
		var dy: float = max(abs(local.y) - half.y, 0.0)
		var dz: float = max(abs(local.z) - half.z, 0.0)
		var surface_distance := sqrt(dx * dx + dy * dy + dz * dz)
		if surface_distance >= OUT_OF_BOUNDS_MARGIN:
			continue

		var local_push: Vector3
		if surface_distance > 0.0:
			# Outside the box but have not cleared the margin
			var dir := Vector3(dx * signf(local.x), dy * signf(local.y), dz * signf(local.z)) / surface_distance
			local_push = dir * (OUT_OF_BOUNDS_MARGIN - surface_distance + EPSILON)
		else:
			# Inside the box: exit through the nearest face + add the margin
			var depth_x: float = half.x - abs(local.x)
			var depth_y: float = half.y - abs(local.y)
			var depth_z: float = half.z - abs(local.z)
			var axis: int = 0
			var min_depth := depth_x
			if depth_y < min_depth:
				axis = 1
				min_depth = depth_y
			if depth_z < min_depth:
				axis = 2
				min_depth = depth_z

			# point exactly on the box's center axis: pick an arbitrary side
			var coord_sign := signf(local[axis])
			if coord_sign == 0.0:
				coord_sign = 1.0
			local_push = Vector3.ZERO
			local_push[axis] = coord_sign * (min_depth + OUT_OF_BOUNDS_MARGIN + EPSILON)

		var world_push: Vector3 = collision_shape.global_transform.basis * local_push
		var magnitude_sq := world_push.length_squared()
		if magnitude_sq < best_magnitude_sq:
			best_magnitude_sq = magnitude_sq
			best_push = world_push

	return best_push


# Returns `true` if `point` is inside the out-of-bounds area, OR within `margin` of one's surface.
func _is_point_out_of_bounds(point: Vector3, margin: float) -> bool:
	for child in _out_of_bounds_area.get_children():
		if child is CollisionShape3D and child.shape is BoxShape3D:
			var local: Vector3 = child.global_transform.affine_inverse() * point
			var half: Vector3 = (child.shape as BoxShape3D).size * 0.5
			var dx: float = max(abs(local.x) - half.x, 0.0)
			var dy: float = max(abs(local.y) - half.y, 0.0)
			var dz: float = max(abs(local.z) - half.z, 0.0)
			if sqrt(dx * dx + dy * dy + dz * dz) < margin: # spherical margin check
				return true
	return false


# Handles focused mode interaction (and the DRAGGING release) in _input so that the focused object gets the event first
func _input(event: InputEvent) -> void:
	if GameState.is_player_input_locked:
		return

	# Grab starts: what did the player grab? 
	# The soft select target may change later, the grab does not change while LMB is still pressed!
	if event.is_action_pressed("mouse_click_left") and _state == State.FOCUSED:
		match _soft_select_target:
			SoftSelectTarget.STICKER:
				if _try_grab_selected_sticker(event):
					_currently_grabbed = CurrentlyGrabbed.STICKER
				else:
					_currently_grabbed = CurrentlyGrabbed.OBJECT # the sticker said no, the object behind it says yes
			SoftSelectTarget.OBJECT:
				_currently_grabbed = CurrentlyGrabbed.OBJECT
			SoftSelectTarget.NONE:
				_currently_grabbed = CurrentlyGrabbed.MISS
		_drag_start_pos = get_viewport().get_mouse_position()
		get_viewport().set_input_as_handled()
		return

	# Grab is held: stickers get the raw events, the object gets rotated
	if event is InputEventMouseMotion:
		match _currently_grabbed:
			CurrentlyGrabbed.STICKER:
				_forward_mouse_input_to_grabbed_sticker(event)
			CurrentlyGrabbed.OBJECT:
				_handle_object_grab_motion(event)
		return

	if event.is_action_released("mouse_click_left"):
		if _state == State.DRAGGING:
			_mouse_down = false
			# evaluate bounds on drag release, not every frame
			if _out_of_bounds_area and _is_point_out_of_bounds(self.global_position, OUT_OF_BOUNDS_MARGIN):
				_return_object_in_bounds()
			else:
				_set_state(State.ON_TABLE)
			get_viewport().set_input_as_handled()
			return

		# Grab ends: ensure what was grabbed is notified of the grab end
		if _currently_grabbed != CurrentlyGrabbed.NONE:
			match _currently_grabbed:
				CurrentlyGrabbed.STICKER:
					_forward_mouse_input_to_grabbed_sticker(event) # the sticker decides if the peel succeeded
				CurrentlyGrabbed.OBJECT: # handle grab end for rotation directly
					if _state == State.ROTATING:
						_set_state(State.FOCUSED)
						_start_snap_tween()
					# else: a click on the object that never crossed the drag threshold did nothing, so don't change state
				CurrentlyGrabbed.MISS:
					if _soft_select_target == SoftSelectTarget.NONE:
						defocus()
					# a miss that ends on the object is not an intended miss (probably), so stay focused
			_currently_grabbed = CurrentlyGrabbed.NONE
			get_viewport().set_input_as_handled()


# Handle interactions for object on the table in unhandled input
# this is done to first give the focused object the chance to consume the input event
func _unhandled_input(event: InputEvent) -> void:
	if GameState.is_player_input_locked:
		return

	if event.is_action_pressed("mouse_click_left"):
		if _state == State.ON_TABLE and _is_mouse_on_object:
			var camera := get_viewport().get_camera_3d() as CameraControl
			if camera == null or not camera.is_at_rest_at_table():
				return
			_mouse_down = true
			_drag_start_pos = get_viewport().get_mouse_position()

	if event is InputEventMouseMotion:
		# ON_TABLE drag: if crossed threshold: start moving object
		if _mouse_down and _state == State.ON_TABLE:
			if get_viewport().get_mouse_position().distance_to(_drag_start_pos) > _drag_threshold_px:
				_mouse_down = false
				_set_state(State.DRAGGING)

	if event.is_action_released("mouse_click_left"):
		var camera := get_viewport().get_camera_3d() as CameraControl
		if _state == State.ON_TABLE and _mouse_down and _is_mouse_on_object:
			# object focus can only happen while in workbench view, NOT quarantine view
			if camera and camera.is_at_rest_in_workbench_view():
				if GameState.is_action_locked[GameState.ActionName.FOCUS_OBJECT]:
					_mouse_down = false
					get_viewport().set_input_as_handled()
					return

				_mouse_down = false
				focus()
				get_viewport().set_input_as_handled()
				return
		_mouse_down = false


func _on_object_mouse_entered() -> void:
	_is_mouse_on_object = true
	_update_can_enter_dialogue_view()
	if _state == State.ON_TABLE:
		_apply_outline()
		CursorManager.request_cursor(CursorManager.CursorType.HOVER)


func _on_object_mouse_exited() -> void:
	_is_mouse_on_object = false
	_update_can_enter_dialogue_view()
	if _state == State.ON_TABLE:
		_remove_outline()
		CursorManager.release_cursor(CursorManager.CursorType.HOVER)


func _on_object_area_entered(area: Area3D) -> void:
	# wait for player to place the object on the table before completing it
	if area == _object_completed_area:
		_is_pending_completion = true
		object_pending_completion_changed.emit(true)


func _on_object_area_exited(area: Area3D) -> void:
	if area == _object_completed_area and not is_queued_for_deletion():
		_is_pending_completion = false
		object_pending_completion_changed.emit(false)


func _on_stickers_placed() -> void:
	for child in Utils.get_all_children(self):
		if child is Sticker:
			_sticker_total += 1
			child.sticker_completed.connect(_on_sticker_completed)
			object_interactible.connect(child._on_object_interactible_change)
			child.tree_exiting.connect(_on_sticker_tree_exiting.bind(child))
	has_stickers_remaining_changed.emit(_sticker_total > 0)
	_set_state(State.ON_TABLE)


## Returns true if the object still has stickers left to peel.
## Works correctly for both special objects & objects with automated sticker placement. [br]
## Note: If called BEFORE sticker placement finishes, returns FALSE
func has_stickers_remaining() -> bool:
	return _completed_stickers < _sticker_total


func _on_sticker_completed():
	if not _has_player_cleansed_sticker:
		_has_player_cleansed_sticker = true
		GameState.first_sticker_cleansed_on_object.emit()

	_completed_stickers += 1
	print("Completed " + str(_completed_stickers) + " stickers!")
	if _completed_stickers >= _sticker_total:
		has_stickers_remaining_changed.emit(false)


# Set all data needed for correct functionality
func set_spawn_data(focus_position: Node3D, on_table_neutral_position: Node3D, object_completed_area: Area3D, out_of_bounds_area: Area3D, object_scene: PackedScene):
	_focus_position = focus_position
	_on_table_neutral_position = on_table_neutral_position
	_object_completed_area = object_completed_area
	_out_of_bounds_area = out_of_bounds_area
	_object_scene = object_scene


func _set_state(state: State):
	if _state != state:
		CursorManager.clear_requests() # self-heal cursor state by resetting on object state change
	if state != State.FOCUSED and state != State.ROTATING:
		_cancel_mouse_input()
		_clear_soft_select()
		_currently_grabbed = CurrentlyGrabbed.NONE
	_state = state
	#print("Set state to " + str(state))
	if state == State.FOCUSED or state == State.ROTATING:
		_set_object_interactible(true)
	else:
		_set_object_interactible(false)
	if state == State.ROTATING:
		if not _has_player_rotated_object:
			_has_player_rotated_object = true
			GameState.first_rotate_on_object.emit()
		if _focus_rotation_tween and _focus_rotation_tween.is_valid():
			_focus_rotation_tween.kill()
	if state == State.DRAGGING:
		if not _has_player_dragged_object:
			_has_player_dragged_object = true
			GameState.first_drag_on_object.emit()
	if state == State.ON_TABLE:
		_place_object_on_xz_plane(_object)

	var camera := get_viewport().get_camera_3d() as CameraControl
	if camera:
		camera.can_enter_quarantine_view = state != State.FOCUSED and state != State.ROTATING
	_update_can_enter_dialogue_view()

	object_state_changed.emit(state)


func focus() -> void:
	if _state != State.ON_TABLE:
		return
	_set_state(State.FOCUSED)
	_remove_outline()
	_start_focus_tween(self.to_local(_focus_position.global_position), focus_position_curve, focus_rotation_curve, Vector3.ONE * FOCUS_OBJECT_SCALE, true)


func defocus() -> void:
	if _state != State.FOCUSED and _state != State.ROTATING:
		return
	_set_state(State.ON_TABLE)
	_start_focus_tween(Vector3.ZERO, focus_position_curve, focus_rotation_curve, Vector3.ONE, false)


## Dialogue transition is allowed only when the player is not interacting with an object
func _update_can_enter_dialogue_view() -> void:
	var camera := get_viewport().get_camera_3d() as CameraControl
	if camera == null:
		return
	camera.can_enter_dialogue_view = _state == State.ON_TABLE and not _is_mouse_on_object


func _set_object_interactible(is_interactible: bool) -> void:
	# NOTE: COMPLETE_STICKER locked action works as intended because the object starts as not interactible and is only set to interactable in focus mode
	if GameState.is_action_locked[GameState.ActionName.COMPLETE_STICKER]:
		is_interactible = false

	if is_interactible and (_state != State.FOCUSED and _state != State.ROTATING):
		return # Object can only be interactible in certain states

	object_interactible.emit(is_interactible)


func _apply_rotation_delta(delta: Vector2) -> void:
	var camera := get_viewport().get_camera_3d()
	_object.rotate(camera.global_basis.y, delta.x * _rotation_sensitivity)
	_object.rotate(camera.global_basis.x, delta.y * _rotation_sensitivity)


func _start_snap_tween() -> void:
	# orthonormalize first: repeated rotate() calls accumulate float drift
	# preserve scale — orthonormalized() strips it by normalizing axis vectors to unit length
	var current_scale := _object.scale
	_object.basis = _object.basis.orthonormalized()
	_object.scale = current_scale
	var start_basis := _object.basis.orthonormalized()
	var target_basis := _nearest_snap_orientation(start_basis)
	if _snap_tween and _snap_tween.is_valid():
		_snap_tween.kill()
	_snap_tween = create_tween()
	var snap_fn := func(t: float) -> void:
		_object.basis = Basis(Quaternion(start_basis).slerp(Quaternion(target_basis), t))
		_object.scale = current_scale
	_snap_tween.tween_method(snap_fn, 0.0, 1.0, ROTATION_SNAP_DURATION)


func _start_focus_tween(target_local_pos: Vector3, position_curve: Curve, rotation_curve: Curve, target_scale: Vector3, is_focusing: bool) -> void:
	var position_sample := func(t: float) -> float: return position_curve.sample(t) if position_curve else t
	var rotation_sample := func(t: float) -> float: return rotation_curve.sample(t) if rotation_curve else t
	var start_pos := _object.position
	var start_basis := _object.basis.orthonormalized()
	var start_scale := _object.scale

	if _focus_position_tween and _focus_position_tween.is_valid():
		_focus_position_tween.kill()
	if _focus_rotation_tween and _focus_rotation_tween.is_valid():
		_focus_rotation_tween.kill()
	if _focus_scale_tween and _focus_scale_tween.is_valid():
		_focus_scale_tween.kill()
	if _snap_tween and _snap_tween.is_valid():
		_snap_tween.kill()

	var camera := get_viewport().get_camera_3d() as CameraControl
	if camera:
		if is_focusing:
			camera.begin_object_focus(_object.additional_focus_zoom_percent, FOCUS_DURATION)
		else:
			camera.end_object_focus(FOCUS_DURATION)

	_focus_position_tween = create_tween()
	_focus_position_tween.tween_method(
		func(t: float): _object.position = start_pos.lerp(target_local_pos, position_sample.call(t)),
		0.0, 1.0, FOCUS_DURATION
	)
	_focus_position_tween.tween_callback(func(): _place_object_on_xz_plane(_object))

	_focus_rotation_tween = create_tween()
	_focus_rotation_tween.tween_method(
		func(t: float): _object.basis = Basis(Quaternion(start_basis).slerp(Quaternion.IDENTITY, rotation_sample.call(t))),
		0.0, 1.0, FOCUS_DURATION
	)

	_focus_scale_tween = create_tween()
	_focus_scale_tween.tween_method(
		func(t: float): _object.scale = start_scale.lerp(target_scale, position_sample.call(t)),
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


func _on_sticker_tree_exiting(sticker: Sticker) -> void:
	if _selected_sticker == sticker:
		_cancel_mouse_input() # no effect unless this sticker is grabbed
		_selected_sticker = null


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
	if GameState.is_action_locked[GameState.ActionName.COMPLETE_OBJECT]:
		_return_to(_on_table_neutral_position.global_position)
		return

	print("Object Completed! Stickers completed: " + str(_completed_stickers) + "/" + str(_sticker_total))
	AudioManager.play_sfx(Config.OBJECT_COMPLETED_SFX_NAME, Config.OBJECT_COMPLETED_SFX_VOLUME_DB)
	GameState.object_completed.emit()

	_is_mouse_on_object = false # Prevents timing issues where the mouse is registered as hovering while the object is being freed
	_set_state(State.ON_TABLE)
	queue_free()
	object_completed.emit(_object_scene.resource_path.get_file().get_basename(), _object.is_special_object, _completed_stickers, _sticker_total)


# Snap-back to a target world position. Locks player input on this object during the return animation via the RETURNING state
func _return_to(target_global_position: Vector3) -> void:
	_set_state(State.RETURNING)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "global_position", target_global_position, RETURN_TWEEN_DURATION)
	tween.finished.connect(_on_return_finished)


func _on_return_finished() -> void:
	_set_state(State.ON_TABLE)

# Ensures the objects sits on top of the XZ plane, with no geometry sticking out below it
func _place_object_on_xz_plane(object: Node3D):
	var bbox: AABB = Utils._calculate_bounding_box(object, false)
	# TODO: get the world space transform matrix of the object and multiply it with the object BBOX
	# bug is most likely caused by object bbox being in local coords
	global_position.y = bbox.size.y / 2


## Result of one soft select ray that hit the object or one of its stickers.
class SoftSelectRayHit:
	var node: Node # _object or one of its stickers
	var position: Vector3 # world space hit position

	func _init(hit_node: Node, hit_position: Vector3) -> void:
		node = hit_node
		position = hit_position
