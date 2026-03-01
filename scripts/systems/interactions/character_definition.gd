## Holds all data about a specific NPC
class_name CharacterDefintion
extends Resource

@export var character_id: String
@export var display_name: String
@export var description: String # Optional to give more context for the developers
@export var default_sprite: Texture2D
@export var alt_sprites: Dictionary[String, Texture2D] = {} # Key: Identifier used in dialogue tags
