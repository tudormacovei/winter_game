extends CanvasLayer

@onready var anim_player: AnimationPlayer = $AnimationPlayer

enum GameStateUIType {
	DIALOGUE,
	# TODO[ziana]: Add object game state UI
}

func show_game_state_ui(ui_type: GameStateUIType) -> void:
	var vars: Dictionary = _get_ui_type_variables(ui_type)
	if vars.is_empty():
		push_error("GameStateUI:show_game_state_ui Invalid UI type")
		return

	if vars["root_node"].visible:
		return

	var margin_container: MarginContainer = vars["root_node"].get_node("MarginContainer")
	margin_container.scale = Vector2.ZERO
	
	vars["root_node"].show()
	anim_player.play(vars["show_anim_name"])

func hide_game_state_ui(ui_type: GameStateUIType) -> void:
	var vars: Dictionary = _get_ui_type_variables(ui_type)
	if vars.is_empty():
		push_error("GameStateUI:hide_game_state_ui Invalid UI type")
		return

	vars["root_node"].hide()

func _get_ui_type_variables(ui_type: GameStateUIType) -> Dictionary:
	match ui_type:
		GameStateUIType.DIALOGUE:
			return {
				"root_node": $DialogueStateUI,
				"show_anim_name": "dialogue_state_ui_show",
			}

	return {}
