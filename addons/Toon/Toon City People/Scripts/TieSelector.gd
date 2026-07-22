@tool
extends Node3D

const MAX_TIES = 5

@export_range(0, MAX_TIES - 1) var tie: int = 0:
	set(v):
		tie = v
		_apply()

@export var ties: Array[Node3D] = []

func _apply() -> void:
	for i in ties.size():
		if ties[i] != null:
			ties[i].visible = (i == tie)
