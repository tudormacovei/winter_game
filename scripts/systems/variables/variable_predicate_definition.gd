## Allows for defining a comparison predicate that can be evaluated at runtime.
## Is always true by default.
## 
## Only meant to exist as part of other resources, not as a standalone file.
@tool
class_name VariablePredicate
extends Resource

enum Operator {GREATER, LESS, EQUAL, GREATER_EQUAL, LESS_EQUAL, NOT_EQUAL}
enum MethodName {GET_VAR, GET_CHAR_VAR}

## Will the predicate always evaluate to true? If so, the other properties are irrelevant and ignored.
@export var is_always_true: bool = true:
	set(value):
		is_always_true = value
		notify_property_list_changed()

@export var method: MethodName = MethodName.GET_VAR
@export var method_arguments: Array = []
@export var operator: Operator = Operator.GREATER
@export var compare_value: float = 0.0

func evaluate() -> bool:
	if is_always_true:
		return true
		
	var method_name = _get_method(method)
	var variable = Variables.callv(method_name, method_arguments)
	match operator:
		Operator.GREATER: return variable > compare_value
		Operator.LESS: return variable < compare_value
		Operator.EQUAL: return variable == compare_value
		Operator.GREATER_EQUAL: return variable >= compare_value
		Operator.LESS_EQUAL: return variable <= compare_value
		Operator.NOT_EQUAL: return variable != compare_value

	return false

# Grey out properties in the Inspector if the predicate is always true
func _validate_property(property: Dictionary) -> void:
	if is_always_true and property.name in ["method", "method_arguments", "operator", "compare_value"]:
		property.usage |= PROPERTY_USAGE_READ_ONLY

func _get_method(method_name: MethodName) -> String:
	match method_name:
		MethodName.GET_VAR: return "get_var"
		MethodName.GET_CHAR_VAR: return "get_char_var"
	return ""
