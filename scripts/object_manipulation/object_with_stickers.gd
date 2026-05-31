# This is the base class for all objects with stickers
# Handles random placement of stickers on object surface
@tool
class_name ObjectWithStickers extends Area3D

signal stickers_placed()

const VALIDATION_RAY_HEIGHT: float = 0.05
const VALIDATION_DISTANCE_TOLERANCE: float = 0.01
const VALIDATION_MAX_ATTEMPTS: int = 50
const DEBUG_PLACEMENT_MESH_NAME := &"DebugPlacementMesh"

@export var is_special_object: bool = false
@export var max_sticker_count: int = 3 # this is the ceiling; actual count = round(max * difficulty_fraction)
@export var placement_mesh: Mesh # Triangle mesh to sample random surface points from
@export var rng_seed: int = 1 # Set to 0 to ignore seeed and have run-to-run variation
@export var preview_difficulty: int = 5 # !!! editor-only: defines difficulty used by the Place Stickers tool button

# Skip runtime initialization of stickers: needed when spawning the object during shader warmup 
var skip_runtime_init: bool = false

@warning_ignore("unused_private_class_variable")
@export_tool_button("Place Stickers")
var _place_stickers_button := _editor_place_stickers

@warning_ignore("unused_private_class_variable")
@export_tool_button("Clear Stickers")
var _clear_stickers_button := _editor_clear_stickers

@warning_ignore("unused_private_class_variable")
@export_tool_button("Spawn Placement Debug Mesh")
var _spawn_debug_button := _editor_spawn_debug_mesh

@warning_ignore("unused_private_class_variable")
@export_tool_button("Clear Placement Debug Mesh")
var _clear_debug_button := _editor_clear_debug_mesh

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if skip_runtime_init:
		return # non-gameplay context (e.g. shader warmup)
	
	# because object owner is set by InteractibleObject after our _ready returns, %GameManager can't resolve yet.
	# we defer the function call to ensure it runs after the owner is in place
	call_deferred("_place_stickers_runtime")


func _place_stickers_runtime() -> void:
	var gm: GameManager = %GameManager as GameManager
	if gm == null:
		push_warning("ObjectWithStickers: GameManager not found; skipping sticker placement.")
		stickers_placed.emit()
		return
	place_stickers(gm.current_difficulty)


## Places stickers at random positions on the placement_mesh surface, oriented along face normals.
## Count = round(max_sticker_count * fraction), sticker type is uniformly sampled from the eligible list
func place_stickers(difficulty: int) -> void:
	if is_special_object:
		stickers_placed.emit() # Still emit signal so InteractibleObject can proceed with setup
		return

	if placement_mesh == null:
		push_warning("ObjectWithStickers: placement_mesh is not set.")
		return
	if max_sticker_count <= 0:
		push_warning("ObjectWithStickers: max_sticker_count must be positive, got: " + str(max_sticker_count))
		return

	var cfg := GameManager.get_sticker_spawn_config(difficulty)
	var sticker_types: Array = cfg["types"]
	if sticker_types.is_empty():
		push_warning("ObjectWithStickers: No eligible sticker types for difficulty %d." % difficulty)
		return
	var actual_count: int = roundi(max_sticker_count * (cfg["fraction"] as float))
	if actual_count <= 0:
		stickers_placed.emit()
		return

	var mesh_instance := _find_mesh_instance()
	if mesh_instance == null:
		push_warning("ObjectWithStickers: No MeshInstance3D child found.")
		return

	# Extract triangles from the first surface (material slot) - we assume the given mesh only has one
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

	# Build area-weighted cumulative distribution
	var cumulative_areas: Array[float] = []
	var total_area: float = 0.0
	for tri in triangles:
		var area: float = (tri[1] - tri[0]).cross(tri[2] - tri[0]).length() * 0.5
		total_area += area
		cumulative_areas.append(total_area)

	if total_area <= 0.0:
		push_warning("ObjectWithStickers: Mesh has zero total surface area.")
		return

	# Initialize RNG as true random if seed set to 0
	var rng := RandomNumberGenerator.new()
	if rng_seed != 0:
		rng.seed = rng_seed
	else:
		rng.randomize()

	# Transform placement mesh triangles to world space for ray-triangle validation
	var world_triangles: Array = []
	for tri in triangles:
		world_triangles.append([
			mesh_instance.to_global(tri[0]),
			mesh_instance.to_global(tri[1]),
			mesh_instance.to_global(tri[2])
		])

	# Read mesh AABB and local transform from a temp sticker once. All eligible sticker scenes
	# share the same mesh (important!), so these values apply to every candidate.
	var temp_sticker: Node3D = (sticker_types[0] as PackedScene).instantiate()
	var temp_mesh_inst: MeshInstance3D = temp_sticker.get_node("MeshInstance3D")
	var mesh_aabb: AABB = temp_mesh_inst.get_aabb()
	var mesh_local_transform: Transform3D = temp_mesh_inst.transform
	var sticker_scale: Vector3 = mesh_local_transform.basis.get_scale()
	var extent_x: float = mesh_aabb.size.x * sticker_scale.x
	var extent_z: float = mesh_aabb.size.z * sticker_scale.z
	var min_distance: float = sqrt(extent_x * extent_x + extent_z * extent_z)
	temp_sticker.free()

	var placed_positions: Array[Vector3] = []
	var placed_shrink_factors: Array[float] = []

	# pure math fit check first: object instantiation only happen for the candidate that passes both surface and overlap checks.
	for _i in range(actual_count):
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

			# Build the candidate transform (Area3D-local relative to mesh_instance) and the
			# world transform of the would-be MeshInstance3D, used for ray-cast validation.
			var sticker_basis := _basis_from_normal(normal)
			sticker_basis = sticker_basis * Basis(Vector3.UP, rng.randf() * TAU)
			sticker_basis = sticker_basis.scaled(Vector3.ONE * shrink_factor)
			var candidate_local_transform := Transform3D(sticker_basis, point)
			var mesh_world_transform := mesh_instance.global_transform * candidate_local_transform * mesh_local_transform

			# Surface validation: ray-cast the 4 AABB corners against the placement mesh.
			if not _validate_sticker_position(mesh_world_transform, mesh_aabb, world_triangles):
				shrink_factor *= 0.97
				continue

			# Overlap with previously-placed stickers
			var too_close := false
			for j in range(placed_positions.size()):
				var threshold: float = min_distance * max(shrink_factor, placed_shrink_factors[j])
				if point.distance_to(placed_positions[j]) < threshold:
					too_close = true
					break
			if too_close:
				shrink_factor *= 0.97
				continue

			# Both checks passed — instantiate the chosen sticker type and add for real.
			var sticker_scene_pick: PackedScene = sticker_types[rng.randi() % sticker_types.size()] as PackedScene
			var sticker_instance: Node3D = sticker_scene_pick.instantiate()
			sticker_instance.transform = candidate_local_transform
			mesh_instance.add_child(sticker_instance)

			placed_positions.append(point)
			placed_shrink_factors.append(shrink_factor)
			placed = true
			break
		if not placed:
			push_warning("ObjectWithStickers: Failed to place sticker %d after %d attempts." % [_i, VALIDATION_MAX_ATTEMPTS])

	stickers_placed.emit()

## Editor-only: removes auto-placed stickers (children of the MeshInstance3D that are not
## the placement debug mesh). Use this before saving the scene.
func _editor_clear_stickers() -> void:
	var mesh_instance := _find_mesh_instance()
	if mesh_instance == null:
		push_warning("ObjectWithStickers: No MeshInstance3D child found.")
		return
	for child in mesh_instance.get_children():
		if child.name == DEBUG_PLACEMENT_MESH_NAME:
			continue
		child.queue_free()
	update_configuration_warnings()


## Editor-only: clears existing stickers then places new ones for preview.
func _editor_place_stickers() -> void:
	_editor_clear_stickers()
	place_stickers(preview_difficulty)
	update_configuration_warnings()


## Editor-only: spawns a red translucent overlay of the placement_mesh for verification of the sampling surface.
## Idempotent: clears any existing debug mesh first.
func _editor_spawn_debug_mesh() -> void:
	var mesh_instance := _find_mesh_instance()
	if mesh_instance == null:
		push_warning("ObjectWithStickers: No MeshInstance3D child found.")
		return
	if placement_mesh == null:
		push_warning("ObjectWithStickers: placement_mesh is not set; nothing to visualize.")
		return
	_editor_clear_debug_mesh()
	var debug_mesh_inst := MeshInstance3D.new()
	debug_mesh_inst.name = DEBUG_PLACEMENT_MESH_NAME
	debug_mesh_inst.mesh = placement_mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1, 0, 0, 0.3)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	debug_mesh_inst.material_override = mat
	mesh_instance.add_child(debug_mesh_inst)
	debug_mesh_inst.owner = get_tree().edited_scene_root
	update_configuration_warnings()


## Editor-only: removes the placement debug mesh if present. Use this before saving the scene.
func _editor_clear_debug_mesh() -> void:
	var mesh_instance := _find_mesh_instance()
	if mesh_instance == null:
		return
	var debug := mesh_instance.get_node_or_null(NodePath(DEBUG_PLACEMENT_MESH_NAME))
	if debug != null:
		debug.queue_free()
	update_configuration_warnings()


## Warnings shown as a yellow triangle in the scene dock.
func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if _has_auto_placed_stickers():
		warnings.append("Auto-placed stickers present — clear before saving (Clear Stickers button).")
	if _has_debug_placement_mesh():
		warnings.append("Placement debug mesh present — clear before saving (Clear Placement Debug Mesh button).")
	return warnings


func _has_auto_placed_stickers() -> bool:
	var mi := _find_mesh_instance()
	if mi == null:
		return false
	for child in mi.get_children():
		if child.name != DEBUG_PLACEMENT_MESH_NAME:
			return true
	return false


func _has_debug_placement_mesh() -> bool:
	var mi := _find_mesh_instance()
	return mi != null and mi.has_node(NodePath(DEBUG_PLACEMENT_MESH_NAME))


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

## Validates that a sticker would sit on a convex surface, given the world transform of
## its would-be MeshInstance3D and the mesh AABB. Casts rays from the 4 XZ-plane AABB corners
## down along the surface normal against the placement mesh triangles (in world space).
## Pure math — no scene tree interaction, so candidates can be tested before instantiation.
func _validate_sticker_position(mesh_world_transform: Transform3D, mesh_aabb: AABB, world_triangles: Array) -> bool:
	# Probe the 4 AABB corners on the sticker's local XZ plane
	var min_x: float = mesh_aabb.position.x
	var max_x: float = mesh_aabb.position.x + mesh_aabb.size.x
	var min_z: float = mesh_aabb.position.z
	var max_z: float = mesh_aabb.position.z + mesh_aabb.size.z
	var probe_points: Array[Vector3] = [
		Vector3(min_x, 0.0, min_z),
		Vector3(max_x, 0.0, min_z),
		Vector3(min_x, 0.0, max_z),
		Vector3(max_x, 0.0, max_z),
	]

	# Cast rays from each corner into the placement mesh (analytical, no physics needed)
	var sticker_normal: Vector3 = mesh_world_transform.basis.y.normalized()
	var ray_dir: Vector3 = - sticker_normal
	var hit_distances: Array[float] = []

	for local_point in probe_points:
		var world_point: Vector3 = mesh_world_transform * local_point
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
