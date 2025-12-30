## Holds all data about a specific day in the game. A day is made up of multiple interactions ([code]InteractionDefintion[/code]).
## 
## Meant to be instantiated in standalone files under the folder res://data/days/
## TODO[ziana]: Implement - Files will then be read at runtime to programatically build the game flow 
## Filename convention: "day_<number>.tres"
@tool
class_name DayDefintion
extends Resource

const InteractionResource := preload("res://scripts/systems/interactions/interaction_definition.gd")

@export var day_id: int # ID is auto-set based on filename convention
@export var interactions: Array[InteractionResource] = []

func _validate_property(_property: Dictionary) -> void:
    _update_id_from_filename()

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
