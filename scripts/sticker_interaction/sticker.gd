# Clickable area that gets removed when the player clicks it.
#
# Not interactible by default, _on_object_interactible_change must
# be connected to signal from parent object.
class_name Sticker extends Area3D

var _is_mouse_on_object := false
var _is_object_interactible := false

signal sticker_completed()

func _ready() -> void:
	pass

func _complete_sticker():
	#print("Completed sticker!")
	sticker_completed.emit()
	queue_free()

func _input(event: InputEvent) -> void:
	# Child classes implement specific interactions
	pass

func _on_object_interactible_change(is_interactible: bool):
	_is_object_interactible = is_interactible
	$CollisionShape3D.disabled = !is_interactible

func _on_mouse_entered() -> void:
	print("INFO:: Mouse entered sticker")
	_is_mouse_on_object = true

func _on_mouse_exited() -> void:
	print("INFO:: Mouse exited sticker")
	_is_mouse_on_object = false

# true if sticker can be interacted with, false otherwise
func _get_interactible() -> bool:
	if _is_mouse_on_object and _is_object_interactible:
		return true
	return false
