extends CanvasLayer

@onready var anim_player: AnimationPlayer = $Balloon/AnimationPlayer
@onready var margin_container: MarginContainer = $Balloon/MarginContainer

func show_state_balloon() -> void:
	margin_container.scale = Vector2.ZERO
	show()
	anim_player.play("dialogue_status_pop_in")
