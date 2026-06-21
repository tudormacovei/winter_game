# Sticker object base class
#
# Not interactible by default, _on_object_interactible_change must
# be connected to signal from parent object.
@tool
class_name Sticker extends Area3D

enum State { ACTIVE, FAILED }

@export var debug_enabled := false

# Textures that cane beused by this sticker, set in inspector.
@export var spot_textures: Array[Texture2D] = [] : set = _set_spot_textures

# When randomize_texture is true, a texture is picked at random from spot_textures on spawn.
# When false, locked_texture_index selects the texture
# 	- useful for extra control on special objects that do not have randomized sticker placement
@export var randomize_texture: bool = true : set = _set_randomize_texture
@export var locked_texture_index: int = 0 : set = _set_locked_texture_index

var state: State = State.ACTIVE
var _is_mouse_on_object := false
var _is_object_interactible := false
# Track if Surface 0's material has already been duplicated for this instance,
# so we don't unnecessarily double-duplicate. (for example, directional stickers already duplicate the material instance to set per-object material parameters)
var _surface_material_duplicated: bool = false

signal sticker_completed()
signal sticker_mouse_entered(sticker: Sticker)
signal sticker_mouse_exited(sticker: Sticker)

func _ready() -> void:
	_pick_and_apply_texture()


# Pick the active texture and bind it to the per-instance material.
func _pick_and_apply_texture() -> void:
	if spot_textures.is_empty():
		return # keep the scene's default material — no override
	var chosen: Texture2D
	if randomize_texture and not Engine.is_editor_hint():
		chosen = spot_textures[randi() % spot_textures.size()]
	else:
		# Editor always uses the locked index as the preview; runtime uses it when randomize is off.
		var idx: int = clampi(locked_texture_index, 0, spot_textures.size() - 1)
		chosen = spot_textures[idx]
	_apply_texture(chosen)


# Writes the texture to the per-instance Surface 0 material. Branches on material type.
func _apply_texture(texture: Texture2D) -> void:
	var mat := _get_or_duplicate_surface_material()
	if mat == null:
		return
	if mat is StandardMaterial3D:
		var smat := mat as StandardMaterial3D
		smat.albedo_texture = texture
		smat.emission_texture = texture
	elif mat is ShaderMaterial:
		var shmat := mat as ShaderMaterial
		# Godot allows set_shader_parameter to run without effect for undeclared uniforms, so these writes should not error
		shmat.set_shader_parameter(&"albedo_texture", texture)
		shmat.set_shader_parameter(&"emission_texture", texture)


# Returns Surface 0's material, duplicating it on first call so it becomes a per-instance material.
# Subsequent calls return the already-duplicated material
func _get_or_duplicate_surface_material() -> Material:
	var mesh_instance : MeshInstance3D = find_children("*", "MeshInstance3D")[0]
	if mesh_instance == null:
		return null
	var current := mesh_instance.get_surface_override_material(0)
	if current == null:
		return null
	if not _surface_material_duplicated:
		current = current.duplicate()
		mesh_instance.set_surface_override_material(0, current)
		_surface_material_duplicated = true
	return current


func _set_spot_textures(v: Array[Texture2D]) -> void:
	spot_textures = v
	if is_inside_tree():
		_pick_and_apply_texture()

func _set_randomize_texture(v: bool) -> void:
	randomize_texture = v
	if is_inside_tree():
		_pick_and_apply_texture()

func _set_locked_texture_index(v: int) -> void:
	locked_texture_index = v
	if is_inside_tree():
		_pick_and_apply_texture()

func _complete_sticker():
	#print("Completed sticker!")
	sticker_completed.emit()
	queue_free()

func _input(_event: InputEvent) -> void:
	# Child classes implement specific interactions
	pass

func _on_object_interactible_change(is_interactible: bool):
	_is_object_interactible = is_interactible
	$CollisionShape3D.disabled = !is_interactible or state != State.ACTIVE
	CursorManager.refresh()
	CursorManager.clear_requests()

func _on_mouse_entered() -> void:
	_is_mouse_on_object = true
	sticker_mouse_entered.emit(self)
	if _is_object_interactible:
		CursorManager.request_cursor(CursorManager.CursorType.HOVER)

func _on_mouse_exited() -> void:
	_is_mouse_on_object = false
	sticker_mouse_exited.emit(self)
	CursorManager.release_cursor(CursorManager.CursorType.HOVER)

# true if sticker can be interacted with, false otherwise
func _get_interactible() -> bool:
	if state != State.ACTIVE:
		return false
	if _is_mouse_on_object and debug_enabled:
		return true

	if _is_mouse_on_object and _is_object_interactible:
		return true
	return false
