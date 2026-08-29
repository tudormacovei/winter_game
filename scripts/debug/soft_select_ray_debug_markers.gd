## Debug only: show one sphere per soft select ray, scaled to look like 2D circular markers from the camera POV (but they are 3D objects)
## Red: the ray missed. Blue: the ray hit the object. Green: the ray hit a selectable sticker.
## Owned by an InteractibleObject. Does nothing while the DebugUI checkbox is off.
class_name SoftSelectRayDebugMarkers extends Node3D

enum Result { MISS, OBJECT, STICKER }

const MARKER_SCREEN_FRACTION: float = 0.002 # marker radius as a fraction of the viewport width

var _materials: Dictionary = {
	Result.MISS: _create_material(Color.RED),
	Result.OBJECT: _create_material(Color.BLUE),
	Result.STICKER: _create_material(Color.GREEN),
}
var _sphere_mesh := SphereMesh.new()
var _markers: Array[MeshInstance3D] = [] # one per ray
var _used_marker_count := 0


func _ready() -> void:
	top_level = true # markers use world positions, independent of the owning object transform
	_sphere_mesh.radius = 1.0
	_sphere_mesh.height = 2.0
	_sphere_mesh.radial_segments = 8
	_sphere_mesh.rings = 4


## Hides all markers. Call before a new fan of rays.
func clear_markers() -> void:
	for marker in _markers:
		marker.visible = false
	_used_marker_count = 0


## Shows one marker at world_position, scaled so that it appears MARKER_SCREEN_FRACTION wide on screen.
func add_marker(camera: Camera3D, screen_position: Vector2, world_position: Vector3, result: Result) -> void:
	if not DebugUI.general_tab_show_soft_select_rays[0]:
		return
	if _used_marker_count == _markers.size():
		_markers.append(_create_marker())
	var marker := _markers[_used_marker_count]
	_used_marker_count += 1

	marker.visible = true
	marker.global_position = world_position
	marker.material_override = _materials[result]
	marker.scale = Vector3.ONE * _world_radius(camera, screen_position, world_position)


func _world_radius(camera: Camera3D, screen_position: Vector2, world_position: Vector3) -> float:
	var depth := (world_position - camera.global_position).dot(-camera.global_basis.z)
	var marker_radius_px := get_viewport().get_visible_rect().size.x * MARKER_SCREEN_FRACTION
	var center := camera.project_position(screen_position, depth)
	var edge := camera.project_position(screen_position + Vector2(marker_radius_px, 0.0), depth)
	return center.distance_to(edge)


func _create_marker() -> MeshInstance3D:
	var marker := MeshInstance3D.new()
	marker.mesh = _sphere_mesh
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(marker)
	return marker


static func _create_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.no_depth_test = true # always on top
	material.render_priority = 127
	return material
