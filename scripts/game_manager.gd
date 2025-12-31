# Responsible for managing game flow. 
# Days are loaded from specified directory. They are ordered alphabetically by filename and played in sequence.
class_name GameManager
extends Node

const DayDefinition := preload("res://scripts/systems/interactions/day_definition.gd")

const DAY_RESOURCES_PATH: String = "res://data/days/"

var current_day_index: int = -1
var current_interaction_index: int = -1

var _day_resources: Array[DayDefinition] = []

@onready var ui_manager := %UIManager
@onready var character_node := get_node("/root/Workspace/DialogueView/DialogueCharacterTexture")

func _ready():
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)

	_load_day_resources()

	current_day_index = 0
	_play_next_interaction()

func _load_day_resources():
	_day_resources.clear()

	var dir = DirAccess.open(DAY_RESOURCES_PATH)
	if dir:
		dir.list_dir_begin()
		var files = []
		for file_name in dir.get_files():
			if file_name.ends_with(".tres"):
				files.append(file_name)

		# Sort filenames alphabetically
		files.sort()
		for f in files:
			var resource = load(DAY_RESOURCES_PATH + f)
			if resource and resource is DayDefinition:
				_day_resources.append(resource)
				print("GameManager: Loaded day with filename '%s'" % f)
			elif resource:
				push_warning("Day resource '%s' is not a valid DayDefinition and will not be considered." % f)

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
	
	if not interaction.character:
		Utils.debug_error("Character is invalid for day %d interaction %d" % [current_day_index + 1, current_interaction_index])
		return

	if not interaction.dialogue:
		Utils.debug_error("Dialogue is invalid for day %d interaction %d" % [current_day_index + 1, current_interaction_index])
		return

	# Start the interaction
	character_node.texture = interaction.character.sprite
	var dialogue_balloon = DialogueManager.show_dialogue_balloon(interaction.dialogue, "initialize_local_variables")
	ui_manager.balloon_layer = dialogue_balloon
	print("GameManager: Starting day %d interaction %d" % [current_day_index + 1, current_interaction_index])
	
#region Signals

func _on_dialogue_ended(_resource):
	_play_next_interaction()
	# TODO[ziana]: Handle timing/transitions in-between interactions
	# TODO[ziana]: Handle day end and game end by showing a dark screen with text "Day X Complete"

#endregion
