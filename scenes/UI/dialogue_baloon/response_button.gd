## Dialogue response button
## Shows the response using a RichTextLabel instead of the button's text property
extends Button

@onready var label: RichTextLabel = $RichTextLabel

# Assigned by Dialogue Manager when dynamically creating the responses
var response: DialogueResponse:
	set(value):
		response = value
		$RichTextLabel.text = value.text

func _ready() -> void:
	label.minimum_size_changed.connect(_fit)
	_fit()

func _fit() -> void:
	var padding := label.offset_top - label.offset_bottom
	custom_minimum_size.y = label.get_combined_minimum_size().y + padding
