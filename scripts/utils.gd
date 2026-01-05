@tool
extends Node

func debug_error(message: String):
    push_error(message)
    if OS.has_feature("debug"):
        OS.alert(message)

func get_timestamp_string() -> String:
    var dt := Time.get_datetime_dict_from_system()
    return "%04d-%02d-%02d %02d:%02d:%02d" % [
        dt.year, dt.month, dt.day,
        dt.hour, dt.minute, dt.second
    ]