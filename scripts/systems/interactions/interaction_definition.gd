## Holds all data about a specific interaction. 
## An interaction is defined as a single meeting between the player and an NPC and it is made up of:
## - A dialogue
## - [TODO] Some object(s) that the character brings with them
##
## Only meant to exist as a resource part of a [code]DayDefinition[/code], not as a standalone file.
class_name InteractionDefintion
extends Resource

#TODO: Add variables for objects 
#TODO[ziana]: When implementing, figure out if character_id var is necessary or if it can be inferred from the dialogue

@export var dialogue: Array[Resource] = []
