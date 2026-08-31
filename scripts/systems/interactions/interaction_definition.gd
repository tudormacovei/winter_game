## Holds all data about a specific interaction. 
## An interaction is defined as a single meeting between the player and an NPC and it is made up of:
## - A dialogue
## - Some object(s) that the character brings with them
## - Extra data for miscellaneous functionality
##
## Only meant to exist as a resource part of a [code]DayDefinition[/code], not as a standalone file.
class_name InteractionDefinition
extends Resource

const DEFAULT_CONFIG_RESOURCE := preload("res://data/interaction_configs/workshop_default_config.tres")

@export var dialogue: Resource
## The interaction is skippied if the predicate evaluates to false. If left empty, the interaction is always shown.
@export var predicate: VariablePredicate = VariablePredicate.new()
@export var objects: Array[PackedScene]
@export var start_delay_seconds: float = 1 # Delay before starting the interaction
@export var config: Resource = DEFAULT_CONFIG_RESOURCE
