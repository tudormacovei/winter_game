# Responsible for managing game flow. 
# Days are loaded from specified directory. They are ordered alphabetically by filename and played in sequence.
class_name GameManager
extends Node

const DayDefinition := preload("res://scripts/systems/interactions/day_definition.gd")
const CharacterDefinition := preload("res://scripts/systems/interactions/character_definition.gd")

@onready var workbench := %WorkbenchView
@onready var ui_manager := %UIManager
@onready var character_node := get_node("/root/Workspace/DialogueView/DialogueCharacterTexture")

var _day_resources: Array[DayDefinition] = []
var _character_dict: Dictionary = {} # Key: character_id, Value: CharacterDefinition

var current_day_index: int = -1
var current_interaction_index: int = -1
var is_dialogue_running: bool = false
var are_all_objects_completed: bool = true
var current_dialogue_baloon = null

func _ready():
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)
	DialogueManager.got_dialogue.connect(_on_dialogue_line_started)
	workbench.connect("all_objects_completed", _on_all_objects_completed)

	_load_day_resources()
	_load_character_resources()

	current_day_index = 0
	_play_next_interaction()

	if OS.is_debug_build():
		DebugUI.register_game_manager(self )

#region Data Loading Functions

func _load_day_resources():
	_day_resources.clear()

	var dir = DirAccess.open(Config.DAY_RESOURCES_PATH)
	if dir:
		dir.list_dir_begin()
		var files = []
		for file_name in dir.get_files():
			if file_name.ends_with(".tres"):
				files.append(file_name)

		# Sort filenames alphabetically
		files.sort()
		for f in files:
			var resource = load(Config.DAY_RESOURCES_PATH + f)
			if resource and resource is DayDefinition:
				_day_resources.append(resource)
				print("GameManager: Loaded day from file '%s'" % f)
			elif resource:
				push_warning("Day resource '%s' is not a valid DayDefinition and will not be considered." % f)

func _load_character_resources():
	_character_dict.clear()

	var dir = DirAccess.open(Config.CHARACTER_RESOURCES_PATH)
	if dir:
		dir.list_dir_begin()
		var files = []
		for file_name in dir.get_files():
			if file_name.ends_with(".tres"):
				files.append(file_name)

		for f in files:
			var resource = load(Config.CHARACTER_RESOURCES_PATH + f)
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

		if current_day_index >= _day_resources.size():
			print("GameManager: All days completed!")
			ui_manager.show_game_end_screen()
			return

		await ui_manager.show_day_end_screen(current_day_index)

	var interaction = _day_resources[current_day_index].interactions[current_interaction_index]
	if not interaction:
		Utils.debug_error("Interaction data is invalid for day %d interaction %d" % [current_day_index + 1, current_interaction_index])
		return
	
	if not interaction.dialogue:
		Utils.debug_error("Dialogue is invalid for day %d interaction %d" % [current_day_index + 1, current_interaction_index])
		return

	# Wait for start delay
	await get_tree().create_timer(interaction.start_delay_seconds).timeout

	# Start the character interaction
	current_dialogue_baloon = DialogueManager.show_dialogue_balloon(interaction.dialogue, "initialize_local_variables")
	ui_manager.balloon_layer = current_dialogue_baloon
	is_dialogue_running = true

	workbench.reset_workbench()
	for object: PackedScene in interaction.objects:
		workbench.add_object(object)
	if interaction.objects.size() != 0:
		are_all_objects_completed = false

	print("GameManager: Starting day %d interaction %d" % [current_day_index + 1, current_interaction_index])

func _try_play_next_interaction():
	if is_dialogue_running:
		return
	if not are_all_objects_completed:
		return

	_play_next_interaction()

#region Signals

func _on_all_objects_completed():
	are_all_objects_completed = true
	_try_play_next_interaction()

func _on_dialogue_ended(_resource):
	is_dialogue_running = false
	character_node.texture = null
	_try_play_next_interaction()

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

#region Debug

func debug_play_next_interaction():
	#NOTE: Dialogue baloon needs to be manually cleaned up. DialogueManager only cleans it up when last dialogue line is reached. 
	#NOTE: Emitting the dialogue ended signal will let other systems cleanup for themselves.
	current_dialogue_baloon.queue_free()
	DialogueManager.dialogue_ended.emit(_day_resources[current_day_index].interactions[current_interaction_index].dialogue)
	
	print("Debug: Skipping to next interaction...")
	_play_next_interaction()

func debug_start_day(day_number: int):
	if day_number < 1 or day_number > _day_resources.size():
		Utils.debug_error("Debug: Invalid day number %d. Must be between 1 and %d" % [day_number, _day_resources.size()])
		return

	current_day_index = day_number - 1
	current_interaction_index = -1

	print("Debug: Starting day %d" % day_number)
	debug_play_next_interaction()

#endregion