extends Node3D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Variables.state_changed.connect(update_window_view)


func update_window_view(variable_name: String) -> void:
	if variable_name != "prog_window_background_path":
		return

	var path = Variables.get_var("prog_window_background_path")
	var texture := load(path) as Texture2D
	if texture == null:
		push_error("WindowView: Could not load texture at path: " + path)
		return

	var mat := $DialogueWindowView.material_override as StandardMaterial3D
	if mat == null:
		push_error("WindowView: material_override is null or not a StandardMaterial3D")
		return

	mat.albedo_texture = texture
	mat.emission_enabled = true
	mat.emission_texture = texture
