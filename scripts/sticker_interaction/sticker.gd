# Sticker object base class
#
# Not interactible by default, _on_object_interactible_change must
# be connected to signal from parent object.
@tool
class_name Sticker extends Area3D

enum State { ACTIVE, FAILED }

@export var debug_enabled := false

@export var spots: Array[ShaderMaterial] = [] : set = _set_spots

# When randomize_spot is true, a spot is picked at random on spawn
# When false, locked_spot_index selects the spot
# 	- useful for extra control on special objects that do not have randomized sticker placement
# The editor always shows the locked spot.
@export var randomize_spot: bool = true : set = _set_randomize_spot
@export var locked_spot_index: int = 0 : set = _set_locked_spot_index
@export var health_gain_percent: float = 10.0

@onready var mesh_instance: MeshInstance3D = find_children("*", "MeshInstance3D")[0]

var state: State = State.ACTIVE
var _is_selected := false
var _is_object_interactible := false

signal sticker_completed()
signal sticker_selected(sticker: Sticker)
signal sticker_deselected(sticker: Sticker)

func _ready() -> void:
	_apply_spot()


func _apply_spot() -> void:
	if spots.is_empty():
		push_warning("Sticker %s has no spots" % get_path())
		return
	var spot_index: int
	if randomize_spot and not Engine.is_editor_hint():
		spot_index = randi() % spots.size()
	else:
		spot_index = clampi(locked_spot_index, 0, spots.size() - 1)
	mesh_instance.set_surface_override_material(0, spots[spot_index])


func set_shader_value(value_name: StringName, value: Variant) -> void:
	mesh_instance.set_instance_shader_parameter(value_name, value)


func _set_spots(value: Array[ShaderMaterial]) -> void:
	spots = value
	if is_inside_tree():
		_apply_spot()

func _set_randomize_spot(value: bool) -> void:
	randomize_spot = value
	if is_inside_tree():
		_apply_spot()

func _set_locked_spot_index(value: int) -> void:
	locked_spot_index = value
	if is_inside_tree():
		_apply_spot()

func _complete_sticker():
	#print("Completed sticker!")
	sticker_completed.emit()
	queue_free()

func _on_object_interactible_change(is_interactible: bool):
	_is_object_interactible = is_interactible
	$CollisionShape3D.disabled = !is_interactible or state != State.ACTIVE
	if not is_interactible:
		set_deselected()
	CursorManager.refresh()
	CursorManager.clear_requests()

func is_interactible() -> bool:
	return state == State.ACTIVE and _is_object_interactible

func set_selected() -> void:
	if _is_selected:
		return
	_is_selected = true
	sticker_selected.emit(self)
	if _is_object_interactible:
		CursorManager.request_cursor(CursorManager.CursorType.HOVER)

func set_deselected() -> void:
	if not _is_selected:
		return
	_is_selected = false
	sticker_deselected.emit(self)
	CursorManager.release_cursor(CursorManager.CursorType.HOVER)

func handle_mouse_input(_event: InputEvent) -> bool:
	return false

func cancel_mouse_input() -> void:
	pass

# true if sticker can be interacted with, false otherwise
func _get_interactible() -> bool:
	if state != State.ACTIVE:
		return false
	if _is_selected and debug_enabled:
		return true

	return _is_selected and is_interactible()
