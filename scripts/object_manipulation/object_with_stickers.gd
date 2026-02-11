# This is the base class for all objects with stickers
# Handles random placement of stickers on object surface
@tool # @tool for debug purposes
class_name ObjectWithStickers extends Area3D

@export var sticker_count: int = 3
@export var placement_mesh: Mesh # Triangle mesh to sample random surface points from
@export var rng_seed: int = 1 # Set to 0 to ignore seeed and have run-to-run variation
@export var sticker_scene: PackedScene

@export_tool_button("Place Stickers")
var place_stickers_button := place_stickers

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	place_stickers()


### Sticker placement

## Places sticker_count new stickers at random positions on the placement_mesh surface, oriented along face normals.
func place_stickers() -> void:
	if placement_mesh == null:
		push_warning("ObjectWithStickers: placement_mesh is not set.")
		return
	if sticker_scene == null:
		push_warning("ObjectWithStickers: sticker_scene is not set.")
		return
	if sticker_count <= 0:
		push_warning("ObjectWithStickers: No stickers to place on object spawn! sicker_count must be positive, got: " + str(sticker_count))
		return

	var mesh_instance := _find_mesh_instance()
	if mesh_instance == null:
		push_warning("ObjectWithStickers: No MeshInstance3D child found.")
		return

	## Extract triangles from the first surface (material slot) - we assume the given mesh only has one
	var arrays := placement_mesh.surface_get_arrays(0)
	if arrays == null or arrays.is_empty():
		push_warning("ObjectWithStickers: placement_mesh has no surface data.")
		return

	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices = arrays[Mesh.ARRAY_INDEX]

	var triangles: Array = []
	if indices != null and indices.size() > 0:
		for i in range(0, indices.size(), 3):
			triangles.append([vertices[indices[i]], vertices[indices[i + 1]], vertices[indices[i + 2]]])
	else:
		for i in range(0, vertices.size(), 3):
			triangles.append([vertices[i], vertices[i + 1], vertices[i + 2]])

	if triangles.is_empty():
		push_warning("ObjectWithStickers: No triangles found in placement_mesh.")
		return

	## Build area-weighted cumulative distribution
	var cumulative_areas: Array[float] = []
	var total_area: float = 0.0
	for tri in triangles:
		var area: float = (tri[1] - tri[0]).cross(tri[2] - tri[0]).length() * 0.5
		total_area += area
		cumulative_areas.append(total_area)

	if total_area <= 0.0:
		push_warning("ObjectWithStickers: Mesh has zero total surface area.")
		return

	## Initialize RNG as true random if seed set to 0
	var rng := RandomNumberGenerator.new()
	if rng_seed != 0:
		rng.seed = rng_seed
	else:
		rng.randomize()

	## Place each sticker
	for _i in range(sticker_count):
		# Pick random triangle (area-weighted)
		var tri_index: int = _binary_search(cumulative_areas, rng.randf() * total_area)
		var a: Vector3 = triangles[tri_index][0]
		var b: Vector3 = triangles[tri_index][1]
		var c: Vector3 = triangles[tri_index][2]

		# Random point on triangle (barycentric)
		var r1: float = rng.randf()
		var r2: float = rng.randf()
		var sqrt_r1: float = sqrt(r1)
		var point: Vector3 = (1.0 - sqrt_r1) * a + sqrt_r1 * (1.0 - r2) * b + sqrt_r1 * r2 * c

		# Face normal
		var normal: Vector3 = (b - a).cross(c - a).normalized()

		# Instantiate and orient sticker
		var sticker_instance: Node3D = sticker_scene.instantiate()
		sticker_instance.transform = Transform3D(_basis_from_normal(normal), point)
		mesh_instance.add_child(sticker_instance)

		# Set owner for editor scene tree visibility (for debug)
		if Engine.is_editor_hint():
			sticker_instance.set_owner(get_tree().edited_scene_root)


### Helpers

## Returns the first MeshInstance3D child, or null if none exists.
func _find_mesh_instance() -> MeshInstance3D:
	for child in get_children():
		if child is MeshInstance3D:
			return child
	return null

## Returns the index of the first element in arr that is >= x.
func _binary_search(arr: Array[float], x: float) -> int:
	var low: int = 0
	var high: int = arr.size() - 1
	while low < high:
		@warning_ignore("integer_division")
		var mid: int = (low + high) / 2
		if arr[mid] < x:
			low = mid + 1
		else:
			high = mid
	return low

## Returns an orientation Basis where local Y aligns with the given normal.
func _basis_from_normal(normal: Vector3) -> Basis:
	var up := normal
	var arbitrary := Vector3.RIGHT if abs(normal.dot(Vector3.RIGHT)) < 0.99 else Vector3.FORWARD
	var tangent := up.cross(arbitrary).normalized()
	var bitangent := tangent.cross(up).normalized()
	return Basis(tangent, up, bitangent)