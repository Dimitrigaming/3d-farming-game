@tool
extends Node3D

const MAX_HEADS = 35

@export_range(0, MAX_HEADS - 1) var head: int = 0:
	set(v):
		head = v
		_apply()

@export var heads: Array[Node3D] = []

func _apply() -> void:
	for i in heads.size():
		if heads[i] != null:
			heads[i].visible = (i == head)
