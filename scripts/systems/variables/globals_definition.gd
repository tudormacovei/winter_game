class_name GlobalVariablesDefinition
extends Resource

const VariableDefinition = preload("res://scripts/systems/variables/variable_definition.gd")

@export var definitions: Array[VariableDefinition] = []

func get_initial_state() -> Dictionary:
	var globals := {}
	for def in definitions:
		globals[def.name] = def.default_value
	return globals
