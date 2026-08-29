## Defines the performance text that is displayed at the end of a day.
##
## Only meant to exist as a resource part of a [code]DayDefinition[/code], not as a standalone file.
class_name PerformanceTextDefinition
extends Resource

const PerformanceTextPoolResource := preload("res://scripts/systems/day_end/performance_text_pool.gd")

@export var pools: Array[PerformanceTextPoolResource] = []

## Returns empty string if no pool matches or is configured
func get_text_for_score(score: int) -> String:
	if pools.is_empty():
		return ""

	for i in len(pools):
		var pool = pools[i]
		if pool == null:
			continue
		if pool.min_value <= score and score <= pool.max_value:
			if pool.texts.is_empty():
				return ""

			var text = pool.texts[randi() % pool.texts.size()]
			print("PerformanceTextDefinition:get_text_for_score - score %s, pool index %s" % [score, i])
			return text

	return ""
