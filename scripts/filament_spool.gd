extends Node3D

@export var filament: FilamentType

@onready var _filament_mesh: CSGCombiner3D = $Filament

var filament_remaining: float = 1.0

func _ready() -> void:
	if filament:
		filament_remaining = filament.remaining
		_apply_material()
	set_filament_level(filament_remaining)

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

func set_filament_level(level: float) -> void:
	filament_remaining = clamp(level, 0.0, 1.0)
	var s = lerp(0.33, 1.0, filament_remaining)
	_filament_mesh.scale = Vector3(s, 1.0, s)

func set_filament(new_filament: FilamentType) -> void:
	filament = new_filament
	if is_inside_tree():
		_apply_material()
