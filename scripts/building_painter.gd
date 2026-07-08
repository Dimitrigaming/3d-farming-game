extends Node3D

const MAT_WHITE = preload("res://addons/city_megakit/materials/MI_WhiteBrick.tres")
const MAT_WORN  = preload("res://addons/city_megakit/materials/MI_WornBrick.tres")

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("paint_white"):
		_set_exterior(MAT_WHITE)
	elif event.is_action_pressed("paint_worn"):
		_set_exterior(MAT_WORN)

func _set_exterior(mat: Material) -> void:
	for mi in _get_mesh_instances($Exterior):
		if not mi.mesh is ArrayMesh:
			continue
		for surface_name in ["mat_Exterior", "MI_WornBrick", "MI_WhiteBrick"]:
			var idx = mi.mesh.surface_find_by_name(surface_name)
			if idx >= 0:
				mi.set_surface_override_material(idx, mat)
				break

func _get_mesh_instances(node: Node) -> Array:
	var result = []
	if node is MeshInstance3D:
		result.append(node)
	for child in node.get_children():
		result.append_array(_get_mesh_instances(child))
	return result
