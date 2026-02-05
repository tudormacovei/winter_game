# Clickable area that gets removed when the player clicks it.
#
# Not interactible by default, _on_object_interactible_change must
# be connected to signal from parent object.
class_name StickerClick extends Sticker

func _ready() -> void:
	pass

func _input(event: InputEvent) -> void:
	if event.is_action_released("mouse_click_left") and _get_interactible():
		get_viewport().set_input_as_handled()
		_complete_sticker()
