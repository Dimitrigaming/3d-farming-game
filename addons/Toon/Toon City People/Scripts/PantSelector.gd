@tool
extends Node3D

const MAX_PANTS = 5

@export_range(0, MAX_PANTS - 1) var pant: int = 0:
	set(v):
		pant = v
		_apply()

@export var pants: Array[Node3D] = []

func _apply() -> void:
	for i in pants.size():
		if pants[i] != null:
			pants[i].visible = (i == pant)
