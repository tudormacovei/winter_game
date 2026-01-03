class_name Sticker extends Area3D

var _is_mouse_on_object := false
var _is_object_interactible := false

signal sticker_completed()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

func _input(event: InputEvent) -> void:
	if event.is_action_released("mouse_click_left") and _get_interactible():
		print("Completed sticker!")
		sticker_completed.emit()

# Flow:
# Receive input event click
# IF click is inside the area of this object
# complete the sticker

# Question: how do we make the stickers non-interactible?
# the stickers should only react to input if we are in a state when we can interact with them
# idea for solving this: sticker subscribes to event fired by interactible object
# so we will have bidirectional communication, the sticker listening to the object to check if
# it should be in an interactible state, and the object listening to the sticker to change its
# state (how well the object was repaired)

func _on_object_interactible_change(is_interactible: bool):
	_is_object_interactible = is_interactible

func _on_mouse_entered() -> void:
	_is_mouse_on_object = true


func _on_mouse_exited() -> void:
	_is_mouse_on_object = false

# returns true if sticker can be interacted with, false otherwise
func _get_interactible() -> bool:
	if _is_mouse_on_object and _is_object_interactible:
		return true
	return false
