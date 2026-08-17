## Defines the narrative text that is displayed at the end of a day.
##
## Only meant to exist as a resource part of a [code]DayDefinition[/code], not as a standalone file.
class_name NarrativeTextDefinition
extends Resource

@export var text: String = ""
@export var predicate: VariablePredicate = VariablePredicate.new()
