# Responsible for managing game flow. 
# Days are loaded from specified directory. They are ordered alphabetically by filename and played in sequence.
class_name GameManager
extends Node

const DayDefinition := preload("res://scripts/systems/interactions/day_definition.gd")
const CharacterDefinition := preload("res://scripts/systems/interactions/character_definition.gd")

var current_day_index: int = -1
var current_interaction_index: int = -1

var _day_resources: Array[DayDefinition] = []
var _character_dict: Dictionary = {} # Key: character_id, Value: CharacterDefinition

@onready var ui_manager := %UIManager
@onready var character_node := get_node("/root/Workspace/DialogueView/DialogueCharacterTexture")

func _ready():
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)
	DialogueManager.got_dialogue.connect(_on_dialogue_line_started)

	_load_day_resources()
	_load_character_resources()

	current_day_index = 0
	_play_next_interaction()

#region Data Loading Functions

func _load_day_resources():
	_day_resources.clear()

	var dir = DirAccess.open(Utils.DAY_RESOURCES_PATH)
	if dir:
		dir.list_dir_begin()
		var files = []
		for file_name in dir.get_files():
			if file_name.ends_with(".tres"):
				files.append(file_name)

		# Sort filenames alphabetically
		files.sort()
		for f in files:
			var resource = load(Utils.DAY_RESOURCES_PATH + f)
			if resource and resource is DayDefinition:
				_day_resources.append(resource)
				print("GameManager: Loaded day from file '%s'" % f)
			elif resource:
				push_warning("Day resource '%s' is not a valid DayDefinition and will not be considered." % f)

func _load_character_resources():
	_character_dict.clear()

	var dir = DirAccess.open(Utils.CHARACTER_RESOURCES_PATH)
	if dir:
		dir.list_dir_begin()
		var files = []
		for file_name in dir.get_files():
			if file_name.ends_with(".tres"):
				files.append(file_name)

		for f in files:
			var resource = load(Utils.CHARACTER_RESOURCES_PATH + f)
			if resource and resource is CharacterDefinition:
				if resource.character_id in _character_dict:
					push_warning("Character resource '%s' has duplicate id '%s' and will be skipped." % [f, resource.character_id])
					continue
				
				# TODO: When switching to character_id in dialogue, make that the key and do sprite display based on that instead of display_name 
				_character_dict[resource.display_name] = resource
				print("GameManager: Loaded character '%s' from file '%s'" % [resource.character_id, f])
			elif resource:
				push_warning("Character resource '%s' is not a valid CharacterDefinition and will not be considered." % f)

#endregion

func _play_next_interaction():
	# Traverse day and interaction arrays
	current_interaction_index += 1
	if current_interaction_index >= _day_resources[current_day_index].interactions.size():
		current_day_index += 1
		current_interaction_index = 0

		# TODO: Handle end of game
		if current_day_index >= _day_resources.size():
			print("GameManager: All days completed!")
			return

	var interaction = _day_resources[current_day_index].interactions[current_interaction_index]
	if not interaction:
		Utils.debug_error("Interaction data is invalid for day %d interaction %d" % [current_day_index + 1, current_interaction_index])
		return
	
	if not interaction.dialogue:
		Utils.debug_error("Dialogue is invalid for day %d interaction %d" % [current_day_index + 1, current_interaction_index])
		return

	# Start the interaction
	var dialogue_balloon = DialogueManager.show_dialogue_balloon(interaction.dialogue, "initialize_local_variables")
	ui_manager.balloon_layer = dialogue_balloon
	print("GameManager: Starting day %d interaction %d" % [current_day_index + 1, current_interaction_index])

#region Signals

func _on_dialogue_ended(_resource):
	_play_next_interaction()
	# TODO[ziana]: Handle timing/transitions in-between interactions
	# TODO[ziana]: Handle day end and game end by showing a dark screen with text "Day X Complete"

func _on_dialogue_line_started(dialogue_line):
	# Set character sprite
	if dialogue_line.character.is_empty():
		character_node.texture = null
		return

	if not _character_dict.has(dialogue_line.character):
		Utils.debug_error("Dialogue line references unknown character '%s'" % dialogue_line.character)
		character_node.texture = null
		return
		
	character_node.texture = _character_dict[dialogue_line.character].sprite

#endregion
