@tool
extends Node

func debug_error(message: String):
    push_error(message)
    if OS.has_feature("debug"):
        OS.alert(message)
