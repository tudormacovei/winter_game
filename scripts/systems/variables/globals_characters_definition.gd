class_name GlobalsCharacterDefinition
extends Resource

const VariableDefinitionClass = preload("res://scripts/systems/variables/variable_definition.gd")

## Must exactly match the character ID of the corresponding CharacterDefinition resource!
@export var character_id: String = ""
@export var definitions: Array[VariableDefinitionClass] = []
func get_initial_state() -> Dictionary:
	var globals_char := {} # Key: character_id + "_" + name, Value: default_value
	for def in definitions:
		globals_char[character_id + "_" + def.name] = def.default_value
	
	return globals_char
