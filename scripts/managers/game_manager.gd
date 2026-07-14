# Responsible for managing game flow. 
# Days are loaded from specified directory. They are ordered alphabetically by filename and played in sequence.
class_name GameManager
extends Node

signal day_started(day_index: int)
signal day_ended(day_index: int)

const DayDefinition := preload("res://scripts/systems/interactions/day_definition.gd")
const CharacterDefinition := preload("res://scripts/systems/interactions/character_definition.gd")

# Sticker spawning configuration.
# STICKER_TYPES is the global asset registry; DIFFICULTY_TABLE maps difficulty to indices into STICKER_TYPES
const STICKER_TYPES: Array[PackedScene] = [
	preload("res://scenes/sticker_interaction/sticker_peel/sticker_peel.tscn"),
	preload("res://scenes/sticker_interaction/sticker_peel/sticker_peel_directional.tscn"),
	preload("res://scenes/sticker_interaction/sticker_peel/sticker_peel_timed.tscn"),
]

const DIFFICULTY_TABLE: Array[Dictionary] = [
	{"types": [0], "fraction": 0.50}, # 0: peel only
	{"types": [0, 1], "fraction": 0.60}, # 1: + directional
	{"types": [0, 1, 2], "fraction": 0.70}, # 2: + timed
	{"types": [0, 1, 2], "fraction": 0.80}, # 3
	{"types": [0, 1, 2], "fraction": 0.90}, # 4
	{"types": [0, 1, 2], "fraction": 1.00}, # 5
]

const MAX_DIFFICULTY: int = 5
var current_difficulty: int = 5 # hardcoded for now; will be driven by game progression later


## Returns the eligible sticker scenes and count fraction for the given difficulty.
static func get_sticker_spawn_config(difficulty: int) -> Dictionary:
	var clamped: int = clampi(difficulty, 0, MAX_DIFFICULTY)
	var row: Dictionary = DIFFICULTY_TABLE[clamped]
	var types: Array[PackedScene] = []
	for idx in row["types"]:
		types.append(STICKER_TYPES[idx])
	return {"types": types, "fraction": row["fraction"] as float}

@onready var workbench := %WorkbenchView
@onready var ui_manager := %UIManager
@onready var health_manager: HealthManager = %HealthManager
@onready var character_node := get_node("/root/Workspace/CameraSpace/DialogueView/DialogueCharacterTexture")
@onready var time_manager := %TimeManager

var _day_resources: Array[DayDefinition] = []
var _character_dict: Dictionary = {} # Key: character_id, Value: CharacterDefinition

var current_day_index: int = -1
var current_interaction_index: int = -1
var is_dialogue_running: bool = false
var current_dialogue_balloon = null

# Interaction cancelling variables
# Starting a new interaction invalidates previous interaction tokens. This is used to cancel pending interactions and only start the most recent one.
# NOTE: GDScript is single threaded by default. Cancelling logic could look like a race condition, but it doesn't seem to be in practice. 
var _interaction_start_pending: bool = false
var _interaction_start_token: int = 0

func _ready():
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)
	DialogueManager.got_dialogue.connect(_on_dialogue_line_started)
	workbench.connect("all_objects_completed", _on_all_objects_completed)
	tree_exiting.connect(_on_tree_exiting)

	day_started.connect(health_manager.reset_max_health.unbind(1)) # reset HP needed on day start so debug skips also reset HP
	day_ended.connect(health_manager.reset_max_health.unbind(1)) # reset HP on day end to remove low-HP effects

	_load_day_resources()
	_load_character_resources()

	current_day_index = 0
	day_started.emit(0)
	_play_next_interaction()

	AudioManager.play_music(Config.AMBIENT_MUSIC_FILE_NAME)

	DialogueFuncs.register_game_manager(self)
	if OS.is_debug_build():
		DebugUI.register_debug_target(self)

#region Dialogue Functions

func dialogue_add_object_to_workbench(object_name: String):
	_add_object_to_workbench(load(Config.OBJECTS_SCENES_PATH + "/" + object_name + ".tscn"))

#endregion

#region Data Loading Functions

func _load_day_resources():
	_day_resources.clear()

	var files = Array(ResourceLoader.list_directory(Config.DAY_RESOURCES_PATH))

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

	var files = Array(ResourceLoader.list_directory(Config.CHARACTER_RESOURCES_PATH))
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

# TODO[ziana]: Integrate time of day changes after an interaction ends
func _play_next_interaction():
	_interaction_start_token += 1
	var current_start_token = _interaction_start_token
	_interaction_start_pending = true

	# Traverse day and interaction arrays
	current_interaction_index += 1
	if current_interaction_index >= _day_resources[current_day_index].interactions.size():
		# Fire day_ended before showing end-of-day UI, to have a clean screen
		day_ended.emit(current_day_index)

		current_day_index += 1
		current_interaction_index = 0

		if current_day_index >= _day_resources.size():
			print("GameManager: All days completed!")
			ui_manager.show_game_end_screen()
			return

		await ui_manager.show_day_end_screen(current_day_index)
		if current_start_token != _interaction_start_token:
			return

		day_started.emit(current_day_index)

	var interaction = _day_resources[current_day_index].interactions[current_interaction_index]
	if not interaction:
		Utils.debug_error("Interaction data is invalid for day %d interaction %d" % [current_day_index + 1, current_interaction_index])
		return
	
	if not interaction.dialogue:
		Utils.debug_error("Dialogue is invalid for day %d interaction %d" % [current_day_index + 1, current_interaction_index])
		return

	_update_time_of_day()

	# Wait for start delay
	if not (OS.is_debug_build() and debug_disable_interaction_delay):
		await get_tree().create_timer(interaction.start_delay_seconds).timeout
		if current_start_token != _interaction_start_token:
			return

	# Start the character interaction
	current_dialogue_balloon = DialogueManager.show_dialogue_balloon(interaction.dialogue, "initialize_local_variables", [GameState])
	ui_manager.set_balloon_layer(current_dialogue_balloon)
	call_deferred("_deferred_connect_spoke_signal") # NOTE: Nodes inside the dialogue balloon are not created at this point, so we cannot connect signals to them.
	is_dialogue_running = true

	workbench.reset_workbench()
	for object_scene: PackedScene in interaction.objects:
		_add_object_to_workbench(object_scene)

	_interaction_start_pending = false
	print("GameManager: Starting day %d interaction %d" % [current_day_index + 1, current_interaction_index])

# Next interaction is played when dialogue ends and there are no more objects on the workbench
func _try_play_next_interaction():
	if is_dialogue_running:
		return
	if not workbench.is_workbench_empty():
		ui_manager.try_show_object_state_ui()
		return

	_play_next_interaction()

#region Helper Functions

func _update_time_of_day():
	if not time_manager:
		return

	var total_interactions: int = _day_resources[current_day_index].interactions.size()
	var day_progress: float = float(current_interaction_index) / max(1, total_interactions - 1)
	var do_lerp: bool = current_interaction_index > 0 # Don't lerp on the first interaction
	time_manager.set_target_time_of_day(day_progress, do_lerp)

func _add_object_to_workbench(object_scene: PackedScene):
	var object = workbench.add_object(object_scene)
	if object == null:
		return
		
	object.connect("object_completed", _on_object_completed)
	health_manager.register_object(object)

func _deferred_connect_spoke_signal():
	if current_dialogue_balloon and current_dialogue_balloon.dialogue_label:
		current_dialogue_balloon.dialogue_label.connect("spoke", _on_dialogue_letter_spoke)
		return
		
	call_deferred("_deferred_connect_spoke_signal") # Try again if dialogue label is not available yet

#endregion

#region Signals

## Clean up active dialogue when leaving the scene (pause menu -> main menu).
## Without this DialogueManager (which is an autoload) retains stale dialogue state accross scene changes
func _on_tree_exiting():
	# Disconnect local functions from the dialogueManager to ensure the emit() below does not trigger
	# these functions while we are exiting the tree (this is spaghetti asf)
	DialogueManager.dialogue_ended.disconnect(_on_dialogue_ended)
	DialogueManager.got_dialogue.disconnect(_on_dialogue_line_started)

	if current_dialogue_balloon and not current_dialogue_balloon.is_queued_for_deletion():
		current_dialogue_balloon.queue_free()
	if is_dialogue_running:
		DialogueManager.dialogue_ended.emit(null) # TODO: would be nice to cleanup calls like this and not call the emit of other objects

func _on_object_completed(object_name: String, is_special_object: bool, completed_stickers: int, total_stickers: int):
	var sticker_completion_percentage = 100 if total_stickers == 0 else int(float(completed_stickers) / total_stickers * 100)
	if total_stickers == 0:
		Utils.debug_error("Object '%s' has NO stickers! Its sticker completion percentage is set to 100." % object_name)

	# Update sabotage variables
	if is_special_object:
		Variables.add_or_modify_special_object_var(object_name, sticker_completion_percentage)
	else:
		# For simple objects aggregated score, use EMA calculation  
		var current_score = Variables.get_var(Config.SCORE_SIMPLE_OBJECTS_VAR_KEY)
		var new_score = current_score * (1 - Config.SCORE_SIMPLE_OBJECTS_SMOOTHING_FACTOR) + sticker_completion_percentage * Config.SCORE_SIMPLE_OBJECTS_SMOOTHING_FACTOR
		Variables.set_var(Config.SCORE_SIMPLE_OBJECTS_VAR_KEY, int(new_score))

func _on_all_objects_completed():
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
		Utils.debug_error("GameManager: Dialogue line references unknown character '%s'" % dialogue_line.character)
		character_node.texture = null
		return
		
	var sprite_to_set = _character_dict[dialogue_line.character].default_sprite
	var sprite_change_tag = dialogue_line.get_tag_value(Config.DIALOGUE_TAGS.SPRITE_CHANGE)
	if sprite_change_tag:
		sprite_to_set = _character_dict[dialogue_line.character].alt_sprites[sprite_change_tag]

	character_node.texture = sprite_to_set

var letter_spoke_counter = 0
func _on_dialogue_letter_spoke(_letter: String, _letter_index: int, _speed: float):
	letter_spoke_counter += 1
	if letter_spoke_counter % Config.LETTER_SPOKE_FREQUENCY == 0:
		letter_spoke_counter = 0
		AudioManager.play_sfx_on_letter_spoke()

#endregion

#region Debug

var debug_disable_interaction_delay: bool = false

func debug_get_current_day_number() -> int:
	return current_day_index + 1

func debug_get_current_interaction_number() -> int:
	return current_interaction_index

func debug_get_current_dialogue() -> String:
	if current_day_index >= _day_resources.size() or current_interaction_index >= _day_resources[current_day_index].interactions.size():
		return "None"

	var interaction = _day_resources[current_day_index].interactions[current_interaction_index]
	if not interaction:
		return "None"
	if not interaction.dialogue:
		return "None"
	return interaction.dialogue.resource_path

func debug_play_next_interaction():
	if current_day_index >= _day_resources.size():
		Utils.debug_alert("Debug: Cannot play next interaction. All days have been completed.")
		return
	
	if _interaction_start_pending:
		_interaction_start_token += 1
		print("Debug: Cancelling pending interaction...")

	if not workbench.is_workbench_empty():
		workbench.reset_workbench()

	#NOTE: Dialogue balloon needs to be manually cleaned up. DialogueManager only cleans it up when last dialogue line is reached.
	#NOTE: Emitting the dialogue ended signal will let other systems cleanup for themselves.
	if current_dialogue_balloon and not current_dialogue_balloon.is_queued_for_deletion():
		print("Debug: Skipping to next interaction...")
		
		current_dialogue_balloon.queue_free()
		DialogueManager.dialogue_ended.emit(_day_resources[current_day_index].interactions[current_interaction_index].dialogue)
		return # NOTE: Early out since emitting signal above will skip to the next interaction by default

	print("Debug: Starting next interaction...")
	_play_next_interaction()

func debug_start_day(day_number: int):
	if day_number < 1 or day_number > _day_resources.size():
		Utils.debug_alert("Debug: Invalid day number %d. Must be between 1 and %d" % [day_number, _day_resources.size()])
		return

	ui_manager.debug_hide_game_end_screen()
	current_day_index = day_number - 1
	day_started.emit(current_day_index)
	current_interaction_index = -1

	print("Debug: Starting day %d" % day_number)
	debug_play_next_interaction()

#endregion
