extends Node

signal warmup_completed

const WARMUP_FRAME_COUNT: int = 30
const WORKBENCH_VIEW_SCENE: PackedScene = preload("res://scenes/main_game_view/workbench_view.tscn")
const STICKER_PEEL_SCENE: PackedScene = preload("res://scenes/sticker_interaction/sticker_peel/sticker_peel.tscn")

var _frame_counter: int = 0

func _ready() -> void:
	var viewport := _create_viewport()
	_populate_scenes(viewport)

func _process(_delta: float) -> void:
	_frame_counter += 1
	if _frame_counter >= WARMUP_FRAME_COUNT:
		warmup_completed.emit()
		queue_free()

func _create_viewport() -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720) # Matches res of the project 
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS # ensures render occurs even if it is not visible
	add_child(viewport)

	var env := Environment.new()
	env.ambient_light_color = Color(1.0, 1.0, 1.0, 1.0)
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	viewport.add_child(world_env)

	# Camera looking toward negative Z at origin
	var camera := Camera3D.new()
	camera.position = Vector3(1.0, 1.0, 2.0) # position from which all objects can be seen
	viewport.add_child(camera)

	var light := DirectionalLight3D.new()
	light.light_energy = 0.5
	viewport.add_child(light)

	return viewport

func _populate_scenes(viewport: SubViewport) -> void:
	var container := Node3D.new()
	viewport.add_child(container)

	var files := Array(ResourceLoader.list_directory(Config.OBJECTS_SCENES_PATH + "/"))
	for f: String in files:
		if not f.ends_with(".tscn"):
			continue
		var scene := load(Config.OBJECTS_SCENES_PATH + "/" + f) as PackedScene
		if scene == null:
			continue
		container.add_child(scene.instantiate())

	container.add_child(WORKBENCH_VIEW_SCENE.instantiate())
	container.add_child(STICKER_PEEL_SCENE.instantiate())
