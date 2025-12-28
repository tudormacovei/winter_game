extends Node3D

var interactible: bool = true

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

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
