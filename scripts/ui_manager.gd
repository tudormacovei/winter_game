# Responsible for managing UI elements and their transitions
# For now, manages behaviour of dialogue balloon
class_name UIManager
extends Node

const CameraControlScript = preload("res://scenes/main_game_view/scripts/camera_control.gd")
	
@onready var camera: CameraControl = %Camera3D

var balloon_layer: CanvasLayer = null

# TODO: Show dialogue state bubble when in workspace view

func _ready() -> void:
	if camera and camera.has_signal("camera_focus_changed"):
		camera.connect("camera_focus_changed", Callable(self, "_on_camera_focus_changed"))

#region Signals

func _on_camera_focus_changed(current_focus) -> void:
	if not balloon_layer:
		return

	# NOTE: It's important that we specifically show / hide the balloon_layer.balloon variable instead of 
	# the entire balloon_layer, so that the input events are propagated correctly based on logic in dialogue balloon script
	if current_focus == CameraControl.CameraFocus.WORK_AREA:
		balloon_layer.balloon.hide()
	elif current_focus == CameraControl.CameraFocus.DIALOGUE_AREA:
		# Delay showing the ballon until the camera rotation is complete
		await get_tree().create_timer(camera.ANIMATION_TIME).timeout
		balloon_layer.balloon.show()
		
#endregion
