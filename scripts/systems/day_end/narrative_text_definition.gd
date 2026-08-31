## Defines the narrative text that is displayed at the end of a day.
##
## Only meant to exist as a resource part of a [code]DayDefinition[/code], not as a standalone file.
class_name NarrativeTextDefinition
extends Resource

## Shown if the predicate evaluates to true
@export var text_true: String = ""
## Shown if the predicate evaluates to false. Unused if predicate is always true.
@export var text_false: String = ""
## If left empty, the narrative text is not shown
@export var predicate: VariablePredicate = VariablePredicate.new()
