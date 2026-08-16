extends Node

@onready var _day_label: Label = %DayCompleteText
@onready var _performance_label := %PerformanceText
@onready var _narrative_label := %NarrativeText

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_performance_label.hide()
	_narrative_label.hide()

func set_text(day_number: int) -> void:
	_day_label.text = Config.DAY_END_SCREEN_MESSAGE % day_number
	
	# TODO[ziana]: Implement performance and narrative text

# TODO: This is meant to be a temporary visual until game end is implemented
func set_game_end_text() -> void:
	_day_label.text = Config.GAME_END_SCREEN_MESSAGE
	
	_performance_label.hide()
	_narrative_label.hide()
