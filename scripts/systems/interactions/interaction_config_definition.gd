## Holds information about what an interaction looks like and the rules it applies.
## 
## Meant to be instantiated and configured in standalone files under the folder res://data/interaction_configs/
## Meant to be used as a resource in [code]InteractionDefinition[/code]
class_name InteractionConfigDefinition
extends Resource

const DEFAULT_SCENE_NAME: String = "DialogueView"
const DEFAULT_DIALOGUE_BALLOON_SCENE: PackedScene = preload("res://scenes/UI/dialogue_baloon/dialogue_balloon.tscn")
const DEFAULT_AUDIO_AMBIENT_FILE_NAME: String = "amb_music"

# TODO: Right now, this is used to show/hide existing scene instances. Ideally, this should hold a scene reference and load it / clean up other scenes when needed.
@export var scene_name: String = DEFAULT_SCENE_NAME

@export var is_camera_locked: bool = false

@export var dialogue_balloon_scene: PackedScene = DEFAULT_DIALOGUE_BALLOON_SCENE

## This file must be in the audio streams folder!
@export var audio_ambient_file_name: String = DEFAULT_AUDIO_AMBIENT_FILE_NAME