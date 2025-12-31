## Holds all data about a specific interaction. 
## An interaction is defined as a single meeting between the player and an NPC and it is made up of:
## - A character
## - A dialogue
## - [TODO] Some object(s) that the character brings with them
##
## Only meant to exist as a resource part of a [code]DayDefinition[/code], not as a standalone file.
class_name InteractionDefinition
extends Resource

const CharacterResource := preload("res://scripts/systems/interactions/character_definition.gd")

@export var character: CharacterResource
@export var dialogue: Resource

#TODO: Add variables for objects 
