extends Node3D

@export var filament: FilamentType

# Applies the filament's color/shininess to all CSG meshes on the spool
func _ready() -> void:
	if filament:
		_apply_material()

func _apply_material() -> void:
	var mat = StandardMaterial3D.new()
	mat.albedo_color = filament.color
	mat.metallic = filament.metallic
	mat.roughness = filament.roughness
	_apply_to_children(self, mat)

func _apply_to_children(node: Node, mat: StandardMaterial3D) -> void:
	for child in node.get_children():
		if child is CSGPrimitive3D:
			child.material = mat
		_apply_to_children(child, mat)

func get_filament_type() -> FilamentType:
	return filament

func set_filament(new_filament: FilamentType) -> void:
	filament = new_filament
	if is_inside_tree():
		_apply_material()
