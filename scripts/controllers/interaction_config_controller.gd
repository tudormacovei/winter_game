class_name InteractionConfigController
extends Node3D

var current_config: InteractionConfigDefinition = null

var _ui_manager: UIManager = null
var _camera: CameraControl = null

func apply_config(config: Resource) -> void:
	if config is InteractionConfigDefinition:
		config = config as InteractionConfigDefinition
	else:
		Utils.debug_error("InteractionConfigController: Config is invalid")
		return

	if current_config == config:
		return

	_resolve_camera()
	_resolve_ui_manager()
	
	if current_config:
		await _ui_manager.fade_to_black()
	else:
		await _ui_manager.fade_to_black(0.0)

	current_config = config
	_apply_scene_by_name(config.scene_name)
	_apply_camera_rules(config.is_camera_locked)
	_apply_audio_ambient(config.audio_ambient_file_name)

	await _ui_manager.fade_from_black()
	
func _apply_camera_rules(is_locked: bool) -> void:
	_camera.set_locked_to_dialogue(is_locked)

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

# NOTE: We lazily resolve some nodes because otherwise the scene tree is not ready yet :/

func _resolve_camera() -> void:
	if _camera:
		return

	_camera = %Camera3D

func _resolve_ui_manager() -> void:
	if _ui_manager:
		return
		
	_ui_manager = %UIManager

#endregion
