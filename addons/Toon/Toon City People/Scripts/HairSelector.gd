@tool
extends Node3D

const MAX_HAIRSTYLES = 51

@export_range(0, MAX_HAIRSTYLES - 1) var hairstyle: int = 0:
	set(v):
		hairstyle = v
		_apply()

@export var hairstyles: Array[Node3D] = []

func _apply() -> void:
	for i in hairstyles.size():
		if hairstyles[i] != null:
			hairstyles[i].visible = (i == hairstyle)
