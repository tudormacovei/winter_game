## Holds all data about a specific NPC
class_name CharacterDefinition
extends Resource

@export var character_id: String
@export var display_name: String
@export var description: String # Optional to give more context for the developers
@export var default_sprite: Texture2D
@export var alt_sprites: Dictionary[String, Texture2D] = {} # Key: Identifier used in dialogue tags
@export var speaking_push_distance: float = 0.2 ## How far this character pushes the other characters aside while it is speaking (world units on x-axis)
