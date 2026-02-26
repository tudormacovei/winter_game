@tool
extends Node

const DAY_RESOURCES_PATH: String = "res://data/days/"
const CHARACTER_RESOURCES_PATH: String = "res://data/characters/"
const OBJECTS_SCENES_PATH: String = "res://scenes/object_manipulation/objects"

const SCORE_SPECIAL_OBJECT_VAR_KEY_PREFIX: String = "prog_score_special_object_"
const SCORE_SIMPLE_OBJECTS_VAR_KEY: String = "prog_score_simple_objects" # NOTE: This needs to be synced with the variable name in global_variables.tres
const SCORE_SIMPLE_OBJECTS_SMOOTHING_FACTOR: float = 0.2 # Higher value = score will change quicker based on recent performance. Value should be between 0 and 1.

#region UI 

const DAY_END_SCREEN_SHOW_TIME_SECONDS: float = 3.0

#endregion

#region Text

const DAY_END_SCREEN_MESSAGE: String = "You have completed day %d."
const GAME_END_SCREEN_MESSAGE: String = "You have completed all days."

#endregion