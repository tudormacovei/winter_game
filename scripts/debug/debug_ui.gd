extends Node2D

var enabled := false

var _tabs := [
	{"name": "General", "draw_func": "_draw_general_tab"},
	{"name": "Dialogue", "draw_func": "_draw_dialogue_tab"},
]

var game_manager: GameManager = null

#region Debug UI State Variables

#NOTE: Needed for persistent text. Otherwise text would reset every frame.
var general_tab_day_number := ["1"]
var dialogue_tab_vars_search_text := [""]
var dialogue_tab_set_var_key := [""]
var dialogue_tab_set_var_value := [""]

#endregion

#region Tab Draw Functions

func _draw_general_tab():
	ImGui.Text("General Information")

	ImGui.TextColored(Color(0.25, 0.6, 1), "TODO: Show general info. Which day, interaction, dialogue etc.")

	ImGui.Separator()

	ImGui.Text("Game Flow")
	ImGui.TextColored(Color(1.0, 0.8, 0.25), "Warning: Using these might result in an invalid game state!")

	if ImGui.Button("Start next interaction"):
		game_manager.debug_play_next_interaction()
	
	ImGui.SetNextItemWidth(80)
	if ImGui.InputInt("Day Number", general_tab_day_number):
		general_tab_day_number[0] = max(general_tab_day_number[0], 1)
	ImGui.SameLine()
	if ImGui.Button("Start day"):
		game_manager.debug_start_day(general_tab_day_number[0])
		

# Show all dialogue variables. Allow searching by variable name
func _draw_dialogue_tab():
	if ImGui.CollapsingHeader("Dialogue Variables"):
		ImGui.InputText("Search", dialogue_tab_vars_search_text, 64)

		# Show current state of all dialogue variables. Allow searching by variable name
		ImGui.BeginChild("DialogueVarsChild", Vector2(0, 200), true)
		var all_vars := Variables.debug_get_all_variables()
		var lines := all_vars.split("\n")
		for line in lines:
			if dialogue_tab_vars_search_text[0] == "" or line.to_lower().find(dialogue_tab_vars_search_text[0].to_lower()) != -1:
				ImGui.Text(line)
		ImGui.EndChild()

		# Button to set a dialogue variable
		ImGui.SetNextItemWidth(150)
		ImGui.InputTextWithHint("##Key", "Key", dialogue_tab_set_var_key, 64)
		ImGui.SameLine()
		ImGui.SetNextItemWidth(80)
		ImGui.InputTextWithHint("##Value", "Value", dialogue_tab_set_var_value, 64)
		ImGui.SameLine()
		if ImGui.Button("Set Variable"):
			Variables.set_var(dialogue_tab_set_var_key[0], str_to_var(dialogue_tab_set_var_value[0]))

#endregion

func register_game_manager(gm: GameManager):
	game_manager = gm

func _process(_delta):
	if not enabled:
		return

	ImGui.Begin("Debug UI")

	if ImGui.BeginTabBar("Debug Tabs"):
		for tab in _tabs:
			_draw_tab(tab)
		ImGui.EndTabBar()

	ImGui.End()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_debug_ui"):
		enabled = !enabled

func _draw_tab(tab: Dictionary) -> void:
	if ImGui.BeginTabItem(tab.name):
		call(tab.draw_func)
		ImGui.EndTabItem()
