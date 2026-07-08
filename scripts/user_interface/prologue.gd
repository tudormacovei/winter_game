extends Node2D

const PROLOGUE_DIALOGUE: Resource = preload("res://data/dialogue/NPC_0/NPC_0_1.dialogue")
const WORKSPACE_SCENE: PackedScene = preload("res://scenes/main_game_view/workspace.tscn")

var _active_balloon = null

func _ready() -> void:
    DialogueManager.dialogue_ended.connect(_on_dialogue_ended)
    _start_prologue_dialogue()

func _start_prologue_dialogue() -> void:
    _active_balloon = DialogueManager.show_dialogue_balloon(PROLOGUE_DIALOGUE)

func _on_dialogue_ended(resource: Resource) -> void:
    if resource != PROLOGUE_DIALOGUE:
        return 

    DialogueManager.dialogue_ended.disconnect(_on_dialogue_ended)

    SceneManager.set_meta("start_day_index", 0)
    SceneManager.set_meta("next_interaction_to_play", 1)

    # switch scene
    SceneManager.change_scene(WORKSPACE_SCENE)

func _exit_tree() -> void:
    # defensive disconnect if still connected
    pass