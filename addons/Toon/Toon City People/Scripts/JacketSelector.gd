@tool
extends Node3D

const MAX_JACKETS = 5

@export_range(0, MAX_JACKETS - 1) var jacket: int = 0:
	set(v):
		jacket = v
		_apply()

@export var jackets: Array[Node3D] = []

func _apply() -> void:
	for i in jackets.size():
		if jackets[i] != null:
			jackets[i].visible = (i == jacket)
