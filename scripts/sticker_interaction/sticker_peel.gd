class_name StickerPeel extends Sticker

var mouse_start: Vector2
var mouse_current: Vector2
var is_peeling: bool = false
var _original_mesh_backup: Mesh = null
var _original_center: Vector3
var _original_extent: float

var peel_radius: float # larger radius increases peel curvature (worldspace)
var max_peel_distance: float # how much can the mouse move before stopping the peel animation (worldspace)
const COMPLETION_THRESHOLD: float = 0.7

func _ready() -> void:
	var mesh_instance = _find_mesh_instance(self)
	if mesh_instance == null:
		push_warning("StickerPeel: No MeshInstance3D found; cannot compute sticker size.")
		return
	var aabb := mesh_instance.get_aabb()
	var mesh_scale: Vector3 = mesh_instance.global_transform.basis.get_scale()
	var world_size := aabb.size * mesh_scale
	# Sticker size = 2nd smallest dimension of the world-space bounding box
	var dims := [world_size.x, world_size.y, world_size.z]
	dims.sort()
	# get middle dimension, which is smallest '2D' dimension of the sticker (since thickness is 0, and that's the smallest 3D dimension)
	var sticker_size: float = dims[1]
	peel_radius = sticker_size * 0.25
	max_peel_distance = sticker_size * 1.5

func _complete_fraction() -> float:
	# returns the % that a sticker is completed
	# for this sticker type this is directly equal to deform_amplitude
	if not is_peeling:
		return 0.0
	var start_3d := _screen_to_plane(mouse_start)
	var current_3d := _screen_to_plane(mouse_current)
	return clamp(start_3d.distance_to(current_3d) / max_peel_distance, 0.0, 1.0)

func _handle_sticker_deform() -> void:
	if not is_peeling:
		return

	mouse_current = get_viewport().get_mouse_position()

	# Project screen-space drag into world-space via camera ray onto horizontal plane
	var start_3d := _screen_to_plane(mouse_start)
	var current_3d := _screen_to_plane(mouse_current)
	var world_offset := current_3d - start_3d

	# Optimization go brrr
	if world_offset.length() < 0.001:
		return

	var deform_direction := Vector2(world_offset.x, world_offset.z).normalized()
	
	# To smooth inputs we need to measure past the max peel distance, so clamp at 3.0 
	var deform_amplitude: float = clamp(world_offset.length() / max_peel_distance, 0.0, 3.0)
	# Smooth inputs to not have hard cutoff at max peel distance
	deform_amplitude = atan((3.0*deform_amplitude))/1.45

	# Curl direction is opposite to drag so the peel visually advances with the drag
	cylinder_radius = -deform_direction * peel_radius

	# Position cylinder to control peel progress
	var mesh_instance = _find_mesh_instance(self)
	if mesh_instance == null:
		return

	if _original_mesh_backup == null:
		_original_mesh_backup = mesh_instance.mesh
		var aabb := mesh_instance.get_aabb()
		_original_center = mesh_instance.to_global(aabb.get_center())
		var world_min := mesh_instance.to_global(aabb.position)
		var world_max := mesh_instance.to_global(aabb.position + aabb.size)
		_original_extent = world_min.distance_to(world_max) * 0.5

	var drag_dir := Vector3(deform_direction.x, 0.0, deform_direction.y).normalized()

	# Peel line sweeps from the edge opposite the drag toward the drag edge
	cylinder_origin = _original_center + drag_dir * lerp(-_original_extent, _original_extent, deform_amplitude)
	cylinder_origin.y = _original_center.y + peel_radius

	_deform_object()

func _process(delta: float) -> void:
	_handle_sticker_deform()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("mouse_click_left") and _get_interactible():
		CursorManager.request_cursor(CursorManager.CursorType.GRAB)
		get_viewport().set_input_as_handled()
		is_peeling = true
		mouse_start = get_viewport().get_mouse_position()
		mouse_current = mouse_start
	if event.is_action_released("mouse_click_left") and is_peeling:
		get_viewport().set_input_as_handled()
		mouse_current = get_viewport().get_mouse_position()
		var fraction := _complete_fraction()
		is_peeling = false
		if fraction >= COMPLETION_THRESHOLD:
			_complete_sticker()
		else:
			_reset_deform()
		CursorManager.release_cursor(CursorManager.CursorType.GRAB)

# Project a screen position onto a horizontal plane at this sticker's world height
func _screen_to_plane(screen_pos: Vector2) -> Vector3:
	var camera := get_viewport().get_camera_3d()
	var origin := camera.project_ray_origin(screen_pos)
	var direction := camera.project_ray_normal(screen_pos)
	if abs(direction.y) < 0.001:
		return global_position
	var t := (global_position.y - origin.y) / direction.y
	return origin + direction * t

func _reset_deform() -> void:
	var mesh_instance = _find_mesh_instance(self)
	if mesh_instance and _original_mesh_backup:
		mesh_instance.mesh = _original_mesh_backup
	_original_mesh_backup = null
	_original_center = Vector3.ZERO
	_original_extent = 0.0
	original_surfaces.clear()

### Deformation logic

var cylinder_origin: Vector3 = Vector3.ZERO
# cylinder_radius defines both the ORIENTATION and RADIUS of an UNBOUNDED cylinder
# 	If cylinder_radius is an X unit vector, the cylinder is axis-aligned with the Z axis
# 	The direction also determines which side of the start line gets curled:
# 	vertices ahead of start_of_curl in the forward direction enter the curl, while vertices behind it stay flat
var cylinder_radius: Vector2 = Vector2(1.0, 0.0)

# Member to cache original per-surface vertices to avoid cumulative deformation
var original_surfaces: Dictionary = {}

# Helper: find first MeshInstance3D in this node's subtree
func _find_mesh_instance(node: Node) -> MeshInstance3D:
	for child in node.get_children():
		if child is MeshInstance3D:
			return child
		var found := _find_mesh_instance(child)
		if found:
			return found
	return null

# Deform attached object for sticker peel effect
func _deform_object() -> void:
	# Find the MeshInstance3D (self may be a MeshInstance3D or a parent Node)
	var mesh_instance = _find_mesh_instance(self)
	if mesh_instance == null:
		push_warning("No MeshInstance3D found in node subtree; cannot deform.")
		return

	# Get mesh
	var mesh: Mesh = mesh_instance.mesh
	if mesh == null:
		push_warning("MeshInstance3D has no mesh assigned.")
		return

	if not (mesh is ArrayMesh):
		push_warning("Only ArrayMesh is supported by this deformation helper.")
		return
	var array_mesh: ArrayMesh = mesh as ArrayMesh

	# Cache original vertices the first time we run, keyed by surface index
	if original_surfaces.is_empty():
		for s in array_mesh.get_surface_count():
			var arrays := array_mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			# duplicate to avoid referencing the source buffer
			original_surfaces[s] = verts.duplicate() if verts != null else PackedVector3Array()

	# Build a new mesh, deforming each surface from the cached original vertices
	var new_mesh := ArrayMesh.new()
	for s in range(array_mesh.get_surface_count()):
		var arrays := array_mesh.surface_get_arrays(s)
		var orig_verts: PackedVector3Array = original_surfaces.get(s, PackedVector3Array()).duplicate()

		# [NEW] Prepare array for custom data (Curl Ratio)
		# 4 bytes per vertex (R, G, B, A). We use Red for the ratio.
		var custom_data := PackedByteArray() 
		custom_data.resize(orig_verts.size() * 4) 

		# Deform vertex positions: convert local -> world, map to cylinder, convert back to local
		for i in range(orig_verts.size()):
			var local_v: Vector3 = orig_verts[i]
			var world_v: Vector3 = mesh_instance.to_global(local_v)
			
			# [CHANGED] Call modified map function that returns Dict
			var result: Dictionary = _map_to_cylinder(world_v, cylinder_origin, cylinder_radius)
			var mapped_world: Vector3 = result["position"]
			var ratio: float = result["ratio"] # 0.0 to 1.0

			var mapped_local: Vector3 = mesh_instance.to_local(mapped_world)
			# debugging 
			orig_verts[i] = mapped_local

			# [Store ratio in Custom Data (Mapped to 0-255 byte)
			var byte_val := int(clamp(ratio, 0.0, 1.0) * 255.0)
			var byte_idx := i * 4
			custom_data[byte_idx] = byte_val     # R channel
			custom_data[byte_idx + 1] = 0        # G channel
			custom_data[byte_idx + 2] = 0        # B channel
			custom_data[byte_idx + 3] = 0        # A channel

		# Replace the vertex array with the deformed copy
		arrays[Mesh.ARRAY_VERTEX] = orig_verts

		# Assign Custom Data Array
		arrays[Mesh.ARRAY_CUSTOM0] = custom_data

		# Add the modified surface
		new_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

		# Copy material if present
		var surf_mat := array_mesh.surface_get_material(s)
		if surf_mat:
			new_mesh.surface_set_material(new_mesh.get_surface_count() - 1, surf_mat)

	# Replace the mesh on the instance with our new deformed mesh
	mesh_instance.mesh = new_mesh

func _map_to_cylinder(point: Vector3, cylinder_location: Vector3, cylinder_radius: Vector2) -> Dictionary:
	var EPS := 1e-6

	# Cylinder Properties
	var radius: float = cylinder_radius.length()
	assert(radius > EPS, "Cylinder radius cannot be zero.")

	# The input vector defines the FORWARD direction of the curl on the ground
	var forward_dir := Vector3(cylinder_radius.x, 0.0, cylinder_radius.y).normalized()

	var axis_dir := Vector3(-forward_dir.z, 0.0, forward_dir.x).normalized()

	# The Radius Vector points from the Axis down to the flat ground
	# since we want the sheet to lie on the XZ plane
	var radius_dir := Vector3.DOWN

	# Geometry relative to curl start
	# The start line is directly below the cylinder axis
	var start_of_curl := cylinder_location + (radius_dir * radius) 
	
	var p_rel: Vector3 = point - start_of_curl 
	var dist_spine: float = p_rel.dot(axis_dir)
	
	# Project distance onto the forward direction
	var dist_linear: float = p_rel.dot(forward_dir)

	# Params
	var max_angle: float = PI * 1.2
	var max_arc_length: float = radius * max_angle
	
	# Thickness logic: height above the surface adds to the curl radius
	var thickness: float = point.y - start_of_curl.y
	var current_radius: float = radius + thickness

	var final_pos: Vector3
	var ratio: float = 0.0

	if dist_linear < 0.0:
		# ZONE A: Before Curl
		# Move along the Forward direction
		final_pos = start_of_curl + (forward_dir * dist_linear) + (axis_dir * dist_spine)
		
		# Apply thickness UP (Opposite to radius_dir)
		final_pos -= radius_dir * thickness
		ratio = 0.0

	elif dist_linear <= max_arc_length:
		# ZONE B: Inside Curl
		var angle: float = dist_linear / radius
		
		var rotated_radius_vec := radius_dir.rotated(axis_dir, angle)
		
		# Reconstruct: Axis + SpineOffset + (RotatedVector * TotalRadius)
		final_pos = cylinder_location + (axis_dir * dist_spine) + (rotated_radius_vec * current_radius)
		
		ratio = dist_linear / max_arc_length 

	else:
		# ZONE C: After Curl
		var end_radius_vec := radius_dir.rotated(axis_dir, max_angle)
		var lip_pos := cylinder_location + (axis_dir * dist_spine) + (end_radius_vec * current_radius)
		
		# Rotate the Forward Vector to extend tangentially
		var end_forward_dir := forward_dir.rotated(axis_dir, max_angle)
		var excess_dist: float = dist_linear - max_arc_length
		final_pos = lip_pos + (end_forward_dir * excess_dist)
		ratio = 1.0

	return {"position": final_pos, "ratio": ratio}
