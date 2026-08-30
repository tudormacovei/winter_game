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
		await _ui_manager.fade_to_black(_ui_manager._SCREEN_FADE_DURATION_INTERACTION_CONFIGS)
	else:
		await _ui_manager.fade_to_black(0.0)

	current_config = config
	_apply_scene_by_name(config.scene_name)
	_apply_camera_rules(config.is_camera_locked)
	_apply_audio_ambient(config.audio_ambient_file_name)

	await _ui_manager.fade_from_black(_ui_manager._SCREEN_FADE_DURATION_INTERACTION_CONFIGS)
	
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
			var animator := child.find_child("CharacterAnimator", true, false) as CharacterAnimator
			if animator:
				animator.clear() # view is hidden, stop computing animations

	if not success:
		Utils.debug_error("InteractionConfigController: Could not find scene '%s' to apply." % scene_name)


## The character animator of the visible view, null when the view has none
func get_character_animator() -> CharacterAnimator:
	for child in get_children():
		if child.visible:
			return child.find_child("CharacterAnimator", true, false) as CharacterAnimator
	return null

func _apply_audio_ambient(audio_file_name: String) -> void:
	if not audio_file_name or audio_file_name == "":
		AudioManager.stop_ambient()
		return

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
