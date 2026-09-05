## Holds all data about a specific day in the game. A day is made up of multiple interactions ([code]InteractionDefinition[/code]).
## 
## Meant to be instantiated in standalone files under the folder res://data/days/
## Filename convention: "day_<number>.tres"
@tool
class_name DayDefintion
extends Resource

const InteractionResource := preload("res://scripts/systems/interactions/interaction_definition.gd")

## ID is auto-set based on filename convention "day_<number>.tres"
@export var day_id: int

@export var interactions: Array[InteractionResource] = []

@export var narrative_text: NarrativeTextDefinition = null
@export var performance_text: PerformanceTextDefinition = null

## Optional override for the first interaction starting time of day. If below 0, will use default config value.
@export_range(-1.0, 1.0) var start_time: float = -1.0

func get_start_time() -> float:
	if start_time < 0.0:
		return Config.TIME_OF_DAY_START
	return clampf(start_time, 0.0, 1.0)

func _validate_property(property: Dictionary) -> void:
	_update_id_from_filename()
	if property.name == "day_id":
		property.usage |= PROPERTY_USAGE_READ_ONLY

func _update_id_from_filename():
	if resource_path == "":
		return

	var file_name = resource_path.get_file()

	var regex = RegEx.new()
	regex.compile("day_(\\d+)")
	var result = regex.search(file_name)
	
	if result:
		var new_id = int(result.get_string(1))
		if day_id != new_id:
			day_id = new_id
			notify_property_list_changed() # Update Inspector display
			print("Day ID for file %s updated to %d based on filename." % [file_name, day_id])
	else:
		Utils.debug_error("File %s does not match naming convention 'day_<number>.tres'" % file_name)
