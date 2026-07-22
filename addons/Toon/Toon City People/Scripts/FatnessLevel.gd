@tool
extends Node3D

@export_range(0, 100) var master_fat_slider: int = 0:
	set(v):
		master_fat_slider = v
		_apply()

func _apply() -> void:
	for child in get_children():
		if not child is MeshInstance3D:
			continue
		var mesh = (child as MeshInstance3D).mesh
		if mesh == null:
			continue
		for i in mesh.get_blend_shape_count():
			if mesh.get_blend_shape_name(i) == "Fat":
				(child as MeshInstance3D).set_blend_shape_value(i, master_fat_slider / 100.0)
