extends CanvasLayer

@onready var anim_player: AnimationPlayer = $Balloon/AnimationPlayer
@onready var margin_container: MarginContainer = $Balloon/MarginContainer

func _ready() -> void:
	visibility_changed.connect(_on_visibility_changed)

func _on_visibility_changed() -> void:
	if visible:
		anim_player.play("dialogue_status_pop_in")
