## Manages all variables in the game:
## - state variables - global and local (only accessed in a single dialogue)
## - character-specific global variables
extends Node

const globals: GlobalVariablesDefinition = preload("res://data/global_variables.tres")

var variables: Dictionary = {}
var _local_variables_keys: Array[String] = []

func _ready():
	if globals:
		variables = globals.get_initial_state()
	else:
		Utils.debug_error("Global variables could not be initialized!")
		
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)


func get_var(var_name: String) -> Variant:
	if not variables.has(var_name):
		Utils.debug_error("Variable '%s' does not exist!" % var_name)
		return
		
	return variables.get(var_name)

func get_char_var(character_id: String, var_name: String) -> Variant:
	return get_var(_make_char_var_name(character_id, var_name))

func set_var(var_name: String, value):
	if not variables.has(var_name):
		Utils.debug_error("Variable '%s' does not exist!" % var_name)
		return
	if typeof(variables[var_name]) != typeof(value):
		Utils.debug_error("Variable type mis-match for var '%s' and value '%s'!" % [var_name, value])
		return
	
	variables[var_name] = value
	print("VariableManager: Set variable '%s' to value '%s'" % [var_name, value])

func set_char_var(character_id: String, var_name: String, value):
	set_var(_make_char_var_name(character_id, var_name), value)

## Add a value to a numeric variable
func mod_var(var_name: String, value):
	if not variables.has(var_name):
		Utils.debug_error("Variable '%s' does not exist!" % var_name)
		return
	if typeof(variables[var_name]) != TYPE_INT and typeof(variables[var_name]) != TYPE_FLOAT:
		Utils.debug_error("Variable '%s' is not numeric and cannot be added to!" % var_name)
		return
	if typeof(variables[var_name]) != typeof(value):
		Utils.debug_error("Variable type mis-match for var '%s' and value '%s'!" % [var_name, value])
		return
	
	variables[var_name] += value
	print("VariableManager: Modified variable '%s' by value '%s'. New value: '%s'" % [var_name, value, variables[var_name]])

func mod_char_var(character_id: String, var_name: String, value):
	mod_var(_make_char_var_name(character_id, var_name), value)

## Add a new local variable that will be removed when the dialogue ends
func add_local(var_name: String, initial_value):
	if variables.has(var_name):
		Utils.debug_error("Variable '%s' already exists! You cannot add it again!" % var_name)
		return
		
	variables[var_name] = initial_value
	_local_variables_keys.append(var_name)

func _make_char_var_name(character_id: String, var_name: String) -> String:
	# Character specific variable names are stored as: character_id + "_" + var_name
	return "%s_%s" % [character_id, var_name]

#region Signals

func _on_dialogue_ended(_resource):
	for key in _local_variables_keys:
		variables.erase(key)

#endregion

#region Debug

func debug_get_all_variables() -> String:
	var result := ""
	for key in variables.keys():
		result += "%s: %s\n" % [key, str(variables[key])]
	return result

#endregion
