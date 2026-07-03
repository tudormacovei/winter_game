extends Node2D

var enabled := false

var _tabs := [
	{"name": "General", "draw_func": "_draw_general_tab"},
	{"name": "Dialogue", "draw_func": "_draw_dialogue_tab"},
	{"name": "Visual", "draw_func": "_draw_visual_tab"},
]

var WarningColor: Color = Color(1.0, 0.8, 0.25)

var game_manager: GameManager = null
var time_manager: TimeManager = null
var ui_manager: UIManager = null

#region Debug UI State Variables

#NOTE: Needed for persistent values. Otherwise they would reset every frame.
var general_tab_day_number := ["1"]
var general_tab_disable_interaction_delay := [false]
var general_tab_disable_death_state := [false]
var dialogue_tab_vars_search_text := [""]
var dialogue_tab_set_var_key := [""]
var dialogue_tab_set_var_value := [""]
var visual_tab_time_of_day := [0.0]

#endregion

#region Tab Draw Functions

func _draw_general_tab():
	ImGui.Text("General Information")

	ImGui.Text("Current Day: %d" % game_manager.debug_get_current_day_number())
	ImGui.Text("Current Interaction: %d" % game_manager.debug_get_current_interaction_number())
	ImGui.Text("Current Dialogue: %s" % game_manager.debug_get_current_dialogue())

	ImGui.Separator()

	ImGui.Text("Game Flow")
	ImGui.TextColored(WarningColor, "Warning: Using these might result in an invalid game state!")

	ImGui.Checkbox("Disable interaction start delay", general_tab_disable_interaction_delay)
	ImGui.Checkbox("Disable death state", general_tab_disable_death_state)

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


func _draw_visual_tab():
	if time_manager == null:
		ImGui.TextColored(WarningColor, "Time Manager not found. Cannot display visual debug options.")
		return

	var current_time_of_day: float = time_manager.debug_get_current_time_of_day()
	ImGui.Text("Current Time of Day: %.2f" % current_time_of_day)

	if ImGui.SliderFloat("Override Time of Day", visual_tab_time_of_day, 0.0, 1.0) and time_manager:
		time_manager.debug_set_time_of_day(visual_tab_time_of_day[0])
#endregion

func register_debug_target(target):
	if target is GameManager:
		game_manager = target
	elif target is TimeManager:
		time_manager = target
	elif target is UIManager:
		ui_manager = target
	else:
		push_warning("DebugUI: Tried to register unsupported debug target of type: " + str(target.get_class()))

func _process(_delta):
	if not enabled:
		return

	ImGui.Begin("Debug UI")

	if ImGui.BeginTabBar("Debug Tabs"):
		for tab in _tabs:
			_draw_tab(tab)
		ImGui.EndTabBar()

	ImGui.End()

	# Sync debug options to Game Manager
	if game_manager:
		game_manager.debug_disable_interaction_delay = general_tab_disable_interaction_delay[0]
	
	if ui_manager:
		ui_manager.debug_disable_death_screen = general_tab_disable_death_state[0]



func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_debug_ui"):
		enabled = !enabled

func _draw_tab(tab: Dictionary) -> void:
	if ImGui.BeginTabItem(tab.name):
		call(tab.draw_func)
		ImGui.EndTabItem()
