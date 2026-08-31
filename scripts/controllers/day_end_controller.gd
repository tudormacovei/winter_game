extends Node

@onready var _day_label: Label = %DayCompleteText
@onready var _performance_label := %PerformanceText
@onready var _narrative_label := %NarrativeText

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_performance_label.text = ""
	_narrative_label.text = ""
	
	_performance_label.hide()
	_narrative_label.hide()

func set_text(day_definition) -> void:
	# NOTE: Day end screen acts more like a Day Start screen, so display the next day's number
	_day_label.text = Config.DAY_END_SCREEN_MESSAGE % (day_definition.day_id + 1)
	
	# Show narrative text
	if day_definition.narrative_text != null:
		var is_true = day_definition.narrative_text.predicate.evaluate()
		_narrative_label.text = day_definition.narrative_text.text_true if is_true else day_definition.narrative_text.text_false
	if _narrative_label.text.length() > 0:
		_narrative_label.show()
	else:
		_narrative_label.hide()

	# Show performance text
	if day_definition.performance_text != null:
		_performance_label.text = day_definition.performance_text.get_text_for_score(Variables.get_var(Config.SCORE_SIMPLE_OBJECTS_VAR_KEY))
	if _performance_label.text.length() > 0:
		_performance_label.show()
	else:
		_performance_label.hide()

# TODO: This is meant to be a temporary visual until game end is implemented
func set_game_end_text() -> void:
	_day_label.text = Config.GAME_END_SCREEN_MESSAGE
	
	_performance_label.hide()
	_narrative_label.hide()
