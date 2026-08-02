# This is the base class for all objects with stickers
# Handles random placement of stickers on object surface
@tool
class_name ObjectWithStickers extends Area3D

signal stickers_placed()

const VALIDATION_DISTANCE_TOLERANCE: float = 1e-6
const VALIDATION_MAX_ATTEMPTS: int = 50
const STICKER_SHRINK_MULTIPLIER: float = 0.97
const PROBE_GRID_N: int = 10 # NxN probe grid over the sticker footprint (must be >= 2!)
const NORMAL_CONSISTENCY_MIN_DOT: float = 0.99 # reject sticker placement if probed normals diverge too much
const DEBUG_PLACEMENT_MESH_NAME: String = "DebugPlacementMesh"
const DEBUG_SAMPLE_NORMALS_NAME: String = "DebugSampleNormals"
const DEBUG_FACE_NORMALS_NAME: String = "DebugPlacementFaceNormals"

@export var is_special_object: bool = false
@export var max_sticker_count: int = 3 # actual count = round(max * difficulty_fraction)
@export var placement_mesh: Mesh # Triangle mesh to sample random surface points from
@export var sticker_placement_offset: float = 0.0 # how far stickers stick out from the surface (0 = flush)
@export var sticker_start_scale: float = 1.0 # scale applied to every new sticker on this object
@export_range(0.01, 1.0, 0.01) var sticker_min_scale_fraction: float = 0.5 # lowest allowed scale relative to sticker_start_scale
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
@export_tool_button("Clear Placement Debug Visuals")
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

	var stickers_to_spawn_count: int = roundi(max_sticker_count * (cfg["fraction"] as float))
	if stickers_to_spawn_count <= 0:
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

	# Probe rays start outside the sampled face, the first hit is the candidate placement surface
	# Use world-space AABB diagonal so the of the probe ray clears any geometry
	var probe_ray_height: float = (mesh_instance.global_transform * placement_mesh.get_aabb()).size.length()

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
	var sticker_min_scale: float = sticker_start_scale * sticker_min_scale_fraction

	# just a fit check first: object instantiation only happens for the candidate that passes both surface and overlap checks
	for _i in range(stickers_to_spawn_count):
		var placed := false
		var shrink_factor: float = sticker_start_scale
		for _attempt in range(VALIDATION_MAX_ATTEMPTS):
			# Pick a random triangle (area-weighted)
			var tri_index: int = _binary_search(cumulative_areas, rng.randf() * total_area)
			var a: Vector3 = triangles[tri_index][0]
			var b: Vector3 = triangles[tri_index][1]
			var c: Vector3 = triangles[tri_index][2]

			# Random point inside a triangle
			var r1: float = rng.randf()
			var r2: float = rng.randf()
			var sqrt_r1: float = sqrt(r1)
			var point: Vector3 = (1.0 - sqrt_r1) * a + sqrt_r1 * (1.0 - r2) * b + sqrt_r1 * r2 * c

			# Godot front faces use clockwise winding, so negate the cross product to get the outward normal.
			var outward_normal: Vector3 = -(b - a).cross(c - a).normalized()

			# Build the candidate transform (Area3D-local relative to mesh_instance) and the
			# world transform of the would-be MeshInstance3D, used for ray-cast validation.
			var sticker_basis := _basis_from_normal(outward_normal)
			sticker_basis = sticker_basis * Basis(Vector3.UP, rng.randf() * TAU)
			sticker_basis = sticker_basis.scaled(Vector3.ONE * shrink_factor)
			var candidate_local_transform := Transform3D(sticker_basis, point)
			var mesh_world_transform := mesh_instance.global_transform * candidate_local_transform * mesh_local_transform
			var sample_points: Array[Vector3] = [] # stored for debugging
			var sample_normals: Array[Vector3] = [] # stored for debugging

			# Surface validation: probe the footprint against the placement mesh.
			if not _validate_sticker_position(mesh_world_transform, mesh_aabb, world_triangles, probe_ray_height, sample_points, sample_normals):
				shrink_factor = maxf(shrink_factor * STICKER_SHRINK_MULTIPLIER, sticker_min_scale)
				continue

			# Overlap with previously-placed stickers
			var too_close := false
			for j in range(placed_positions.size()):
				var threshold: float = min_distance * max(shrink_factor, placed_shrink_factors[j])
				if point.distance_to(placed_positions[j]) < threshold:
					too_close = true
					break
			if too_close:
				shrink_factor = maxf(shrink_factor * STICKER_SHRINK_MULTIPLIER, sticker_min_scale)
				continue

			# Instantiate the chosen sticker type with an offset from the face to ensure no Z-fighting
			var placed_local_transform := Transform3D(sticker_basis, point + outward_normal * sticker_placement_offset)
			var sticker_scene_pick: PackedScene = sticker_types[rng.randi() % sticker_types.size()] as PackedScene
			var sticker_instance: Node3D = sticker_scene_pick.instantiate()
			sticker_instance.transform = placed_local_transform
			mesh_instance.add_child(sticker_instance)
			if Engine.is_editor_hint():
				var arrow_length: float = maxf(extent_x, extent_z) * shrink_factor * 0.25
				_spawn_sample_normal_arrows(mesh_instance, sample_points, sample_normals, arrow_length)

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
		if child.name == DEBUG_PLACEMENT_MESH_NAME or child.name == DEBUG_SAMPLE_NORMALS_NAME or child.name == DEBUG_FACE_NORMALS_NAME:
			continue
		child.queue_free()
	update_configuration_warnings()


## Editor-only: clears existing stickers then places new ones for preview.
func _editor_place_stickers() -> void:
	_editor_clear_stickers()
	_editor_clear_sample_normal_arrows()
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

	var arrays := placement_mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var face_points: Array[Vector3] = []
	var face_normals: Array[Vector3] = []
	if indices.is_empty():
		for index in range(0, vertices.size(), 3):
			_add_face_normal(vertices[index], vertices[index + 1], vertices[index + 2], mesh_instance, face_points, face_normals)
	else:
		for index in range(0, indices.size(), 3):
			_add_face_normal(vertices[indices[index]], vertices[indices[index + 1]], vertices[indices[index + 2]], mesh_instance, face_points, face_normals)
	var arrow_length: float = (mesh_instance.global_transform * placement_mesh.get_aabb()).size.length() * 0.1
	_spawn_normal_arrows(mesh_instance, DEBUG_FACE_NORMALS_NAME, face_points, face_normals, arrow_length, Color(0.7, 0.2, 1.0))
	update_configuration_warnings()


## Editor-only: removes the placement debug mesh if present. Use this before saving the scene.
func _editor_clear_debug_mesh() -> void:
	var mesh_instance := _find_mesh_instance()
	if mesh_instance == null:
		return
	var debug := mesh_instance.get_node_or_null(NodePath(DEBUG_PLACEMENT_MESH_NAME))
	if debug != null:
		debug.queue_free()
	_editor_clear_normal_arrows(DEBUG_SAMPLE_NORMALS_NAME)
	_editor_clear_normal_arrows(DEBUG_FACE_NORMALS_NAME)
	update_configuration_warnings()


func _editor_clear_sample_normal_arrows() -> void:
	_editor_clear_normal_arrows(DEBUG_SAMPLE_NORMALS_NAME)


func _editor_clear_normal_arrows(debug_name: String) -> void:
	var mesh_instance := _find_mesh_instance()
	if mesh_instance == null:
		return
	var arrows := mesh_instance.get_node_or_null(NodePath(debug_name))
	if arrows != null:
		arrows.free()


func _spawn_sample_normal_arrows(mesh_instance: MeshInstance3D, sample_points: Array[Vector3], sample_normals: Array[Vector3], arrow_length: float) -> void:
	_spawn_normal_arrows(mesh_instance, DEBUG_SAMPLE_NORMALS_NAME, sample_points, sample_normals, arrow_length, Color(0.1, 0.9, 1.0))


func _spawn_normal_arrows(mesh_instance: MeshInstance3D, debug_name: String, sample_points: Array[Vector3], sample_normals: Array[Vector3], arrow_length: float, color: Color) -> void:
	var arrow_instance := mesh_instance.get_node_or_null(NodePath(debug_name)) as MeshInstance3D
	if arrow_instance == null:
		arrow_instance = MeshInstance3D.new()
		arrow_instance.name = debug_name
		mesh_instance.add_child(arrow_instance)
		arrow_instance.owner = get_tree().edited_scene_root
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = color
		arrow_instance.material_override = material
		arrow_instance.mesh = ImmediateMesh.new()

	# Build line shafts and cone heads for the sampled surface normals.
	var arrow_mesh := arrow_instance.mesh as ImmediateMesh
	var cone_height: float = arrow_length * 0.3
	var cone_mesh := CylinderMesh.new()
	cone_mesh.top_radius = 0.0
	cone_mesh.bottom_radius = arrow_length * 0.1
	cone_mesh.height = cone_height
	cone_mesh.radial_segments = 8
	arrow_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for index in range(sample_points.size()):
		var start: Vector3 = mesh_instance.to_local(sample_points[index])
		var direction: Vector3 = (mesh_instance.global_transform.basis.inverse() * sample_normals[index]).normalized()
		var end: Vector3 = start + direction * arrow_length

		arrow_mesh.surface_add_vertex(start)
		arrow_mesh.surface_add_vertex(end)

		var cone_instance := MeshInstance3D.new()
		cone_instance.mesh = cone_mesh
		cone_instance.material_override = arrow_instance.material_override
		cone_instance.transform = Transform3D(_basis_from_normal(direction), end - direction * cone_height * 0.5)
		arrow_instance.add_child(cone_instance)
		cone_instance.owner = get_tree().edited_scene_root
	arrow_mesh.surface_end()


func _add_face_normal(a: Vector3, b: Vector3, c: Vector3, mesh_instance: MeshInstance3D, face_points: Array[Vector3], face_normals: Array[Vector3]) -> void:
	var world_a: Vector3 = mesh_instance.to_global(a)
	var world_b: Vector3 = mesh_instance.to_global(b)
	var world_c: Vector3 = mesh_instance.to_global(c)
	face_points.append((world_a + world_b + world_c) / 3.0)
	face_normals.append(-(world_b - world_a).cross(world_c - world_a).normalized())




## Warnings shown as a yellow triangle in the scene dock.
func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if _has_auto_placed_stickers():
		warnings.append("Auto-placed stickers present — clear before saving (Clear Stickers button).")
	if _has_debug_placement_mesh():
		warnings.append("Placement debug visuals present — clear before saving (Clear Placement Debug Visuals button).")
	return warnings


func _has_auto_placed_stickers() -> bool:
	var mi := _find_mesh_instance()
	if mi == null:
		return false
	for child in mi.get_children():
		if child.name != DEBUG_PLACEMENT_MESH_NAME and child.name != DEBUG_SAMPLE_NORMALS_NAME and child.name != DEBUG_FACE_NORMALS_NAME:
			return true
	return false


func _has_debug_placement_mesh() -> bool:
	var mi := _find_mesh_instance()
	return mi != null and (mi.has_node(NodePath(DEBUG_PLACEMENT_MESH_NAME)) or mi.has_node(NodePath(DEBUG_SAMPLE_NORMALS_NAME)) or mi.has_node(NodePath(DEBUG_FACE_NORMALS_NAME)))


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

## Returns an orientation Basis where local Y aligns with the given outward normal.
func _basis_from_normal(outward_normal: Vector3) -> Basis:
	var up := outward_normal
	var arbitrary := Vector3.RIGHT if abs(outward_normal.dot(Vector3.RIGHT)) < 0.99 else Vector3.FORWARD
	var tangent := up.cross(arbitrary).normalized()
	var bitangent := tangent.cross(up).normalized()
	return Basis(tangent, up, bitangent)


### Sticker placement validation

## Validates that a sticker would be correctly placed: flat on a continuous surface
## Rejects if the underlying surface is not made of coplanar triangles
## Function contains no scene tree interaction, it is built so that candidates can be tested before instantiation.
func _validate_sticker_position(mesh_world_transform: Transform3D, mesh_aabb: AABB, world_triangles: Array, probe_ray_height: float, sample_points: Array[Vector3], sample_normals: Array[Vector3]) -> bool:
	var min_x: float = mesh_aabb.position.x
	var max_x: float = mesh_aabb.position.x + mesh_aabb.size.x
	var min_z: float = mesh_aabb.position.z
	var max_z: float = mesh_aabb.position.z + mesh_aabb.size.z

	var outward_normal: Vector3 = mesh_world_transform.basis.y.normalized()
	var ray_dir: Vector3 = -outward_normal

	var min_dist: float = INF
	var max_dist: float = -INF
	var reference_normal := Vector3.ZERO
	var have_reference := false
	var candidate_sample_points: Array[Vector3] = [] # stored for debugging
	var candidate_sample_normals: Array[Vector3] = [] # stored for debugging

	# Sample an NxN grid over the footprint of the sticker
	for ix in range(PROBE_GRID_N):
		for iz in range(PROBE_GRID_N):
			var fx: float = float(ix) / float(PROBE_GRID_N - 1)
			var fz: float = float(iz) / float(PROBE_GRID_N - 1)
			var local_point := Vector3(lerpf(min_x, max_x, fx), 0.0, lerpf(min_z, max_z, fz))
			var world_point: Vector3 = mesh_world_transform * local_point
			var ray_origin: Vector3 = world_point + outward_normal * probe_ray_height

			# first triangle hit along the ray 
			var closest_t: float = -1.0
			var closest_tri: Array = []
			for tri in world_triangles:
				var t: float = _ray_intersects_triangle(ray_origin, ray_dir, tri[0], tri[1], tri[2])
				if t >= 0.0 and (closest_t < 0.0 or t < closest_t):
					closest_t = t
					closest_tri = tri

			if closest_t < 0.0:
				return false # probe overhangs the surface

			# Normals compared probe-to-probe (against the first hit): catches bevels/slopes
			var hit_normal: Vector3 = -(closest_tri[1] - closest_tri[0]).cross(closest_tri[2] - closest_tri[0]).normalized()
			if not have_reference:
				reference_normal = hit_normal
				have_reference = true
			elif reference_normal.dot(hit_normal) < NORMAL_CONSISTENCY_MIN_DOT:
				return false

			# Frontmost hits must be coplanar
			min_dist = minf(min_dist, closest_t)
			max_dist = maxf(max_dist, closest_t)
			if max_dist - min_dist > VALIDATION_DISTANCE_TOLERANCE:
				return false

			candidate_sample_points.append(ray_origin + ray_dir * closest_t)
			candidate_sample_normals.append(hit_normal)

	sample_points.append_array(candidate_sample_points)
	sample_normals.append_array(candidate_sample_normals)
	return true

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
