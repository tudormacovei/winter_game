class_name VariableManager
extends Node

const globals: GlobalVariablesDefinition = preload("res://data/global_variables.tres")

var variables: Dictionary = {}

func _ready():
	if globals:
		variables = globals.get_initial_state()
	else:
		push_error("Global variables could not be initialized!")


func get_var(var_name: String):
	return variables.get(var_name)

func set_var(var_name: String, value):
	if not variables.has(var_name):
		push_error("Variable '%s' does not exist!" % var_name)
		return

	variables[var_name] = value
