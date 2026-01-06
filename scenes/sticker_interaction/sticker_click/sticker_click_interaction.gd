class_name Sticker extends Area3D

var _is_mouse_on_object := false
var _is_object_interactible := false

signal sticker_completed()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass

func _complete_sticker():
	#print("Completed sticker!")
	sticker_completed.emit()
	queue_free() # destroy object

func _input(event: InputEvent) -> void:
	if event.is_action_released("mouse_click_left") and _get_interactible():
		get_viewport().set_input_as_handled()
		_complete_sticker()

func _on_object_interactible_change(is_interactible: bool):
	_is_object_interactible = is_interactible
	$CollisionShape3D.disabled = !is_interactible

func _on_mouse_entered() -> void:
	#print("INFO:: Mouse entered sticker")
	_is_mouse_on_object = true

func _on_mouse_exited() -> void:
	#print("INFO:: Mouse exited sticker")
	_is_mouse_on_object = false

# true if sticker can be interacted with, false otherwise
func _get_interactible() -> bool:
	if _is_mouse_on_object and _is_object_interactible:
		return true
	return false
