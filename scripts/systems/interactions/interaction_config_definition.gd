## Holds information about what an interaction looks like and the rules it applies.
## 
## Meant to be instantiated and configured in standalone files under the folder res://data/interaction_configs/
## Meant to be used as a resource in [code]InteractionDefinition[/code]
class_name InteractionConfigDefinition
extends Resource

const DEFAULT_SCENE_NAME: String = "DialogueView"

# TODO: Right now, this is used to show/hide existing scene instances. Ideally, this should hold a scene reference and load it / clean up other scenes when needed.
@export var scene_name: String = DEFAULT_SCENE_NAME
@export var is_camera_locked: bool = false
