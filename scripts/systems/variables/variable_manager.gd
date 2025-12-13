class_name VariableManager
extends Node

const globals: GlobalVariablesDefinition = preload("res://data/global_variables.tres")

var variables: Dictionary = {}

func _ready():
	if globals:
		variables = globals.get_initial_state()
	else:
		_debug_error("Global variables could not be initialized!")


func get_var(var_name: String):
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


static func _debug_error(message: String):
	push_error(message)
	if OS.has_feature("debug"):
		OS.alert(message)
	
