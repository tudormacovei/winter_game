extends Node

signal scene_loaded
signal scene_unloaded

var is_transitioning: bool = false
@onready var _tree = get_tree()
@onready var _root := _tree.get_root()
@onready var _current_scene = _tree.current_scene

var _previous_scene = null

func _ready() -> void:
    scene_loaded.emit()

func _process(_delta: float) -> void:
    if not is_instance_valid(_previous_scene) and _tree.current_scene:
        _previous_scene = _tree.current_scene
        _current_scene = _tree.current_scene
        scene_loaded.emit()
    if _tree.current_scene != _previous_scene:
        _previous_scene = _tree.current_scene


func change_scene(path: Variant) -> void:
    if path == null:
        _reload_scene()
    else:
        _replace_scene(path)


func _reload_scene() -> void:
    _tree.reload_current_scene()
    await _tree.create_timer(0.0).timeout
    _current_scene = _tree.current_scene

func _replace_scene(path: Variant) -> void:
    if not path:
        push_warning("SceneManager: Invalid scene path provided.")
        return
    _current_scene.queue_free()
    scene_unloaded.emit()
    var following_scene: PackedScene = _load_scene_resource(path)
    _current_scene = following_scene.instantiate()
    await _tree.create_timer(0.0).timeout
    _root.add_child(_current_scene)
    _tree.set_current_scene(_current_scene)


func _load_scene_resource(path: Variant) -> Resource:
    if path is PackedScene:
        return path
    return ResourceLoader.load(path, "PackedScene", 0)

