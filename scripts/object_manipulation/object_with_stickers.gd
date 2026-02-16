# This is the base class for all objects with stickers
# Handles random placement of stickers on object surface
@tool
class_name ObjectWithStickers extends Area3D

signal stickers_placed()

const VALIDATION_RAY_HEIGHT: float = 0.05
const VALIDATION_DISTANCE_TOLERANCE: float = 0.01
const VALIDATION_MAX_ATTEMPTS: int = 50

@export var sticker_count: int = 3
@export var placement_mesh: Mesh # Triangle mesh to sample random surface points from
@export var rng_seed: int = 1 # Set to 0 to ignore seeed and have run-to-run variation
@export var sticker_scene: PackedScene

@export_tool_button("Place Stickers")
var _place_stickers_button := _editor_place_stickers

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	# Deferred so InteractibleObject connects to stickers_placed signal before this runs
	call_deferred("place_stickers")


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

	## Transform placement mesh triangles to world space for ray-triangle validation
	var world_triangles: Array = []
	for tri in triangles:
		world_triangles.append([
			mesh_instance.to_global(tri[0]),
			mesh_instance.to_global(tri[1]),
			mesh_instance.to_global(tri[2])
		])

	## Compute minimum distance between sticker centers from the sticker's scaled AABB
	var temp_sticker: Node3D = sticker_scene.instantiate()
	var temp_mesh_inst: MeshInstance3D = temp_sticker.get_node("MeshInstance3D")
	var sticker_aabb: AABB = temp_mesh_inst.get_aabb()
	var sticker_scale: Vector3 = temp_mesh_inst.transform.basis.get_scale()
	var extent_x: float = sticker_aabb.size.x * sticker_scale.x
	var extent_z: float = sticker_aabb.size.z * sticker_scale.z
	var min_distance: float = sqrt(extent_x * extent_x + extent_z * extent_z)
	temp_sticker.free()

	var placed_positions: Array[Vector3] = []
	var placed_shrink_factors: Array[float] = []

	## Place each sticker with validation
	for _i in range(sticker_count):
		var placed := false
		var shrink_factor: float = 1.0
		for _attempt in range(VALIDATION_MAX_ATTEMPTS):
			# Pick random triangle (area-weighted)
			var tri_index: int = _binary_search(cumulative_areas, rng.randf() * total_area)
			var a: Vector3 = triangles[tri_index][0]
			var b: Vector3 = triangles[tri_index][1]
			var c: Vector3 = triangles[tri_index][2]

			# Random point inside a triangle (barycentric coordinates)
			var r1: float = rng.randf()
			var r2: float = rng.randf()
			var sqrt_r1: float = sqrt(r1)
			var point: Vector3 = (1.0 - sqrt_r1) * a + sqrt_r1 * (1.0 - r2) * b + sqrt_r1 * r2 * c

			# Face normal
			var normal: Vector3 = (b - a).cross(c - a).normalized()

			# Instantiate and orient sticker with random Y rotation, scaled by shrink factor
			var sticker_instance: Node3D = sticker_scene.instantiate()
			var basis := _basis_from_normal(normal)
			basis = basis * Basis(Vector3.UP, rng.randf() * TAU)
			basis = basis.scaled(Vector3.ONE * shrink_factor)
			sticker_instance.transform = Transform3D(basis, point)
			mesh_instance.add_child(sticker_instance)

			# Validate placement via analytical ray-triangle intersection
			if _validate_sticker_position(sticker_instance, world_triangles):
				# Check overlap with already-placed stickers (average of both radii)
				var sticker_center: Vector3 = sticker_instance.transform.origin
				var too_close := false
				for j in range(placed_positions.size()):
					var threshold: float = min_distance * max(shrink_factor, placed_shrink_factors[j])
					if sticker_center.distance_to(placed_positions[j]) < threshold:
						too_close = true
						break
				if too_close:
					sticker_instance.free()
					shrink_factor *= 0.97
					continue

				placed_positions.append(sticker_center)
				placed_shrink_factors.append(shrink_factor)
				placed = true
				break
			else:
				sticker_instance.free()
				shrink_factor *= 0.97
		if not placed:
			push_warning("ObjectWithStickers: Failed to place sticker %d after %d attempts." % [_i, VALIDATION_MAX_ATTEMPTS])

	stickers_placed.emit()



## Editor-only: clears existing stickers then places new ones for preview.
func _editor_place_stickers() -> void:
	var mesh_instance := _find_mesh_instance()
	if mesh_instance == null:
		push_warning("ObjectWithStickers: No MeshInstance3D child found.")
		return
	# Remove previously placed stickers and debug meshes
	for child in mesh_instance.get_children():
		child.queue_free()
	place_stickers()

	# Add debug visualization of the placement mesh
	if placement_mesh != null:
		var debug_mesh_inst := MeshInstance3D.new()
		debug_mesh_inst.name = "DebugPlacementMesh"
		debug_mesh_inst.mesh = placement_mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1, 0, 0, 0.3)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		debug_mesh_inst.material_override = mat
		mesh_instance.add_child(debug_mesh_inst)
		debug_mesh_inst.owner = get_tree().edited_scene_root


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


### Sticker placement validation

## Validates that a sticker sits on a convex surface by casting rays from the 4 AABB
## corners of the sticker mesh against the placement mesh triangles (in world space).
## Returns true if all rays hit and the hit distances are within VALIDATION_DISTANCE_TOLERANCE.
func _validate_sticker_position(sticker_instance: Node3D, world_triangles: Array) -> bool:
	var sticker_mesh_inst: MeshInstance3D = sticker_instance.get_node("MeshInstance3D")
	if sticker_mesh_inst == null or sticker_mesh_inst.mesh == null:
		push_warning("_validate_sticker_position: Sticker has no MeshInstance3D or mesh.")
		return false

	# Probe the 4 AABB corners on the sticker's local XZ plane
	var aabb: AABB = sticker_mesh_inst.get_aabb()
	var min_x: float = aabb.position.x
	var max_x: float = aabb.position.x + aabb.size.x
	var min_z: float = aabb.position.z
	var max_z: float = aabb.position.z + aabb.size.z
	var probe_points: Array[Vector3] = [
		Vector3(min_x, 0.0, min_z),
		Vector3(max_x, 0.0, min_z),
		Vector3(min_x, 0.0, max_z),
		Vector3(max_x, 0.0, max_z),
	]

	# Cast rays from each corner into the placement mesh (analytical, no physics needed)
	var sticker_normal: Vector3 = sticker_instance.global_transform.basis.y.normalized()
	var ray_dir: Vector3 = -sticker_normal
	var hit_distances: Array[float] = []

	for local_point in probe_points:
		var world_point: Vector3 = sticker_mesh_inst.to_global(local_point)
		var ray_origin: Vector3 = world_point + sticker_normal * VALIDATION_RAY_HEIGHT

		# Find closest triangle hit
		var closest_t: float = -1.0
		for tri in world_triangles:
			var t: float = _ray_intersects_triangle(ray_origin, ray_dir, tri[0], tri[1], tri[2])
			if t >= 0.0 and (closest_t < 0.0 or t < closest_t):
				closest_t = t

		if closest_t < 0.0:
			return false # Ray miss, early return

		hit_distances.append(closest_t)

	# All rays hit — check if the surface is flat (distances within tolerance)
	var min_dist: float = hit_distances[0]
	var max_dist: float = hit_distances[0]
	for d in hit_distances:
		min_dist = min(min_dist, d)
		max_dist = max(max_dist, d)
	var spread: float = max_dist - min_dist
	return spread <= VALIDATION_DISTANCE_TOLERANCE

## Moller-Trumbore ray-triangle intersection. Returns distance t along the ray of the intersect, -1.0 if no hit.
static func _ray_intersects_triangle(origin: Vector3, direction: Vector3, v0: Vector3, v1: Vector3, v2: Vector3) -> float:
	var edge1 := v1 - v0
	var edge2 := v2 - v0
	var h := direction.cross(edge2)
	var a := edge1.dot(h)
	if abs(a) < 1e-8:
		return -1.0
	var f := 1.0 / a
	var s := origin - v0
	var u := f * s.dot(h)
	if u < 0.0 or u > 1.0:
		return -1.0
	var q := s.cross(edge1)
	var v := f * direction.dot(q)
	if v < 0.0 or u + v > 1.0:
		return -1.0
	var t := f * edge2.dot(q)
	if t > 0.0:
		return t
	return -1.0
