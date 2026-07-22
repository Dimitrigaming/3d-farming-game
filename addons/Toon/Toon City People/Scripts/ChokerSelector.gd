@tool
extends Node3D

const MAX_CHOKERS = 4

@export_range(0, MAX_CHOKERS - 1) var choker: int = 0:
	set(v):
		choker = v
		_apply()

@export var chokers: Array[Node3D] = []

func _apply() -> void:
	for i in chokers.size():
		if chokers[i] != null:
			chokers[i].visible = (i == choker)
