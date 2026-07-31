class_name InteractionConfigController
extends Node3D

var current_config: InteractionConfigDefinition = null

var _camera: CameraControl = null

func apply_config(config: Resource) -> void:
	if config is InteractionConfigDefinition:
		config = config as InteractionConfigDefinition
	else:
		Utils.debug_error("InteractionConfigController: Config is invalid")
		return

	if current_config == config:
		return

	current_config = config
	_apply_scene_by_name(config.scene_name)
	_apply_camera_rules(config.is_camera_locked)
	_apply_audio_ambient(config.audio_ambient_file_name)
	
func _apply_camera_rules(is_locked: bool) -> void:
	# NOTE: We lazily resolve the camera because otherwise the scene tree is not ready yet :/
	_resolve_camera()
	if _camera:
		_camera.set_locked_to_dialogue(is_locked)
	else:
		get_tree().root.call_deferred("_apply_camera_rules", is_locked)


func _apply_scene_by_name(scene_name: String) -> void:
	if not scene_name or scene_name == "":
		Utils.debug_error("InteractionConfigController: Could not apply scene due to invalid name.")
		return

	var success: bool = false
	for child in get_children():
		if child.name == scene_name:
			child.visible = true
			success = true
		else:
			child.visible = false

	if not success:
		Utils.debug_error("InteractionConfigController: Could not find scene '%s' to apply." % scene_name)

func _apply_audio_ambient(audio_file_name: String) -> void:
	AudioManager.play_ambient_stream(audio_file_name)

#region Helpers

func _resolve_camera() -> void:
	if _camera:
		return

	_camera = %Camera3D

#endregion