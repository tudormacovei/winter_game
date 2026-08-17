extends Node

@onready var _day_label: Label = %DayCompleteText
@onready var _performance_label := %PerformanceText
@onready var _narrative_label := %NarrativeText

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_performance_label.hide()
	_narrative_label.hide()

func set_text(day_definition) -> void:
	# NOTE: Day end screen acts more like a Day Start screen, so display the next day's number
	_day_label.text = Config.DAY_END_SCREEN_MESSAGE % (day_definition.day_id + 1)
	
	# Show narrative text if the predicate evaluates to true
	var should_show_narrative = day_definition.narrative_text != null and day_definition.narrative_text.predicate.evaluate()
	if should_show_narrative:
		_narrative_label.text = day_definition.narrative_text.text
		_narrative_label.show()
	else:
		_narrative_label.hide()

	# TODO[ziana]: Implement performance text

# TODO: This is meant to be a temporary visual until game end is implemented
func set_game_end_text() -> void:
	_day_label.text = Config.GAME_END_SCREEN_MESSAGE
	
	_performance_label.hide()
	_narrative_label.hide()
