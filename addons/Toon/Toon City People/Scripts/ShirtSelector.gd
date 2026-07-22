@tool
extends Node3D

const MAX_SHIRTS = 5

@export_range(0, MAX_SHIRTS - 1) var shirt: int = 0:
	set(v):
		shirt = v
		_apply()

@export var shirts: Array[Node3D] = []

func _apply() -> void:
	for i in shirts.size():
		if shirts[i] != null:
			shirts[i].visible = (i == shirt)
