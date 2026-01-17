class_name Workbench
extends Node3D

@export var object_slots: Array[Node3D]

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

# adds a new object to the workbench
func add_object(object_scene: Resource):
	print("Adding object: " + object_scene.resource_path)
	var object = load(object_scene.resource_path) # TODO: someting is going wrong here with the classess
	
	if object == null or not(object is ObjectWithStickers):
		print("ERROR: add_object loaded null or incorrect class from: "
				+ object_scene.resource_path + ". Aborting object load!")
		return

	# TODO: add object ot next free slot
