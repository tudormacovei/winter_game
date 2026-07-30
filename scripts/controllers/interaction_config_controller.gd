class_name InteractionConfigController
extends Node3D

func apply_config(config: Resource) -> void:
	if config is InteractionConfigDefinition:
		config = config as InteractionConfigDefinition
	else:
		Utils.debug_error("InteractionConfigController: Config is invalid")
		return

	_apply_scene_by_name(config.scene_name)


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