extends Node3D

# temporary variables for debugging
@export var cylinder_origin: Vector3 = Vector3.ZERO
@export var cylinder_radius: Vector3 = Vector3(1.0, 0.0, 0.0)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	_deform_object()
	pass

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
		#print("HERE")
		var arrays := array_mesh.surface_get_arrays(s)
		var orig_verts: PackedVector3Array = original_surfaces.get(s, PackedVector3Array()).duplicate()

		# Deform vertex positions: convert local -> world, map to cylinder, convert back to local
		for i in range(orig_verts.size()):
			#print("HERE")
			var local_v: Vector3 = orig_verts[i]
			var world_v: Vector3 = mesh_instance.to_global(local_v)
			var mapped_world: Vector3 = _map_to_cylinder(world_v, cylinder_origin, cylinder_radius)
			var mapped_local: Vector3 = mesh_instance.to_local(mapped_world)
			orig_verts[i] = mapped_local

		# Replace the vertex array with the deformed copy
		arrays[Mesh.ARRAY_VERTEX] = orig_verts

		# Add the modified surface
		new_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

		# Copy material if present
		var surf_mat := array_mesh.surface_get_material(s)
		if surf_mat:
			new_mesh.surface_set_material(new_mesh.get_surface_count() - 1, surf_mat)

	# Replace the mesh on the instance with our new deformed mesh
	mesh_instance.mesh = new_mesh

# Maps a given point to a given cylinder shape (of infinite(unbound) height)
# The cylinder axes are placed in the XZ plane , with the height being in the XZ plane and perpendicular to the radius vector
# The XZ coordinates of the point are used to map the point to the surface of the cylinder
# The Y coordiante of the point is used to map the point to the 'depth' of the cylinder
# points that have a Y component of 0 will be mapped to the surface of the cylinder 
# parameters:
#  point: a given point in 3D space
#  cylinder_location: location of origin of the cylinder (axis of rotation)
#  cylinder_radius: magnitude is length of the radius of cylinder,
#					as a 3D vector it defines the orientation of the cylinder
# returns: position of vertx on cylinder 
func _map_to_cylinder(point: Vector3, cylinder_location: Vector3, cylinder_radius: Vector3) -> Vector3:
	var EPS := 1e-6

	# Cylinder Properties
	var radius: float = cylinder_radius.length()
	assert(radius > EPS, "Cylinder radius cannot be zero.")

	# Direction from Axis -> Start of the sheet (unrolled state)
	var r_dir_flat := Vector3(cylinder_radius.x, 0.0, cylinder_radius.z)
	if r_dir_flat.length_squared() < EPS:
		r_dir_flat = r_dir_flat.normalized()

	# The Spine Direction (Axis of Rotation)
	# Perpendicular to radius in XZ plane (Rotate 90 deg around Y)
	var axis_dir := Vector3(-r_dir_flat.z, 0.0, r_dir_flat.x).normalized()

	# First treat the input point as existing on a flat plane starting at cylinder_location
	# We add the y component back in at the end
	var p_rel: Vector3 = point - cylinder_location

	# Distance along the spine (Axis)
	var dist_spine: float = p_rel.dot(axis_dir)

	# Distance along the "flat" radius vector (Arc Length)
	# This represents how far "out" the page is before curling.
	var dist_arc: float = p_rel.dot(r_dir_flat)

	# Convert Arc Length to Angle (Theta = Arc / Radius)
	var theta: float = dist_arc / radius

	# Rotate the flat radius vector UP/AROUND the axis
	# We use axis_dir (the spine of the cylinder) as the pivot.
	var r_dir_curled := r_dir_flat.rotated(axis_dir, theta)

	# Input Y is treated as thickness/offset from the surface.
	var final_radius: float = radius + point.y
	
	# Start at origin -> move along spine -> move out along the CURLED radius
	var mapped_point := cylinder_location + (axis_dir * dist_spine) + (r_dir_curled * final_radius)

	return mapped_point
