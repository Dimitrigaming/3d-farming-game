@tool
extends Node3D

const MAX_WATCHES = 16

@export_range(0, MAX_WATCHES - 1) var watch: int = 0:
	set(v):
		watch = v
		_apply()

@export var watches: Array[Node3D] = []

func _apply() -> void:
	for i in watches.size():
		if watches[i] != null:
			watches[i].visible = (i == watch)
