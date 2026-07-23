@tool
class_name BranchRing extends Node2D

@export var branch_texture: Texture2D: set = _set_branch_texture
@export var start_radius: float = 450.0: set = _set_start_radius # Radius of the 16:9 oval where branches sit when fully hidden = at FULL HP
@export var end_radius: float = 200.0: set = _set_end_radius # Radius of the oval when fully revealed = at LOW HP
@export var branch_count: int = 12: set = _set_branch_count
@export var branch_scale: float = 0.15: set = _set_branch_scale
@export var health_window: Vector2 = Vector2(0.95, 0.05): set = _set_health_window

# Pixels of ring shift per pixel of mouse offset from screen center.
@export var parallax_strength: float = 0.0

# Editor-only preview knob. At runtime, HealthManager drives set_health_normalized() directly.
@export_range(0.0, 1.0, 0.01) var preview_health: float = 1.0: set = _set_preview_health

const PARALLAX_SMOOTHING_RATE: float = 8.0

var _branches: Array[Sprite2D] = []
var _start_positions: Array[Vector2] = []
var _end_positions: Array[Vector2] = []


func _ready() -> void:
	_rebuild_branches()
	set_health_normalized(preview_health)


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or parallax_strength == 0.0:
		return
	var mouse_offset := get_viewport().get_mouse_position() - get_viewport_rect().size / 2.0
	var target_offset := mouse_offset * parallax_strength
	position = position.lerp(target_offset, 1.0 - exp(-PARALLAX_SMOOTHING_RATE * delta))


func _rebuild_branches() -> void:
	for c in _branches:
		c.queue_free()
	_branches.clear()
	_start_positions.clear()
	_end_positions.clear()

	if branch_texture == null or branch_count <= 0:
		return

	var aspect: float = 16.0 / 9.0
	for i in branch_count:
		var angle: float = TAU * i / branch_count
		var start_pos := Vector2(cos(angle) * start_radius * aspect, sin(angle) * start_radius)
		var end_pos := Vector2(cos(angle) * end_radius * aspect, sin(angle) * end_radius)

		var sprite := Sprite2D.new()
		sprite.texture = branch_texture
		sprite.scale = Vector2.ONE * branch_scale

		# Anchor by the tip of the branch
		sprite.offset = Vector2(0, branch_texture.get_height() / 2.0)

		# Rotate so texture-up (-Y) points toward screen center (0,0).
		sprite.rotation = (-end_pos).angle() + PI / 2.0
		sprite.position = start_pos

		# Intentionally do NOT set owner!
		# By not setting owner sprite notes will not get saved into the .tscn file (since they are spawned in-editor for preview)
		add_child(sprite)

		_branches.append(sprite)
		_start_positions.append(start_pos)
		_end_positions.append(end_pos)


func set_health_normalized(h: float) -> void:
	var t: float = clampf(inverse_lerp(health_window.x, health_window.y, h), 0.0, 1.0)
	for i in _branches.size():
		_branches[i].position = _start_positions[i].lerp(_end_positions[i], t)

# The setters below are overriden to ensure the overlay gets rebuilt & visualized in-editor

func _set_branch_texture(v: Texture2D) -> void:
	branch_texture = v
	if is_inside_tree():
		_rebuild_branches()
		set_health_normalized(preview_health)

func _set_start_radius(v: float) -> void:
	start_radius = v
	if is_inside_tree():
		_rebuild_branches()
		set_health_normalized(preview_health)

func _set_end_radius(v: float) -> void:
	end_radius = v
	if is_inside_tree():
		_rebuild_branches()
		set_health_normalized(preview_health)

func _set_branch_count(v: int) -> void:
	branch_count = v
	if is_inside_tree():
		_rebuild_branches()
		set_health_normalized(preview_health)

func _set_branch_scale(v: float) -> void:
	branch_scale = v
	if is_inside_tree():
		_rebuild_branches()
		set_health_normalized(preview_health)

func _set_health_window(v: Vector2) -> void:
	health_window = v
	if is_inside_tree():
		set_health_normalized(preview_health)

func _set_preview_health(v: float) -> void:
	preview_health = v
	if is_inside_tree():
		set_health_normalized(preview_health)
