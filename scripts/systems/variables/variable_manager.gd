## Manages all variables in the game:
## - state variables - global and local (only accessed in a single dialogue)
class_name VariableManager
extends Node

const globals: GlobalVariablesDefinition = preload("res://data/global_variables.tres")

var variables: Dictionary = {}
var _local_variables_keys: Array[String] = []

func _ready():
	if globals:
		variables = globals.get_initial_state()
	else:
		_debug_error("Global variables could not be initialized!")
		
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)


func get_var(var_name: String) -> Variant:
	if not variables.has(var_name):
		_debug_error("Variable '%s' does not exist!" % var_name)
		return
		
	return variables.get(var_name)

func set_var(var_name: String, value):
	if not variables.has(var_name):
		_debug_error("Variable '%s' does not exist!" % var_name)
		return
	if typeof(variables[var_name]) != typeof(value):
		_debug_error("Variable type mis-match for var '%s' and value '%s'!" % [var_name, value])
		return
	
	variables[var_name] = value

func add_local(var_name: String, initial_value):
	if variables.has(var_name):
		_debug_error("Variable '%s' already exists! You cannot add it again!" % var_name)
		return
		
	variables[var_name] = initial_value
	_local_variables_keys.append(var_name)

func _on_dialogue_ended(resource):
	# TODO[ziana]: Test this after scene set-up is done!
	for key in _local_variables_keys:
		variables.erase(key)
	
	print("VariableManager:_on_dialogue_ended Cleared locals, dialogue finished:", resource)

static func _debug_error(message: String):
	push_error(message)
	if OS.has_feature("debug"):
		OS.alert(message)
	
