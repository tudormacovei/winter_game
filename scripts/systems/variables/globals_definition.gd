@tool
class_name GlobalVariablesDefinition
extends Resource

const VariableDefinition = preload("res://scripts/systems/variables/variable_definition.gd")

@export var definitions: Array[VariableDefinition] = []

@export var dump_vars_path: String = "res://data/global_variables_overview.txt"

@export_tool_button("Dump Globals To File")
var dump_button := dump_to_file

func get_initial_state() -> Dictionary:
	var globals := {}
	for def in definitions:
		globals[def.name] = def.default_value
	return globals

#region Tool Functions

## Dump all variables to a file for overiew and searching
func dump_to_file() -> void:
	if not Engine.is_editor_hint():
		return

	#NOTE: Opening in WRITE mode clears existing contents of file / creates new file
	var file := FileAccess.open(dump_vars_path, FileAccess.WRITE)
	if file == null:
		push_error("Failed to open file: " + dump_vars_path)
		return

	file.store_line("Generated at: %s" % Utils.get_timestamp_string())
	file.store_line("----------------------------------------")
	file.store_line("")
	for i in definitions.size():
		var def := definitions[i]
		if def == null:
			continue

		file.store_line("[%d] %s" % [i, def.name])
		file.store_line("  Description: %s" % def.description)
		file.store_line("  Default: %s" % str(def.default_value))
		file.store_line("")

	file.close()

	print("Global variables dumped to file at path: ", dump_vars_path)

#endregion Tool Functions
