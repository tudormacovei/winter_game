extends CanvasLayer

@onready var anim_player: AnimationPlayer = $AnimationPlayer

enum GameStateUIType {
	DIALOGUE,
	OBJECT,
}

func show_game_state_ui(ui_type: GameStateUIType, delay: float = 0.0) -> void:
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout

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

func hide_all_game_state_ui() -> void:
	for ui_type in GameStateUIType.values():
		hide_game_state_ui(ui_type)

func _get_ui_type_variables(ui_type: GameStateUIType) -> Dictionary:
	match ui_type:
		GameStateUIType.DIALOGUE:
			return {
				"root_node": %DialogueStateUI,
				"show_anim_name": "dialogue_state_ui_show",
			}
		GameStateUIType.OBJECT:
			return {
				"root_node": %ObjectStateUI,
				"show_anim_name": "object_state_ui_show",
			}

	return {}
