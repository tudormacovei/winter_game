## Holds all data about a specific interaction. 
## An interaction is defined as a single meeting between the player and an NPC and it is made up of:
## - A dialogue
## - Some object(s) that the character brings with them
## - Extra data for miscellaneous functionality
##
## Only meant to exist as a resource part of a [code]DayDefinition[/code], not as a standalone file.
class_name InteractionDefinition
extends Resource

@export var dialogue: Resource
@export var objects: Array[PackedScene]
@export var start_delay_seconds: float = 1 # Delay before starting the interaction
