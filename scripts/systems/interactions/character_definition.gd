## Holds all data about a specific NPC
class_name CharacterDefinition
extends Resource

@export var character_id: String
@export var display_name: String
@export var description: String # Optional to give more context for the developers
@export var default_sprite: Texture2D
@export var alt_sprites: Dictionary[String, Texture2D] = {} # Key: Identifier used in dialogue tags
@export var X_offset: float = 0.2 ## How much to offset the character sprite on the X axis whenever it's on screen
# NOTE: X_offset is a hack since the sprites are not centered properly. Check PrimarySlot in dialogue_view and Sarah for the source of truth.
