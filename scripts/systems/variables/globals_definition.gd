## Defines global variables, both general and for each character
@tool
class_name GlobalVariablesDefinition
extends Resource

const VariableDefinition = preload("res://scripts/systems/variables/variable_definition.gd")
const GlobalsCharacterDefinition = preload("res://scripts/systems/variables/globals_characters_definition.gd")

## General global variable definitions
@export var definitions: Array[VariableDefinition] = []
## Character-specific global variable definitions
@export var character_definitions: Array[GlobalsCharacterDefinition] = []

#region Tool Variables

const DUMP_VARS_PATH: String = "res://data/global_variables_overview.txt"

@export_tool_button("Dump Globals To File")
var dump_button := dump_to_file

#endregion Tool Variables

func get_initial_state() -> Dictionary:
	var globals := {}
	
	# Add general globals
	for def in definitions:
		if globals.has(def.name):
			Utils.debug_error("Duplicate global variable name detected: '%s'. Overwriting previous value." % def.name)
		globals[def.name] = def.default_value
	
	# Add character-specific globals
	for char_def in character_definitions:
		var char_globals := char_def.get_initial_state()
		for key in char_globals.keys():
			if globals.has(key):
				Utils.debug_error("Duplicate character global variable name detected: '%s'. Overwriting previous value." % key)
			globals[key] = char_globals[key]
	
	return globals

#region Tool Functions

## Dump all variables to a file for overiew and searching
func dump_to_file() -> void:
	if not Engine.is_editor_hint():
		return

	#NOTE: Opening in WRITE mode clears existing contents of file / creates new file
	var file := FileAccess.open(DUMP_VARS_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Failed to open file: " + DUMP_VARS_PATH)
		return

	file.store_line("Generated at: %s" % Utils.get_timestamp_string())
	file.store_line("----------------------------------------")
	file.store_line("")
	for i in definitions.size():
		var def := definitions[i]
		if def == null:
			continue

		file.store_line("[%d] %s" % [i, def.name])
		if def.description != "":
			file.store_line("  Description: %s" % def.description)
		file.store_line("  Default: %s" % str(def.default_value))
		file.store_line("")

	for char_def in character_definitions:
		file.store_line("Character ID: %s" % char_def.character_id)
		for j in char_def.definitions.size():
			var def := char_def.definitions[j]
			if def == null:
				continue

			file.store_line("  [%d] %s" % [j, def.name])
			if def.description != "":
				file.store_line("    Description: %s" % def.description)
			file.store_line("    Default: %s" % str(def.default_value))
			file.store_line("")

	file.close()

	print("Global variables dumped to file at path: ", DUMP_VARS_PATH)

#endregion Tool Functions
